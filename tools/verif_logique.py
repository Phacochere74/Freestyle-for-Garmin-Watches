#!/usr/bin/env python3
"""Verification de la LOGIQUE du code Monkey C, hors de la montre.

Le SDK Connect IQ ne tourne pas partout : ce script transcrit fidelement en
Python les fonctions pures de source-common/ (parsing de dates, conversions
d'unites, tendances, historique, seuils) et les confronte a des cas reels,
y compris les cas limites qui font les bugs silencieux.

Il ne valide PAS la syntaxe Monkey C ni les appels d'API Garmin : seule une
compilation avec monkeyc peut le faire. Il valide que les regles de calcul
sont justes.

    python3 tools/verif_logique.py
"""
import calendar
import sys

# --------------------------------------------------------------------------
# Transcription de source-common/Fmt.mc
# --------------------------------------------------------------------------

MGDL_PER_MMOL = 18.0182

TREND_UNKNOWN, TREND_DOUBLE_DOWN, TREND_SINGLE_DOWN, TREND_FORTYFIVE_DOWN, \
    TREND_FLAT, TREND_FORTYFIVE_UP, TREND_SINGLE_UP, TREND_DOUBLE_UP = range(8)


def to_number(text):
    """Equivalent de String.toNumber() : None si non convertible."""
    try:
        return int(text)
    except (TypeError, ValueError):
        return None


def mc_round(value):
    """Math.round() de Monkey C : arrondi a l'entier le plus proche,
    les demis s'eloignant de zero (contrairement au round() de Python)."""
    return int(value + 0.5) if value >= 0 else -int(-value + 0.5)


def to_mmol(mgdl):
    return mgdl / MGDL_PER_MMOL


def format_glucose(mgdl, mmol):
    if mgdl is None:
        return "--"
    if mmol:
        return "%.1f" % to_mmol(float(mgdl))
    return str(mc_round(float(mgdl)))


def format_delta(delta_mgdl, mmol):
    if delta_mgdl is None:
        return ""
    if mmol:
        text = "%.1f" % to_mmol(float(delta_mgdl))
    else:
        text = str(mc_round(float(delta_mgdl)))
    if delta_mgdl >= 0 and not text.startswith("+"):
        text = "+" + text
    return text


def format_age(seconds):
    if seconds is None or seconds < 0:
        return "--"
    if seconds < 60:
        return "<1 min"
    minutes = seconds // 60          # division entiere, comme en Monkey C
    if minutes < 60:
        return "%d min" % minutes
    return "%d h %02d" % (minutes // 60, minutes % 60)


def trend_from_libre(arrow):
    return {1: TREND_SINGLE_DOWN, 2: TREND_FORTYFIVE_DOWN, 3: TREND_FLAT,
            4: TREND_FORTYFIVE_UP, 5: TREND_SINGLE_UP}.get(arrow, TREND_UNKNOWN)


def trend_from_nightscout(direction):
    return {"DoubleUp": TREND_DOUBLE_UP, "SingleUp": TREND_SINGLE_UP,
            "FortyFiveUp": TREND_FORTYFIVE_UP, "Flat": TREND_FLAT,
            "FortyFiveDown": TREND_FORTYFIVE_DOWN, "SingleDown": TREND_SINGLE_DOWN,
            "DoubleDown": TREND_DOUBLE_DOWN}.get(direction, TREND_UNKNOWN)


def split(text, sep):
    return text.split(sep)


def parse_libre_timestamp(text):
    """FactoryTimestamp : "M/D/YYYY h:mm:ss AM|PM", en UTC. Gere aussi le 24 h."""
    if not isinstance(text, str):
        return None
    parts = split(text.strip(), " ")
    if len(parts) < 2:
        return None
    dmy = split(parts[0], "/")
    hms = split(parts[1], ":")
    if len(dmy) < 3 or len(hms) < 2:
        return None
    month, day, year = to_number(dmy[0]), to_number(dmy[1]), to_number(dmy[2])
    hour, minute = to_number(hms[0]), to_number(hms[1])
    second = to_number(hms[2]) if len(hms) >= 3 else 0
    if None in (month, day, year, hour, minute):
        return None
    if second is None:
        second = 0
    if len(parts) >= 3:
        meridiem = parts[2].upper()
        if meridiem == "PM" and hour < 12:
            hour += 12
        elif meridiem == "AM" and hour == 12:
            hour = 0
    if month < 1 or month > 12 or day < 1 or day > 31 or hour > 23 or minute > 59:
        return None
    return calendar.timegm((year, month, day, hour, minute, second, 0, 0, 0))


def parse_iso8601(text):
    """Nightscout dateString : "YYYY-MM-DDTHH:MM:SS[.mmm]Z", en UTC."""
    if not isinstance(text, str) or len(text) < 19:
        return None
    year, month, day = to_number(text[0:4]), to_number(text[5:7]), to_number(text[8:10])
    hour, minute, second = to_number(text[11:13]), to_number(text[14:16]), to_number(text[17:19])
    if None in (year, month, day, hour, minute, second):
        return None
    if month < 1 or month > 12 or day < 1 or day > 31 or hour > 23 or minute > 59 or second > 60:
        return None
    return calendar.timegm((year, month, day, hour, minute,
                            59 if second == 60 else second, 0, 0, 0))


# --------------------------------------------------------------------------
# Transcription de source-common/LibreLinkUpClient.mc (extraction de la mesure)
# --------------------------------------------------------------------------

def extract_mgdl(measurement, uom):
    """Reproduit onConnections() : ValueInMgPerDl, sinon repli sur Value+uom."""
    mgdl = measurement.get("ValueInMgPerDl")
    if mgdl is not None:
        return int(mgdl)
    value = measurement.get("Value")
    if value is None:
        return None
    value = float(value)
    if uom == 2:                       # le compte est configure en mmol/L
        value = value * MGDL_PER_MMOL
    return mc_round(value)


# --------------------------------------------------------------------------
# Transcription de source-common/Store.mc (historique)
# --------------------------------------------------------------------------

HISTORY_MAX = 96
HISTORY_MAX_AGE = 25200


def append_history(history, timestamp, value, now):
    cutoff = now - HISTORY_MAX_AGE
    pruned = [p for p in history if p[0] >= cutoff and p[0] < timestamp]
    pruned.append([timestamp, value])
    if len(pruned) > HISTORY_MAX:
        pruned = pruned[len(pruned) - HISTORY_MAX:]
    return pruned


def sort_by_time(points):
    """Tri par insertion, transcrit tel quel."""
    sorted_points = list(points)
    for i in range(1, len(sorted_points)):
        current = sorted_points[i]
        j = i - 1
        while j >= 0 and sorted_points[j][0] > current[0]:
            sorted_points[j + 1] = sorted_points[j]
            j -= 1
        sorted_points[j + 1] = current
    return sorted_points


def merge_points(history, points, now):
    cutoff = now - HISTORY_MAX_AGE
    merged = list(history)
    for candidate in points:
        if candidate[0] < cutoff:
            continue
        if any(existing[0] == candidate[0] for existing in merged):
            continue
        merged.append(candidate)
    merged = sort_by_time(merged)
    if len(merged) > HISTORY_MAX:
        merged = merged[len(merged) - HISTORY_MAX:]
    return merged


def value_before(history, reference_time, seconds):
    target = reference_time - seconds
    best, best_gap = None, None
    for point in history:
        if point[0] >= reference_time:
            continue
        gap = abs(target - point[0])
        if gap <= 240 and (best_gap is None or gap < best_gap):
            best_gap, best = gap, point[1]
    return best


# --------------------------------------------------------------------------
# Transcription de source-common/Theme.mc (seuils)
# --------------------------------------------------------------------------

URGENT_LOW, LOW, HIGH, URGENT_HIGH = 55, 70, 180, 250


def color_for_value(mgdl):
    if mgdl is None:
        return "GRIS"
    if mgdl <= URGENT_LOW or mgdl >= URGENT_HIGH:
        return "ROUGE"
    if mgdl < LOW:
        return "ORANGE"
    if mgdl > HIGH:
        return "JAUNE"
    return "VERT"


# --------------------------------------------------------------------------
# Cas de test
# --------------------------------------------------------------------------

FAILURES = []


def check(label, actual, expected):
    if actual == expected:
        print("  ok   %-58s %r" % (label, actual))
    else:
        print("  FAIL %-58s obtenu %r, attendu %r" % (label, actual, expected))
        FAILURES.append(label)


def utc(y, mo, d, h, mi, s=0):
    return calendar.timegm((y, mo, d, h, mi, s, 0, 0, 0))


print("\n[1] Horodatage LibreLinkUp (FactoryTimestamp, UTC)")
check("apres-midi : 8:15:00 PM",
      parse_libre_timestamp("9/11/2026 8:15:00 PM"), utc(2026, 9, 11, 20, 15))
check("minuit : 12:05:00 AM -> 00:05",
      parse_libre_timestamp("12/1/2026 12:05:00 AM"), utc(2026, 12, 1, 0, 5))
check("midi : 12:05:00 PM -> 12:05",
      parse_libre_timestamp("12/1/2026 12:05:00 PM"), utc(2026, 12, 1, 12, 5))
check("format 24 h sans AM/PM",
      parse_libre_timestamp("9/11/2026 20:15:00"), utc(2026, 9, 11, 20, 15))
check("jour et mois sur deux chiffres",
      parse_libre_timestamp("09/01/2026 07:05:00 AM"), utc(2026, 9, 1, 7, 5))
check("chaine vide -> None", parse_libre_timestamp(""), None)
check("format inattendu -> None", parse_libre_timestamp("hier soir"), None)
check("mois invalide -> None", parse_libre_timestamp("13/1/2026 10:00:00 AM"), None)
check("valeur non textuelle -> None", parse_libre_timestamp(1757620500), None)

print("\n[2] Horodatage Nightscout (dateString, ISO-8601 UTC)")
check("format standard",
      parse_iso8601("2026-09-11T18:15:00.000Z"), utc(2026, 9, 11, 18, 15))
check("sans millisecondes",
      parse_iso8601("2026-09-11T18:15:42Z"), utc(2026, 9, 11, 18, 15, 42))
check("seconde intercalaire ramenee a 59",
      parse_iso8601("2026-06-30T23:59:60Z"), utc(2026, 6, 30, 23, 59, 59))
check("trop court -> None", parse_iso8601("2026-09-11"), None)

print("\n[3] Extraction de la mesure LibreLinkUp")
check("ValueInMgPerDl prioritaire",
      extract_mgdl({"ValueInMgPerDl": 124, "Value": 6.9}, 2), 124)
check("repli Value en mmol/L (6.9 -> 124, pas 108)",
      extract_mgdl({"Value": 6.9}, 2), 124)
check("repli Value en mmol/L, zone basse (3.9 -> 70, pas 54)",
      extract_mgdl({"Value": 3.9}, 2), 70)
check("repli Value deja en mg/dL", extract_mgdl({"Value": 124}, 1), 124)
check("aucune valeur -> None", extract_mgdl({}, 1), None)

print("\n[4] Conversion et formatage")
check("180 mg/dL en mmol/L", format_glucose(180, True), "10.0")
check("70 mg/dL en mmol/L", format_glucose(70, True), "3.9")
check("124 mg/dL en mg/dL", format_glucose(124, False), "124")
check("absence de mesure", format_glucose(None, True), "--")
check("delta positif en mg/dL", format_delta(7, False), "+7")
check("delta negatif en mg/dL", format_delta(-12, False), "-12")
check("delta positif en mmol/L", format_delta(7, True), "+0.4")
check("delta nul", format_delta(0, False), "+0")

print("\n[5] Anciennete de la mesure")
check("30 s", format_age(30), "<1 min")
check("exactement 60 s", format_age(60), "1 min")
check("185 s", format_age(185), "3 min")
check("59 min", format_age(3540), "59 min")
check("exactement 1 h", format_age(3600), "1 h 00")
check("2 h 10", format_age(7830), "2 h 10")

print("\n[6] Tendances")
check("LibreLinkUp 1 = descente", trend_from_libre(1), TREND_SINGLE_DOWN)
check("LibreLinkUp 3 = stable", trend_from_libre(3), TREND_FLAT)
check("LibreLinkUp 5 = montee", trend_from_libre(5), TREND_SINGLE_UP)
check("LibreLinkUp valeur inconnue", trend_from_libre(9), TREND_UNKNOWN)
check("Nightscout Flat", trend_from_nightscout("Flat"), TREND_FLAT)
check("Nightscout DoubleDown", trend_from_nightscout("DoubleDown"), TREND_DOUBLE_DOWN)
check("Nightscout NOT COMPUTABLE", trend_from_nightscout("NOT COMPUTABLE"), TREND_UNKNOWN)

print("\n[7] Historique glissant")
now = utc(2026, 9, 11, 18, 0)

# Deux limites se combinent, et chacune domine dans un cas different.
# a) Cadence normale du capteur Libre : une mesure / 5 min. C'est la purge par
#    anciennete qui borne, a 7 h / 5 min = 84 points. Le plafond de 96 ne sert pas.
history = []
for i in range(120):                       # 10 h de mesures toutes les 5 min
    history = append_history(history, now - (120 - i) * 300, 100 + i, now)
check("cadence 5 min : borne par l'anciennete (7 h = 84 points)", len(history), 84)
check("trie du plus ancien au plus recent",
      history == sorted(history, key=lambda p: p[0]), True)
check("purge les points de plus de 7 h",
      all(p[0] >= now - HISTORY_MAX_AGE for p in history), True)

# b) Source dense (un Nightscout alimente par xDrip peut publier chaque minute) :
#    c'est le plafond de 96 points qui protege la memoire.
dense = []
for i in range(300):                       # 5 h de mesures chaque minute
    dense = append_history(dense, now - (300 - i) * 60, 100, now)
check("cadence 1 min : borne par le plafond de points", len(dense), HISTORY_MAX)
check("le plafond conserve bien les plus recents",
      dense[-1][0], now - 60)

check("tri par insertion sur entree inversee",
      [p[0] for p in sort_by_time([[30, 1], [10, 2], [20, 3]])], [10, 20, 30])
check("fusion sans doublon d'horodatage",
      len(merge_points([[now - 300, 100]], [[now - 300, 999], [now - 600, 95]], now)), 2)

cadence = [[now - i * 300, 100 + i] for i in range(12)]
check("valeur d'il y a 15 min (3 mesures en arriere)",
      value_before(cadence, now, 900), 103)
check("valeur d'il y a 15 min absente de l'historique",
      value_before([[now - 60, 120]], now, 900), None)

print("\n[8] Couleurs aux bornes des seuils")
check("55 = seuil hypo severe -> rouge", color_for_value(55), "ROUGE")
check("56 -> orange", color_for_value(56), "ORANGE")
check("69 -> orange", color_for_value(69), "ORANGE")
check("70 = seuil bas, dans la cible -> vert", color_for_value(70), "VERT")
check("180 = seuil haut, dans la cible -> vert", color_for_value(180), "VERT")
check("181 -> jaune", color_for_value(181), "JAUNE")
check("249 -> jaune", color_for_value(249), "JAUNE")
check("250 = seuil hyper severe -> rouge", color_for_value(250), "ROUGE")

print("\n" + "=" * 74)
if FAILURES:
    print("%d test(s) en echec : %s" % (len(FAILURES), ", ".join(FAILURES)))
    sys.exit(1)
print("Tous les tests de logique passent.")
print("Rappel : ceci ne valide ni la syntaxe Monkey C ni les appels d'API Garmin.")
