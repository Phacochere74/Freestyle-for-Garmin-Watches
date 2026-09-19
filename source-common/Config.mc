//
// Config - lecture centralisee des reglages de l'application.
//
// Les reglages sont saisis depuis Garmin Connect Mobile (ou Garmin Express) et
// exposes via Application.Properties. getValue() leve une exception si la cle
// n'existe pas (ancienne version installee, propriete renommee...) : tous les
// acces passent donc par des helpers defensifs avec valeur par defaut.
//
using Toybox.Application;
using Toybox.Lang;

(:glance, :background)
module Config {

    enum {
        SOURCE_LIBRELINKUP = 0,
        SOURCE_NIGHTSCOUT = 1
    }

    //! Lecture brute d'une propriete, null si absente ou illisible.
    function raw(key) {
        try {
            return Application.Properties.getValue(key);
        } catch (e) {
            return null;
        }
    }

    function numberProp(key, fallback) {
        var value = raw(key);
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Number) {
            return value;
        }
        if (value instanceof Lang.Float || value instanceof Lang.Double) {
            return value.toNumber();
        }
        if (value instanceof Lang.String) {
            var parsed = Fmt.trim(value).toNumber();
            return (parsed == null) ? fallback : parsed;
        }
        return fallback;
    }

    function boolProp(key, fallback) {
        var value = raw(key);
        if (value instanceof Lang.Boolean) {
            return value;
        }
        if (value instanceof Lang.Number) {
            return value != 0;
        }
        return fallback;
    }

    function stringProp(key) {
        var value = raw(key);
        if (value instanceof Lang.String) {
            return Fmt.trim(value);
        }
        return "";
    }

    // ---- Source de donnees -------------------------------------------------

    function dataSource() {
        var src = numberProp("dataSource", SOURCE_LIBRELINKUP);
        return (src == SOURCE_NIGHTSCOUT) ? SOURCE_NIGHTSCOUT : SOURCE_LIBRELINKUP;
    }

    //! Identifiants du compte suiveur LibreLinkUp.
    //!
    //! Les constantes de Credentials, quand elles sont renseignees, sont
    //! PRIORITAIRES sur les reglages memorises par la montre. C'est
    //! indispensable pour une installation manuelle : la montre conserve les
    //! valeurs enregistrees au premier lancement, et l'ecran de reglages du
    //! telephone n'est pas utilisable dans ce cas.
    function lluEmail() {
        if (Credentials.LLU_EMAIL.length() > 0) {
            return Credentials.LLU_EMAIL;
        }
        return stringProp("lluEmail");
    }

    function lluPassword() {
        if (Credentials.LLU_PASSWORD.length() > 0) {
            return Credentials.LLU_PASSWORD;
        }
        return stringProp("lluPassword");
    }

    //! Region LibreView : "eu", "us", "de", "fr", "jp", "ap", "au", "ca"...
    //! Sert a construire https://api-<region>.libreview.io
    function lluRegion() {
        var region = stringProp("lluRegion").toLower();
        if (region.length() == 0) {
            return "eu";
        }
        return region;
    }

    //! Version d'API annoncee a LibreLinkUp (en-tete "version").
    //! Abbott refuse les versions trop anciennes : si la connexion echoue,
    //! relever cette valeur suffit generalement.
    function lluApiVersion() {
        var version = stringProp("lluApiVersion");
        if (version.length() == 0) {
            return "4.16.0";
        }
        return version;
    }

    function nightscoutUrl() { return Fmt.stripTrailingSlash(stringProp("nightscoutUrl")); }
    function nightscoutToken() { return stringProp("nightscoutToken"); }

    // ---- Affichage ---------------------------------------------------------

    //! true = mmol/L, false = mg/dL
    function useMmol() { return boolProp("useMmol", false); }

    // ---- Seuils (toujours stockes en mg/dL) --------------------------------

    function urgentLow() { return clampThreshold(numberProp("urgentLow", 55), 40, 100); }
    function low() { return clampThreshold(numberProp("lowThreshold", 70), 50, 120); }
    function high() { return clampThreshold(numberProp("highThreshold", 180), 120, 300); }
    function urgentHigh() { return clampThreshold(numberProp("urgentHigh", 250), 150, 400); }

    function clampThreshold(value, minValue, maxValue) {
        if (value < minValue) { return minValue; }
        if (value > maxValue) { return maxValue; }
        return value;
    }

    // ---- Rafraichissement / alertes ---------------------------------------

    //! Periode de rafraichissement quand l'application est ouverte (secondes).
    function refreshSeconds() {
        var value = numberProp("refreshSeconds", 60);
        if (value < 30) { return 30; }
        if (value > 600) { return 600; }
        return value;
    }

    function backgroundEnabled() { return boolProp("backgroundEnabled", true); }
    function vibrateOnAlert() { return boolProp("vibrateOnAlert", true); }

    //! Duree affichee sur le graphique, en heures.
    function chartHours() {
        var value = numberProp("chartHours", 3);
        if (value < 1) { return 1; }
        if (value > 6) { return 6; }
        return value;
    }

    //! Vrai si la source selectionnee dispose du minimum vital pour fonctionner.
    function isConfigured() {
        if (dataSource() == SOURCE_NIGHTSCOUT) {
            var url = nightscoutUrl();
            // Connect IQ refuse les requetes non chiffrees : accepter "http://"
            // ici ferait tourner un service en arriere-plan qui echoue toujours.
            return url.find("https://") == 0;
        }
        return lluEmail().length() > 0 && lluPassword().length() > 0;
    }
}
