//
// Store - persistance locale (Application.Storage).
//
// Contient :
//  - la derniere mesure connue,
//  - un historique glissant (pour tracer la courbe sans re-telecharger),
//  - la session LibreLinkUp (jeton + identifiant de compte hashe).
//
// Le service background ecrit ici : la glance et l'application y relisent la
// valeur meme si elles n'ont pas fait de requete elles-memes.
//
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;

(:glance, :background)
module Store {

    const KEY_READING = "reading";
    const KEY_HISTORY = "history";
    const KEY_TOKEN = "lluToken";
    const KEY_TOKEN_EXP = "lluTokenExp";
    const KEY_ACCOUNT_ID = "lluAccountId";
    const KEY_REGION = "lluApiRegion";
    const KEY_PATIENT = "lluPatientId";
    const KEY_ERROR = "lastError";
    const KEY_ERROR_TS = "lastErrorTs";
    const KEY_FETCH_TS = "lastFetchTs";

    // 6 h max affichees, une mesure toutes les ~5 min => 72 points + marge.
    const HISTORY_MAX = 96;
    // Au-dela de 7 h une mesure ne sert plus au graphique.
    const HISTORY_MAX_AGE = 25200;

    function get(key) {
        try {
            return Application.Storage.getValue(key);
        } catch (e) {
            return null;
        }
    }

    function put(key, value) {
        try {
            Application.Storage.setValue(key, value);
        } catch (e) {
            // Storage plein ou indisponible : on ignore, ce n'est pas critique.
        }
    }

    // ---- Mesure courante ---------------------------------------------------

    //! Construit la representation compacte d'une mesure.
    //! v = mg/dL (Number), t = epoch secondes (Number), d = tendance (Number)
    function makeReading(mgdl, epochSeconds, trend) {
        return {
            "v" => mgdl.toNumber(),
            "t" => epochSeconds.toNumber(),
            "d" => (trend == null) ? Fmt.TREND_UNKNOWN : trend.toNumber()
        };
    }

    function readingValue(reading) {
        if (reading == null || !(reading instanceof Lang.Dictionary)) { return null; }
        return reading["v"];
    }

    function readingTime(reading) {
        if (reading == null || !(reading instanceof Lang.Dictionary)) { return null; }
        return reading["t"];
    }

    function readingTrend(reading) {
        if (reading == null || !(reading instanceof Lang.Dictionary)) { return Fmt.TREND_UNKNOWN; }
        var trend = reading["d"];
        return (trend == null) ? Fmt.TREND_UNKNOWN : trend;
    }

    function getReading() {
        var reading = get(KEY_READING);
        if (reading instanceof Lang.Dictionary && reading["v"] != null && reading["t"] != null) {
            return reading;
        }
        return null;
    }

    //! Enregistre une mesure si elle est plus recente que celle deja connue.
    //! @return true si le stockage a change
    function saveReading(reading) {
        if (reading == null) {
            return false;
        }
        var previous = getReading();
        var previousTime = readingTime(previous);
        var newTime = readingTime(reading);
        if (newTime == null) {
            return false;
        }
        if (previousTime != null && newTime <= previousTime) {
            // Rien de neuf (le capteur publie toutes les ~5 min).
            return false;
        }
        put(KEY_READING, reading);
        appendHistory(reading);
        return true;
    }

    // ---- Historique --------------------------------------------------------

    //! Historique sous forme d'Array de [epochSeconds, mgdl], du plus ancien au plus recent.
    function getHistory() {
        var history = get(KEY_HISTORY);
        if (history instanceof Lang.Array) {
            return history;
        }
        return [];
    }

    function appendHistory(reading) {
        var timestamp = readingTime(reading);
        var value = readingValue(reading);
        if (timestamp == null || value == null) {
            return;
        }
        var history = getHistory();
        var cutoff = Time.now().value() - HISTORY_MAX_AGE;
        var pruned = [];
        for (var i = 0; i < history.size(); i += 1) {
            var point = history[i];
            if (point instanceof Lang.Array && point.size() >= 2 && point[0] != null) {
                if (point[0] >= cutoff && point[0] < timestamp) {
                    pruned.add(point);
                }
            }
        }
        pruned.add([timestamp, value]);
        // On ne conserve que les HISTORY_MAX derniers points.
        if (pruned.size() > HISTORY_MAX) {
            pruned = pruned.slice(pruned.size() - HISTORY_MAX, pruned.size());
        }
        put(KEY_HISTORY, pruned);
    }

    //! Valeur mesuree environ `seconds` avant la mesure courante (pour le delta).
    //! @return mg/dL ou null si l'historique est trop court
    function valueBefore(referenceTime, seconds) {
        var history = getHistory();
        var target = referenceTime - seconds;
        var best = null;
        var bestGap = null;
        for (var i = 0; i < history.size(); i += 1) {
            var point = history[i];
            if (!(point instanceof Lang.Array) || point.size() < 2 || point[0] == null) {
                continue;
            }
            if (point[0] >= referenceTime) {
                continue;
            }
            var gap = (target - point[0]).abs();
            // On accepte une mesure a +/- 4 min de la cible.
            if (gap <= 240 && (bestGap == null || gap < bestGap)) {
                bestGap = gap;
                best = point[1];
            }
        }
        return best;
    }

    // ---- Session LibreLinkUp ----------------------------------------------

    function getToken() {
        var token = get(KEY_TOKEN);
        return (token instanceof Lang.String && token.length() > 0) ? token : null;
    }

    function getTokenExpiry() {
        var expiry = get(KEY_TOKEN_EXP);
        return (expiry instanceof Lang.Number) ? expiry : null;
    }

    //! Vrai si le jeton est present et valable encore au moins 5 minutes.
    function hasValidToken() {
        var token = getToken();
        var expiry = getTokenExpiry();
        if (token == null || expiry == null) {
            return false;
        }
        return expiry > (Time.now().value() + 300);
    }

    function saveSession(token, expiry, accountIdHash, region) {
        put(KEY_TOKEN, token);
        put(KEY_TOKEN_EXP, expiry);
        if (accountIdHash != null) {
            put(KEY_ACCOUNT_ID, accountIdHash);
        }
        if (region != null) {
            put(KEY_REGION, region);
        }
    }

    function getAccountId() {
        var accountId = get(KEY_ACCOUNT_ID);
        return (accountId instanceof Lang.String) ? accountId : null;
    }

    function getRegion() {
        var region = get(KEY_REGION);
        return (region instanceof Lang.String && region.length() > 0) ? region : null;
    }

    function setRegion(region) { put(KEY_REGION, region); }

    function getPatientId() {
        var patientId = get(KEY_PATIENT);
        return (patientId instanceof Lang.String) ? patientId : null;
    }

    function setPatientId(patientId) { put(KEY_PATIENT, patientId); }

    //! Invalide la session (mot de passe change, 401, region modifiee...).
    function clearSession() {
        put(KEY_TOKEN, null);
        put(KEY_TOKEN_EXP, null);
        put(KEY_ACCOUNT_ID, null);
    }

    // ---- Diagnostic --------------------------------------------------------

    function setError(message) {
        put(KEY_ERROR, message);
        put(KEY_ERROR_TS, Time.now().value());
    }

    function getError() {
        var error = get(KEY_ERROR);
        return (error instanceof Lang.String && error.length() > 0) ? error : null;
    }

    function clearError() {
        put(KEY_ERROR, null);
    }

    function markFetch() { put(KEY_FETCH_TS, Time.now().value()); }

    function getLastFetch() {
        var timestamp = get(KEY_FETCH_TS);
        return (timestamp instanceof Lang.Number) ? timestamp : null;
    }

    //! Fusionne une liste de points [epochSeconds, mgdl] dans l'historique.
    //! Utilise pour amorcer la courbe depuis Nightscout en une seule ecriture.
    function mergePoints(points) {
        if (!(points instanceof Lang.Array) || points.size() == 0) {
            return;
        }
        var cutoff = Time.now().value() - HISTORY_MAX_AGE;
        var merged = getHistory();
        for (var i = 0; i < points.size(); i += 1) {
            var candidate = points[i];
            if (!(candidate instanceof Lang.Array) || candidate.size() < 2) {
                continue;
            }
            if (candidate[0] == null || candidate[1] == null || candidate[0] < cutoff) {
                continue;
            }
            var duplicate = false;
            for (var j = 0; j < merged.size(); j += 1) {
                var existing = merged[j];
                if (existing instanceof Lang.Array && existing.size() >= 2 && existing[0] == candidate[0]) {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate) {
                merged.add(candidate);
            }
        }
        merged = sortByTime(merged);
        if (merged.size() > HISTORY_MAX) {
            merged = merged.slice(merged.size() - HISTORY_MAX, merged.size());
        }
        put(KEY_HISTORY, merged);
    }

    //! Tri croissant par horodatage (tri par insertion : l'historique est court
    //! et deja presque trie).
    function sortByTime(points) {
        var count = points.size();
        var sorted = new [count];
        for (var i = 0; i < count; i += 1) {
            sorted[i] = points[i];
        }
        for (var i = 1; i < count; i += 1) {
            var current = sorted[i];
            var j = i - 1;
            while (j >= 0 && sorted[j][0] > current[0]) {
                sorted[j + 1] = sorted[j];
                j -= 1;
            }
            sorted[j + 1] = current;
        }
        return sorted;
    }
}
