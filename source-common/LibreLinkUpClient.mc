//
// LibreLinkUpClient - recuperation de la glycemie via l'API LibreLinkUp.
//
// Principe : l'application FreeStyle Libre 3 du telephone televerse les mesures
// vers LibreView. Un compte "suiveur" LibreLinkUp, invite depuis l'application
// Libre 3, peut relire ces mesures via une API REST. C'est cette API que la
// montre interroge directement (via le Bluetooth du telephone ou le Wi-Fi).
//
// Enchainement :
//   1. POST /llu/auth/login       -> jeton Bearer + identifiant de compte
//      (reponse possible : redirection vers une autre region)
//   2. GET  /llu/connections      -> derniere mesure du patient suivi
//
// L'API n'est pas documentee publiquement par Abbott : elle peut changer sans
// preavis. Toutes les lectures de champs sont donc defensives.
//
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

(:glance, :background)
class LibreLinkUpClient {

    // Valeurs d'en-tete attendues par l'API (elles imitent l'app Android).
    // Abbott releve regulierement la version minimale acceptee : elle est donc
    // modifiable dans les reglages sans avoir a recompiler.
    const PRODUCT = "llu.android";

    hidden var mCallback;      // Method(errorMessage, reading)
    hidden var mTriedLogin;    // evite une boucle login <-> 401
    hidden var mRedirects;     // evite une boucle de redirection de region
    hidden var mRegion;
    hidden var mAllowLogin;    // false en background pour limiter la memoire

    function initialize() {
        mCallback = null;
        mTriedLogin = false;
        mRedirects = 0;
        mRegion = "eu";
        mAllowLogin = true;
    }

    //! Lance la recuperation de la derniere mesure.
    //! @param callback Method(errorMessage as String or Null, reading as Dictionary or Null)
    //! @param allowLogin false pour interdire l'authentification (contexte background)
    function fetch(callback, allowLogin) {
        mCallback = callback;
        mTriedLogin = false;
        mRedirects = 0;
        mAllowLogin = allowLogin;

        var region = Store.getRegion();
        if (region == null) {
            region = Config.lluRegion();
        }
        mRegion = region;

        if (Config.lluEmail().length() == 0 || Config.lluPassword().length() == 0) {
            finish("Identifiants manquants", null);
            return;
        }

        if (Store.hasValidToken()) {
            requestConnections();
        } else if (mAllowLogin) {
            login();
        } else {
            finish("Session expiree", null);
        }
    }

    // ---- Requetes ----------------------------------------------------------

    hidden function baseUrl() {
        return "https://api-" + mRegion + ".libreview.io";
    }

    hidden function commonHeaders() {
        var version = Config.lluApiVersion();
        return {
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
            "product" => PRODUCT,
            "version" => version,
            // Certaines reponses /llu/connections sont refusees sans User-Agent.
            // Connect IQ peut choisir de l'ignorer : si l'API renvoie 403,
            // c'est la premiere piste a verifier.
            "User-Agent" => "LibreLinkUp/" + version
        };
    }

    hidden function login() {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => commonHeaders(),
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        var body = {
            "email" => Config.lluEmail(),
            "password" => Config.lluPassword()
        };
        Communications.makeWebRequest(baseUrl() + "/llu/auth/login", body, options, method(:onLogin));
    }

    hidden function requestConnections() {
        var headers = commonHeaders();
        headers["Authorization"] = "Bearer " + Store.getToken();
        var accountId = Store.getAccountId();
        if (accountId != null) {
            headers["Account-Id"] = accountId;
        }
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(baseUrl() + "/llu/connections", null, options, method(:onConnections));
    }

    // ---- Reponses ----------------------------------------------------------

    function onLogin(responseCode, data) {
        if (responseCode != 200 || !(data instanceof Lang.Dictionary)) {
            finish(Net.describeError(responseCode), null);
            return;
        }

        var status = Net.asNumber(data["status"]);
        var payload = Net.dictGet(data, "data");

        // status 2 = identifiants refuses, 4 = conditions d'utilisation a accepter.
        if (status != null && status == 2) {
            finish("Email ou mot de passe refuse", null);
            return;
        }
        if (status != null && status == 4) {
            finish("Conditions a accepter dans LibreLinkUp", null);
            return;
        }

        // Redirection : le compte appartient a une autre region LibreView.
        var redirect = Net.dictGet(payload, "redirect");
        if (redirect != null && redirect == true) {
            var region = Net.dictGet(payload, "region");
            if (region instanceof Lang.String && region.length() > 0 && mRedirects < 2) {
                mRedirects += 1;
                mRegion = region.toLower();
                Store.setRegion(mRegion);
                login();
                return;
            }
            finish("Region LibreView introuvable", null);
            return;
        }

        var ticket = Net.dictGet(payload, "authTicket");
        var token = Net.dictGet(ticket, "token");
        if (!(token instanceof Lang.String) || token.length() == 0) {
            finish("Connexion refusee", null);
            return;
        }

        var expires = Net.asNumber(Net.dictGet(ticket, "expires"));
        if (expires == null) {
            // Par defaut, on considere le jeton valable 12 h.
            expires = Time.now().value() + 43200;
        }

        // L'API exige l'en-tete Account-Id = SHA-256 de l'identifiant utilisateur.
        var user = Net.dictGet(payload, "user");
        var userId = Net.dictGet(user, "id");
        var accountIdHash = Net.sha256Hex(userId);

        Store.saveSession(token, expires, accountIdHash, mRegion);
        requestConnections();
    }

    function onConnections(responseCode, data) {
        if (responseCode == 401 || responseCode == 403) {
            // Jeton refuse : on le jette et on retente une authentification complete.
            Store.clearSession();
            if (mAllowLogin && !mTriedLogin) {
                mTriedLogin = true;
                login();
                return;
            }
            finish("Session refusee", null);
            return;
        }

        if (responseCode != 200 || !(data instanceof Lang.Dictionary)) {
            finish(Net.describeError(responseCode), null);
            return;
        }

        var connections = Net.dictGet(data, "data");
        if (!(connections instanceof Lang.Array) || connections.size() == 0) {
            finish("Aucun capteur partage", null);
            return;
        }

        var connection = connections[0];
        var patientId = Net.dictGet(connection, "patientId");
        if (patientId instanceof Lang.String) {
            Store.setPatientId(patientId);
        }

        var measurement = Net.dictGet(connection, "glucoseMeasurement");
        if (measurement == null) {
            finish("Mesure indisponible", null);
            return;
        }

        var mgdl = Net.asNumber(Net.dictGet(measurement, "ValueInMgPerDl"));
        if (mgdl == null) {
            // Repli : certains comptes ne renvoient que "Value" dans l'unite du compte.
            var value = Net.asNumber(Net.dictGet(measurement, "Value"));
            var uom = Net.asNumber(Net.dictGet(connection, "uom"));
            if (value != null) {
                // uom = 1 -> mg/dL, uom = 2 -> mmol/L
                mgdl = (uom != null && uom == 2) ? (value / Fmt.MMOL_PER_MGDL).toNumber() : value;
            }
        }
        if (mgdl == null || mgdl <= 0) {
            finish("Mesure illisible", null);
            return;
        }

        // FactoryTimestamp est en UTC ; Timestamp est en heure locale du patient.
        var timestamp = Fmt.parseLibreTimestamp(Net.dictGet(measurement, "FactoryTimestamp"));
        if (timestamp == null) {
            timestamp = Time.now().value();
        }

        var trend = Fmt.trendFromLibre(Net.asNumber(Net.dictGet(measurement, "TrendArrow")));
        finish(null, Store.makeReading(mgdl, timestamp, trend));
    }

    hidden function finish(errorMessage, reading) {
        var callback = mCallback;
        mCallback = null;
        if (callback != null) {
            callback.invoke(errorMessage, reading);
        }
    }
}
