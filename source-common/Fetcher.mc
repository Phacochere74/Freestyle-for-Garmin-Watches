//
// Fetcher - aiguillage entre les sources de donnees et ecriture dans Store.
//
// Une seule requete a la fois : Connect IQ limite le nombre de requetes
// simultanees, et un capteur ne publie de toute facon qu'une mesure / 5 min.
//
using Toybox.Lang;

(:glance, :background)
class Fetcher {

    hidden var mClient;
    hidden var mCallback;
    hidden var mBusy;

    function initialize() {
        mClient = null;
        mCallback = null;
        mBusy = false;
    }

    function isBusy() {
        return mBusy;
    }

    //! Demarre une recuperation.
    //! @param callback Method(errorMessage as String or Null, reading as Dictionary or Null)
    //! @param allowLogin autorise l'authentification LibreLinkUp (false en background)
    //! @param historyCount nombre de mesures Nightscout demandees
    //! @return true si la requete a bien ete lancee
    function start(callback, allowLogin, historyCount) {
        if (mBusy) {
            return false;
        }
        if (!Config.isConfigured()) {
            invokeCallback(callback, "Reglages a completer", null);
            return false;
        }

        mBusy = true;
        mCallback = callback;

        if (Config.dataSource() == Config.SOURCE_NIGHTSCOUT) {
            mClient = new NightscoutClient();
            mClient.fetch(method(:onResult), historyCount);
        } else {
            mClient = new LibreLinkUpClient();
            mClient.fetch(method(:onResult), allowLogin);
        }
        return true;
    }

    function onResult(errorMessage, reading) {
        mBusy = false;
        mClient = null;
        Store.markFetch();

        if (errorMessage == null && reading != null) {
            Store.clearError();
            Store.saveReading(reading);
        } else {
            Store.setError(errorMessage == null ? "Erreur inconnue" : errorMessage);
        }

        var callback = mCallback;
        mCallback = null;
        invokeCallback(callback, errorMessage, reading);
    }

    hidden function invokeCallback(callback, errorMessage, reading) {
        if (callback != null) {
            callback.invoke(errorMessage, reading);
        }
    }
}
