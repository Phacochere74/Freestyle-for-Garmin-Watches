//
// FreestyleApp - point d'entree de l'application.
//
// Trois contextes d'execution coexistent, chacun avec sa propre limite memoire :
//   - l'application complete (getInitialView)
//   - la glance, le petit resume dans la liste des widgets (getGlanceView)
//   - le service background, qui rafraichit toutes les 5 min (getServiceDelegate)
//
// Les annotations (:glance) et (:background) indiquent au compilateur quel code
// embarquer dans quel binaire.
//
using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class FreestyleApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    //! onStart() est appele dans TOUS les contextes : application, glance et
    //! service en arriere-plan. Wake.schedule() est idempotent, c'est ce qui
    //! rend cet appel inoffensif ici (voir source-common/Wake.mc).
    function onStart(state) {
        Wake.schedule();
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new MainView();
        return [ view, new MainDelegate(view) ];
    }

    (:glance)
    function getGlanceView() {
        return [ new FreestyleGlanceView() ];
    }

    (:background)
    function getServiceDelegate() {
        return [ new BackgroundService() ];
    }

    //! Resultat renvoye par le service background via Background.exit().
    //! Appele quand l'application (ou sa glance) s'execute a nouveau.
    function onBackgroundData(data) {
        if (data instanceof Lang.Dictionary) {
            var reading = data["r"];
            if (reading instanceof Lang.Dictionary) {
                Store.saveReading(reading);
                Store.clearError();
                // Republication ici aussi : la publication faite depuis le
                // service en arriere-plan peut etre refusee selon le contexte
                // d'execution, celle-ci a lieu dans l'application elle-meme.
                ComplicationPublisher.publish(reading);
            }
            var errorMessage = data["e"];
            if (errorMessage instanceof Lang.String) {
                Store.setError(errorMessage);
            }
        }
        WatchUi.requestUpdate();
    }

    //! Appele quand les reglages sont modifies depuis Garmin Connect.
    function onSettingsChanged() {
        // Les identifiants ont pu changer : la session en cache n'est plus
        // forcement valable.
        Store.clearSession();
        // La region apprise par redirection ne doit etre ecrasee que si
        // l'utilisateur a reellement modifie le reglage de region : sinon chaque
        // enregistrement de reglages relancerait un aller-retour de redirection.
        var configuredRegion = Config.lluRegion();
        if (!configuredRegion.equals(Store.getRegionSetting())) {
            Store.setRegionSetting(configuredRegion);
            Store.setRegion(configuredRegion);
        }
        Store.clearError();
        Wake.schedule();
        WatchUi.requestUpdate();
    }

}
