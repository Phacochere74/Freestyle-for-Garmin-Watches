//
// Theme - couleurs et seuils d'affichage.
//
using Toybox.Graphics;
using Toybox.Time;

(:glance)
module Theme {

    // Au-dela de ce delai la mesure est consideree comme perimee et grisee.
    const STALE_SECONDS = 900;

    //! Couleur associee a une glycemie, selon les seuils configures.
    function colorForValue(mgdl) {
        if (mgdl == null) {
            return Graphics.COLOR_LT_GRAY;
        }
        if (mgdl <= Config.urgentLow() || mgdl >= Config.urgentHigh()) {
            return Graphics.COLOR_RED;
        }
        if (mgdl < Config.low()) {
            return Graphics.COLOR_ORANGE;
        }
        if (mgdl > Config.high()) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_GREEN;
    }

    //! Couleur effective : grisee si la mesure est trop ancienne.
    function colorForReading(mgdl, ageSeconds) {
        if (ageSeconds != null && ageSeconds > STALE_SECONDS) {
            return Graphics.COLOR_LT_GRAY;
        }
        return colorForValue(mgdl);
    }

    function isStale(ageSeconds) {
        return (ageSeconds == null || ageSeconds > STALE_SECONDS);
    }

    //! Age en secondes d'une mesure, ou null.
    function ageOf(reading) {
        var timestamp = Store.readingTime(reading);
        if (timestamp == null) {
            return null;
        }
        var age = Time.now().value() - timestamp;
        return (age < 0) ? 0 : age;
    }
}
