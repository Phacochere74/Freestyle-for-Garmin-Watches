//
// Fmt - helpers partages : conversion d'unites, formatage, parsing de dates,
// decoupage de chaines (Monkey C n'a pas de String.split natif).
//
// Ce module est utilise par l'application, la glance et le service background :
// il doit donc porter les deux annotations.
//
using Toybox.Lang;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;

(:glance, :background)
module Fmt {

    // Facteur de conversion officiel mg/dL -> mmol/L pour le glucose.
    const MMOL_PER_MGDL = 0.0555;

    // Tendances internes (independantes de la source de donnees).
    enum {
        TREND_UNKNOWN = 0,
        TREND_DOUBLE_DOWN = 1,
        TREND_SINGLE_DOWN = 2,
        TREND_FORTYFIVE_DOWN = 3,
        TREND_FLAT = 4,
        TREND_FORTYFIVE_UP = 5,
        TREND_SINGLE_UP = 6,
        TREND_DOUBLE_UP = 7
    }

    //! Decoupe une chaine selon un separateur. Retourne toujours un Array de String.
    //! @param str chaine a decouper (null -> tableau vide)
    //! @param sep separateur non vide
    function split(str, sep) {
        var out = [];
        if (str == null || sep == null || sep.length() == 0) {
            return out;
        }
        var rest = str;
        // Garde-fou : une chaine de 200 caracteres ne peut pas produire
        // plus de 200 morceaux, on borne la boucle par securite.
        for (var guard = 0; guard < 256; guard += 1) {
            var idx = rest.find(sep);
            if (idx == null) {
                out.add(rest);
                return out;
            }
            out.add(rest.substring(0, idx));
            rest = rest.substring(idx + sep.length(), rest.length());
            if (rest == null) {
                rest = "";
            }
        }
        out.add(rest);
        return out;
    }

    //! Supprime les espaces en debut et fin de chaine.
    function trim(str) {
        if (str == null) {
            return "";
        }
        var start = 0;
        var end = str.length();
        var chars = str.toCharArray();
        while (start < end && (chars[start] == ' ' || chars[start] == '\n' || chars[start] == '\r' || chars[start] == '\t')) {
            start += 1;
        }
        while (end > start && (chars[end - 1] == ' ' || chars[end - 1] == '\n' || chars[end - 1] == '\r' || chars[end - 1] == '\t')) {
            end -= 1;
        }
        return str.substring(start, end);
    }

    //! Retire un eventuel "/" final d'une URL.
    function stripTrailingSlash(url) {
        var u = trim(url);
        while (u.length() > 0 && u.substring(u.length() - 1, u.length()).equals("/")) {
            u = u.substring(0, u.length() - 1);
        }
        return u;
    }

    //! Convertit une valeur mg/dL en mmol/L.
    function toMmol(mgdl) {
        return mgdl * MMOL_PER_MGDL;
    }

    //! Formate une glycemie pour l'affichage.
    //! @param mgdl valeur en mg/dL (Number ou Float)
    //! @param mmol true si l'utilisateur veut des mmol/L
    function formatGlucose(mgdl, mmol) {
        if (mgdl == null) {
            return "--";
        }
        if (mmol) {
            return toMmol(mgdl.toFloat()).format("%.1f");
        }
        return Math.round(mgdl.toFloat()).toNumber().toString();
    }

    //! Formate un ecart (delta) signe entre deux mesures.
    function formatDelta(deltaMgdl, mmol) {
        if (deltaMgdl == null) {
            return "";
        }
        var text;
        if (mmol) {
            text = toMmol(deltaMgdl.toFloat()).format("%.1f");
        } else {
            text = Math.round(deltaMgdl.toFloat()).toNumber().toString();
        }
        if (deltaMgdl >= 0 && !text.substring(0, 1).equals("+")) {
            text = "+" + text;
        }
        return text;
    }

    //! Libelle de l'unite courante.
    function unitLabel(mmol) {
        return mmol ? "mmol/L" : "mg/dL";
    }

    //! Age d'une mesure, en texte court ("maintenant", "3 min", "2 h 10").
    function formatAge(seconds) {
        if (seconds == null || seconds < 0) {
            return "--";
        }
        if (seconds < 60) {
            return "<1 min";
        }
        var minutes = seconds / 60;
        if (minutes < 60) {
            return minutes.toNumber().toString() + " min";
        }
        var hours = minutes / 60;
        var rest = minutes % 60;
        return hours.toNumber().toString() + " h " + rest.toNumber().format("%02d");
    }

    //! Heure locale d'une mesure au format HH:MM.
    function formatClock(epochSeconds) {
        if (epochSeconds == null) {
            return "--:--";
        }
        var info = Gregorian.info(new Time.Moment(epochSeconds), Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

    //! Convertit la fleche de tendance LibreLinkUp (1..5) en constante interne.
    function trendFromLibre(arrow) {
        if (arrow == null) {
            return TREND_UNKNOWN;
        }
        var a = arrow.toNumber();
        if (a == 1) { return TREND_SINGLE_DOWN; }
        if (a == 2) { return TREND_FORTYFIVE_DOWN; }
        if (a == 3) { return TREND_FLAT; }
        if (a == 4) { return TREND_FORTYFIVE_UP; }
        if (a == 5) { return TREND_SINGLE_UP; }
        return TREND_UNKNOWN;
    }

    //! Convertit la direction Nightscout (texte) en constante interne.
    function trendFromNightscout(direction) {
        if (direction == null || !(direction instanceof Lang.String)) {
            return TREND_UNKNOWN;
        }
        if (direction.equals("DoubleUp")) { return TREND_DOUBLE_UP; }
        if (direction.equals("SingleUp")) { return TREND_SINGLE_UP; }
        if (direction.equals("FortyFiveUp")) { return TREND_FORTYFIVE_UP; }
        if (direction.equals("Flat")) { return TREND_FLAT; }
        if (direction.equals("FortyFiveDown")) { return TREND_FORTYFIVE_DOWN; }
        if (direction.equals("SingleDown")) { return TREND_SINGLE_DOWN; }
        if (direction.equals("DoubleDown")) { return TREND_DOUBLE_DOWN; }
        return TREND_UNKNOWN;
    }

    //! Angle (en degres, 0 = horizontal droite) associe a une tendance.
    function trendAngle(trend) {
        if (trend == TREND_DOUBLE_UP || trend == TREND_SINGLE_UP) { return 90; }
        if (trend == TREND_FORTYFIVE_UP) { return 45; }
        if (trend == TREND_FLAT) { return 0; }
        if (trend == TREND_FORTYFIVE_DOWN) { return -45; }
        if (trend == TREND_SINGLE_DOWN || trend == TREND_DOUBLE_DOWN) { return -90; }
        return 0;
    }

    //! Parse un horodatage LibreLinkUp "M/D/YYYY h:mm:ss AM|PM" (FactoryTimestamp, en UTC).
    //! Gere aussi le format 24h "M/D/YYYY HH:mm:ss".
    //! @return epoch en secondes (Number) ou null si non parsable
    function parseLibreTimestamp(str) {
        if (str == null || !(str instanceof Lang.String)) {
            return null;
        }
        var parts = split(trim(str), " ");
        if (parts.size() < 2) {
            return null;
        }
        var dmy = split(parts[0], "/");
        var hms = split(parts[1], ":");
        if (dmy.size() < 3 || hms.size() < 2) {
            return null;
        }
        var month = dmy[0].toNumber();
        var day = dmy[1].toNumber();
        var year = dmy[2].toNumber();
        var hour = hms[0].toNumber();
        var minute = hms[1].toNumber();
        var second = (hms.size() >= 3) ? hms[2].toNumber() : 0;
        if (month == null || day == null || year == null || hour == null || minute == null) {
            return null;
        }
        if (second == null) {
            second = 0;
        }
        if (parts.size() >= 3) {
            var meridiem = parts[2].toUpper();
            if (meridiem.equals("PM") && hour < 12) {
                hour += 12;
            } else if (meridiem.equals("AM") && hour == 12) {
                hour = 0;
            }
        }
        if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59) {
            return null;
        }
        // Gregorian.moment() interprete les champs comme de l'UTC, ce qui
        // correspond exactement au FactoryTimestamp de LibreLinkUp.
        var moment = Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => hour,
            :minute => minute,
            :second => second
        });
        return moment.value();
    }

    //! Parse un horodatage ISO-8601 UTC "YYYY-MM-DDTHH:MM:SS[.mmm]Z" (champ
    //! dateString de Nightscout). On le prefere au champ numerique `date`, qui
    //! est en millisecondes et depasse la capacite d'un Number 32 bits.
    //! @return epoch en secondes (Number) ou null
    function parseIso8601(str) {
        if (str == null || !(str instanceof Lang.String) || str.length() < 19) {
            return null;
        }
        var year = str.substring(0, 4).toNumber();
        var month = str.substring(5, 7).toNumber();
        var day = str.substring(8, 10).toNumber();
        var hour = str.substring(11, 13).toNumber();
        var minute = str.substring(14, 16).toNumber();
        var second = str.substring(17, 19).toNumber();
        if (year == null || month == null || day == null || hour == null || minute == null || second == null) {
            return null;
        }
        if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 60) {
            return null;
        }
        var moment = Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => hour,
            :minute => minute,
            :second => (second == 60) ? 59 : second
        });
        return moment.value();
    }
}
