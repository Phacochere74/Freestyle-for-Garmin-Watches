//
// ComplicationPublisher - publication de la glycemie comme complication.
//
// Mecanisme publieur/abonne de Connect IQ (API 4.2.0+) : une application
// publie une valeur, un cadran s'y abonne et l'affiche. Seuls les cadrans
// peuvent s'abonner ; seules les applications et les fournisseurs de contenu
// audio peuvent publier, jusqu'a quatre complications chacun.
//
// La complication est declaree en access="public" : elle devient visible par
// tous les cadrans, y compris Face It. Les cadrans Garmin d'origine, eux, ne
// lisent pas les complications tierces - il faut un cadran du store qui les
// prenne en charge.
//
// Seule l'application declare la complication dans son manifeste. Ce module
// etant partage, le champ de donnees l'appelle aussi : updateComplication()
// leve alors OperationNotAllowedException, que l'on absorbe.
//
using Toybox.Lang;

(:glance, :background)
module ComplicationPublisher {

    // Doit correspondre a l'attribut id du bloc <complications> des ressources.
    // A garder stable d'une version a l'autre : le changer casserait les
    // cadrans qui se sont abonnes a la precedente.
    const COMPLICATION_ID = 0;

    //! Publie la mesure courante vers les cadrans abonnes.
    //! Sans effet si l'appareil ne gere pas les complications, ou si
    //! l'application appelante ne les declare pas.
    function publish(reading) {
        if (!(Toybox has :Complications)) {
            return;
        }

        var mgdl = Store.readingValue(reading);
        var mmol = Config.useMmol();
        var texte = Fmt.formatGlucose(mgdl, mmol);

        var valeur;
        if (mgdl == null) {
            valeur = null;
        } else if (mmol) {
            valeur = Fmt.toMmol(mgdl.toFloat());
        } else {
            valeur = mgdl.toNumber();
        }

        // Les bornes permettent aux cadrans de colorer la valeur. Elles sont
        // republiees dans l'unite d'affichage choisie : les valeurs statiques
        // du fichier de ressources sont en mg/dL et seraient fausses en mmol/L.
        var bornes = [
            echelle(Config.urgentLow(), mmol),
            echelle(Config.low(), mmol),
            echelle(Config.high(), mmol),
            echelle(Config.urgentHigh(), mmol)
        ];

        // shortLabel est limite a cinq caracteres et sert aux complications
        // radiales : on y met la valeur, plus utile qu'un libelle fixe.
        var data = {
            :ranges => bornes,
            :value => valeur,
            :shortLabel => texte,
            // La documentation du SDK se contredit : le guide emploie :units,
            // la definition de type emploie :unit. On fournit les deux, la cle
            // inutilisee etant simplement ignoree.
            :unit => Fmt.unitLabel(mmol),
            :units => Fmt.unitLabel(mmol)
        };


        try {
            Toybox.Complications.updateComplication(COMPLICATION_ID, data);
        } catch (e) {
            // Application ne declarant pas cette complication (le champ de
            // donnees), ou complications indisponibles sur l'appareil.
        }
    }

    //! Convertit un seuil en mg/dL vers l'unite d'affichage.
    hidden function echelle(mgdl, mmol) {
        if (mmol) {
            return Fmt.toMmol(mgdl.toFloat());
        }
        return mgdl.toNumber();
    }
}
