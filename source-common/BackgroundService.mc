//
// BackgroundService - rafraichissement periodique hors application.
//
// Contraintes fortes : le service background dispose d'une memoire tres reduite
// (de l'ordre de 32 Ko sur beaucoup de montres) et doit se terminer par
// Background.exit(). On y fait donc le strict minimum :
//   - LibreLinkUp : uniquement si un jeton valide est deja en cache
//     (l'authentification, plus lourde, est reservee a l'application) ;
//   - Nightscout : une seule mesure demandee.
//
using Toybox.Background;
using Toybox.Lang;
using Toybox.System;

(:background)
class BackgroundService extends System.ServiceDelegate {

    hidden var mFetcher;
    hidden var mExited;

    function initialize() {
        System.ServiceDelegate.initialize();
        mFetcher = null;
        mExited = false;
    }

    function onTemporalEvent() {
        // Dater le reveil AVANT tout test de configuration : ce qu'on mesure
        // ici, c'est que la plateforme nous reveille bien, pas que la requete
        // aboutisse. Wake.isStale() s'appuie sur cette date.
        Store.markWakeRun();

        if (!Config.backgroundEnabled() || !Config.isConfigured()) {
            exitOnce(null);
            return;
        }
        mFetcher = new Fetcher();
        // L'authentification est autorisee ici : le champ de donnees n'a aucune
        // vue de premier plan, ce service est son SEUL moyen d'obtenir un jeton.
        // start() peut echouer immediatement et avoir deja appele onResult(),
        // d'ou le garde-fou mExited : Background.exit() ne doit partir qu'une fois.
        if (!mFetcher.start(method(:onResult), 1)) {
            exitOnce(null);
        }
    }

    function onResult(errorMessage, reading) {
        // Fetcher a deja ecrit dans Store ; on renvoie aussi le resultat a
        // l'application via Background.exit() pour qu'elle se rafraichisse.
        if (errorMessage == null && reading != null) {
            exitOnce({ "r" => reading });
        } else if (errorMessage != null) {
            exitOnce({ "e" => errorMessage });
        } else {
            exitOnce(null);
        }
    }

    hidden function exitOnce(payload) {
        if (mExited) {
            return;
        }
        mExited = true;
        Background.exit(payload);
    }
}
