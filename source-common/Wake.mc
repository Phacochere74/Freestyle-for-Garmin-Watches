//
// Wake - programmation du reveil periodique du service en arriere-plan.
//
// Trois regles de la plateforme Connect IQ gouvernent ce fichier :
//
//   1. Une seule application peut enregistrer UN SEUL evenement temporel.
//   2. registerForTemporalEvent() ECRASE l'enregistrement precedent. Le compte
//      a rebours repart donc de zero a chaque appel.
//   3. Un evenement enregistre avec une Duration SE REPETE tout seul. Il n'y a
//      rien a reprogrammer apres chaque declenchement.
//
// La version precedente appelait registerForTemporalEvent() depuis onStart(),
// qui s'execute dans TOUS les contextes : ouverture de l'application, affichage
// de la glance dans le carrousel, et execution du service lui-meme. Chacun de
// ces evenements repoussait donc le reveil suivant de 5 minutes supplementaires
// (regle 2), alors qu'il n'y avait rien a reprogrammer (regle 3).
//
// D'ou la regle tenue ici : on n'enregistre que s'il n'y a RIEN d'enregistre.
//
using Toybox.Background;
using Toybox.Time;

(:glance, :background)
module Wake {

    // 5 minutes : minimum impose par Connect IQ, et cadence de publication du
    // capteur Libre. Descendre plus bas fait echouer l'enregistrement.
    const PERIOD_SECONDS = 300;

    //! Etat du reveil periodique, lu en direct sur la plateforme.
    //! @return true si un evenement temporel est enregistre pour cette application
    function isRegistered() {
        if (!(Toybox has :Background)) {
            return false;
        }
        if (!(Background has :getTemporalEventRegisteredTime)) {
            // API anterieure a Connect IQ 2.x : impossible de savoir. On repond
            // false, ce qui ramene au comportement historique (reenregistrement).
            return false;
        }
        try {
            return Background.getTemporalEventRegisteredTime() != null;
        } catch (e) {
            return false;
        }
    }

    //! Met le reveil periodique en accord avec les reglages.
    //! Idempotent : n'ecrase JAMAIS un enregistrement deja en place.
    //! @return true si un reveil est programme quand la fonction rend la main
    function schedule() {
        if (!(Toybox has :Background)) {
            return false;
        }

        var registered = isRegistered();
        var wanted = Config.backgroundEnabled() && Config.isConfigured();

        if (!wanted) {
            if (registered) {
                try {
                    Background.deleteTemporalEvent();
                } catch (e) {
                    // Rien a faire : l'evenement restera, le service ressortira
                    // immediatement puisque onTemporalEvent reteste la config.
                }
            }
            return false;
        }

        if (registered) {
            // Deja programme. Reenregistrer relancerait le compte a rebours.
            return true;
        }

        try {
            Background.registerForTemporalEvent(new Time.Duration(PERIOD_SECONDS));
            return true;
        } catch (e) {
            // Refus le plus probable : moins de 5 minutes se sont ecoulees
            // depuis le dernier evenement temporel. Le prochain passage dans
            // schedule() reessaiera.
            return false;
        }
    }
}
