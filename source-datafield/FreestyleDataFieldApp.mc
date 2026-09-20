//
// FreestyleDataFieldApp - point d'entree du champ de donnees.
//
// Contrainte structurante de Connect IQ : un champ de donnees ne peut PAS
// faire de requete reseau lui-meme. Seul un service en arriere-plan le peut.
// Le champ se contente donc d'afficher ce que le service a depose dans
// Application.Storage, et le service fait le travail toutes les 5 minutes.
//
// C'est une application distincte de l'app principale : Connect IQ cloisonne le
// stockage de chacune, ce champ tient donc son propre historique et fait ses
// propres requetes. Les identifiants, eux, sont partages : ils viennent de
// source-common/Credentials.mc, compile dans les deux applications.
//
using Toybox.Application;
using Toybox.Background;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

class FreestyleDataFieldApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        scheduleBackground();
    }

    //! NE PAS supprimer ici le reveil periodique.
    //!
    //! onStop() est appele dans TOUS les contextes d'execution, y compris
    //! celui du service en arriere-plan : quand le service se termine par
    //! Background.exit(), onStop() suit. Y supprimer l'evenement temporel
    //! revenait a annuler la programmation apres le premier cycle, et le
    //! champ ne se rafraichissait plus du tout.
    function onStop(state) {
    }

    function getInitialView() {
        return [ new GlucoseDataField() ];
    }

    (:background)
    function getServiceDelegate() {
        return [ new BackgroundService() ];
    }

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

    function onSettingsChanged() {
        Store.clearSession();
        var configuredRegion = Config.lluRegion();
        if (!configuredRegion.equals(Store.getRegionSetting())) {
            Store.setRegionSetting(configuredRegion);
            Store.setRegion(configuredRegion);
        }
        Store.clearError();
        scheduleBackground();
        WatchUi.requestUpdate();
    }

    hidden function scheduleBackground() {
        if (!(Toybox has :Background)) {
            return;
        }
        try {
            // Meme condition que l'application : sans ce test, desactiver la mise
            // a jour en arriere-plan laisserait un evenement programme dont le
            // service ressort immediatement, figeant le champ en silence.
            if (Config.backgroundEnabled() && Config.isConfigured()) {
                // 5 minutes : minimum autorise par Connect IQ, et cadence de
                // publication du capteur Libre.
                Background.registerForTemporalEvent(new Time.Duration(300));
            } else {
                Background.deleteTemporalEvent();
            }
        } catch (e) {
            // Appareil sans support background : le champ affichera "--".
        }
    }
}
