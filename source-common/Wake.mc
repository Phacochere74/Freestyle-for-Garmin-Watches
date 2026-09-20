//
// Wake - programmation et surveillance du reveil periodique.
//
// Trois regles de la plateforme Connect IQ gouvernent ce fichier :
//
//   1. Une application ne peut enregistrer QU'UN SEUL evenement temporel.
//   2. registerForTemporalEvent() ECRASE l'enregistrement precedent. Le compte
//      a rebours repart donc de zero a chaque appel.
//   3. Un evenement enregistre avec une Duration SE REPETE tout seul. Il n'y a
//      rien a reprogrammer apres chaque declenchement.
//
// La version precedente appelait registerForTemporalEvent() depuis onStart(),
// qui s'execute dans TOUS les contextes : ouverture de l'application, affichage
// de la glance dans le carrousel, et execution du service lui-meme. Chacun de
// ces evenements repoussait le reveil suivant de 5 minutes (regle 2), alors
// qu'il n'y avait rien a reprogrammer (regle 3).
//
// D'ou les deux regles tenues ici :
//   - on n'enregistre que s'il n'y a RIEN d'enregistre ;
//   - on ne se fie pas a l'enregistrement : on verifie qu'il produit vraiment
//     des reveils, et on le refait une fois s'il est reste muet trop longtemps.
//
using Toybox.Background;
using Toybox.Time;

(:glance, :background)
module Wake {

    // 5 minutes : minimum impose par Connect IQ, et cadence de publication du
    // capteur Libre. Descendre plus bas fait echouer l'enregistrement.
    const PERIOD_SECONDS = 300;

    // Au-dela de 4 periodes sans aucun reveil, on considere l'enregistrement
    // perdu (redemarrage de la montre, mise a jour du logiciel, reinstallation)
    // et on le refait. Marge volontairement large : la montre a le droit de
    // retarder un reveil, et refaire l'enregistrement coute jusqu'a 5 minutes
    // de decalage supplementaire. Le controle ne peut se declencher qu'une fois
    // par periode de silence, puisque markWakeRegistered() repousse l'echeance.
    const STALE_SECONDS = 1200;

    //! Etat du reveil, lu en direct sur la plateforme.
    //! @return true si un evenement temporel est enregistre pour cette application
    function isRegistered() {
        if (!(Toybox has :Background)) {
            return false;
        }
        if (!(Background has :getTemporalEventRegisteredTime)) {
            // API trop ancienne pour savoir : on repond false, ce qui ramene au
            // comportement historique (reenregistrement).
            return false;
        }
        try {
            return Background.getTemporalEventRegisteredTime() != null;
        } catch (e) {
            return false;
        }
    }

    //! true si le service est enregistre mais n'a produit aucun reveil depuis
    //! STALE_SECONDS. Sert aussi a l'affichage de diagnostic.
    function isStale() {
        if (!isRegistered()) {
            return false;
        }
        // Date de reference : le dernier reveil reel, ou a defaut la date
        // d'enregistrement tant qu'aucun reveil n'a encore eu lieu.
        var reference = Store.getLastWakeRun();
        if (reference == null) {
            reference = Store.getWakeSince();
        }
        if (reference == null) {
            return false;
        }
        return (Time.now().value() - reference) > STALE_SECONDS;
    }

    //! Met le reveil en accord avec les reglages, et le repare s'il est mort.
    //! Idempotent : n'ecrase jamais un enregistrement qui fonctionne.
    //! @return true si un reveil est programme quand la fonction rend la main
    function schedule() {
        if (!(Toybox has :Background)) {
            return false;
        }

        if (!(Config.backgroundEnabled() && Config.isConfigured())) {
            if (isRegistered()) {
                try {
                    Background.deleteTemporalEvent();
                } catch (e) {
                    // L'evenement restera ; onTemporalEvent reteste la config
                    // et ressortira immediatement. Sans consequence.
                }
            }
            Store.clearWakeSince();
            return false;
        }

        if (!isRegistered()) {
            return register();
        }

        if (isStale()) {
            try {
                Background.deleteTemporalEvent();
            } catch (e) {
            }
            return register();
        }

        // Enregistre et vivant : surtout ne rien faire (regles 2 et 3).
        if (Store.getWakeSince() == null) {
            // Enregistrement herite d'une version anterieure : on date le
            // point de depart de la surveillance, sans toucher a l'evenement.
            Store.markWakeRegistered();
        }
        return true;
    }

    //! Enregistre l'evenement repetitif et date l'operation.
    function register() {
        try {
            Background.registerForTemporalEvent(new Time.Duration(PERIOD_SECONDS));
            Store.markWakeRegistered();
            return true;
        } catch (e) {
            // Refus le plus probable : moins de 5 minutes depuis le dernier
            // evenement temporel. Le prochain passage reessaiera.
            return false;
        }
    }
}
