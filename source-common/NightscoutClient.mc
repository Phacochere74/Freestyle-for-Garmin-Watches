//
// NightscoutClient - source alternative : un serveur Nightscout.
//
// Interessant si tu utilises deja xDrip+, Juggluco ou LibreLinkUp -> Nightscout
// pour televerser tes mesures : la reponse est beaucoup plus legere que celle de
// LibreLinkUp, et l'API est publique et stable.
//
// Endpoint : GET <url>/api/v1/entries/sgv.json?count=N[&token=...]
// Reponse  : [{ "sgv": 120, "date": 1694458800000, "direction": "Flat", ... }, ...]
//            triee du plus recent au plus ancien.
//
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

(:glance, :background)
class NightscoutClient {

    hidden var mCallback;
    hidden var mCount;

    function initialize() {
        mCallback = null;
        mCount = 1;
    }

    //! @param callback Method(errorMessage as String or Null, reading as Dictionary or Null)
    //! @param historyCount nombre de mesures demandees (1 = juste la derniere)
    function fetch(callback, historyCount) {
        mCallback = callback;
        mCount = historyCount;
        if (mCount < 1) { mCount = 1; }
        if (mCount > 48) { mCount = 48; }

        var url = Config.nightscoutUrl();
        if (url.length() == 0) {
            finish("URL Nightscout manquante", null);
            return;
        }
        if (url.find("https://") != 0) {
            // Connect IQ refuse les requetes non chiffrees.
            finish("URL HTTPS requise", null);
            return;
        }

        var params = { "count" => mCount.toString() };
        var token = Config.nightscoutToken();
        if (token.length() > 0) {
            params["token"] = token;
        }

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url + "/api/v1/entries/sgv.json", params, options, method(:onEntries));
    }

    //! Signature imposee par Communications.ResponseCallback : le verificateur
    //! de types refuse un callback non type passe a makeWebRequest().
    function onEntries(responseCode as Lang.Number,
                       data as Lang.Dictionary or Lang.String or Null) as Void {
        if (responseCode != 200) {
            finish(Net.describeError(responseCode), null);
            return;
        }
        // Nightscout renvoie un tableau JSON a la racine, alors que la signature
        // imposee au callback ne mentionne que Dictionary ou String. On elargit
        // donc le type avant le test, sinon le verificateur considere la branche
        // comme morte et le code du tableau ne serait jamais atteint.
        var payload = data as Lang.Object;
        if (!(payload instanceof Lang.Array) || payload.size() == 0) {
            finish("Aucune mesure", null);
            return;
        }

        // Les entrees arrivent du plus recent au plus ancien : on les reinjecte
        // dans l'historique en ordre croissant.
        var points = [];
        var newest = null;
        for (var i = payload.size() - 1; i >= 0; i -= 1) {
            var entry = payload[i];
            var sgv = Net.asNumber(Net.dictGet(entry, "sgv"));
            if (sgv == null || sgv <= 0) {
                continue;
            }
            // On privilegie dateString (ISO-8601) : le champ numerique `date`
            // est en millisecondes et depasse la plage d'un Number 32 bits.
            var seconds = Fmt.parseIso8601(Net.dictGet(entry, "dateString"));
            if (seconds == null) {
                var dateMs = Net.dictGet(entry, "date");
                if (dateMs != null && !(dateMs instanceof Lang.String)) {
                    seconds = (dateMs.toDouble() / 1000.0).toNumber();
                }
            }
            if (seconds == null || seconds <= 0) {
                continue;
            }
            points.add([seconds, sgv]);
            newest = entry;
        }

        if (newest == null || points.size() == 0) {
            finish("Mesure illisible", null);
            return;
        }

        if (points.size() > 1) {
            Store.mergePoints(points.slice(0, points.size() - 1));
        }

        var last = points[points.size() - 1];
        var trend = Fmt.trendFromNightscout(Net.dictGet(newest, "direction"));
        finish(null, Store.makeReading(last[1], last[0], trend));
    }

    hidden function finish(errorMessage, reading) {
        var callback = mCallback;
        mCallback = null;
        if (callback != null) {
            callback.invoke(errorMessage, reading);
        }
    }
}
