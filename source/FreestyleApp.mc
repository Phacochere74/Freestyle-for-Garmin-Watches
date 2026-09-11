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
using Toybox.Background;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

class FreestyleApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        scheduleBackground();
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
        // Les identifiants ou la region ont pu changer : la session en cache
        // n'est plus forcement valable.
        Store.clearSession();
        Store.setRegion(Config.lluRegion());
        Store.clearError();
        scheduleBackground();
        WatchUi.requestUpdate();
    }

    //! (Re)programme ou supprime le reveil periodique du service background.
    hidden function scheduleBackground() {
        if (!(Toybox has :Background)) {
            return;
        }
        try {
            if (Config.backgroundEnabled() && Config.isConfigured()) {
                // 5 minutes est le minimum autorise par Connect IQ, et
                // correspond a la cadence de publication du capteur Libre.
                Background.registerForTemporalEvent(new Time.Duration(300));
            } else {
                Background.deleteTemporalEvent();
            }
        } catch (e) {
            // Appareil sans support background ou quota atteint : sans effet.
        }
    }
}
