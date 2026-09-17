//
// Net - utilitaires reseau partages : libelles d'erreur lisibles et SHA-256.
//
using Toybox.Communications;
using Toybox.Lang;
using Toybox.StringUtil;

(:glance, :background)
module Net {

    //! Traduit un code de reponse Connect IQ en message court affichable.
    //! Les codes negatifs sont des erreurs locales (BLE, telephone, memoire),
    //! les codes positifs sont des codes HTTP renvoyes par le serveur.
    function describeError(code) {
        if (code == null) {
            return "Erreur inconnue";
        }
        // Codes locaux Connect IQ (negatifs).
        if (code == -2 || code == -3 || code == -200) { return "Delai depasse"; }
        if (code == -4) { return "Pas de donnees"; }
        if (code == -101) { return "File d'attente pleine"; }
        if (code == -104) { return "Telephone non connecte"; }
        if (code == -201 || code == -202) { return "Reponse trop volumineuse"; }
        if (code == -300) { return "Stockage plein"; }
        if (code == -400) { return "HTTPS requis"; }
        if (code == -401) { return "Type de contenu refuse"; }
        if (code == -402) { return "Connexion interrompue"; }
        if (code == -1000) { return "En-tetes invalides"; }
        if (code == -1001) { return "Corps de requete invalide"; }
        // Codes HTTP.
        if (code == 400) { return "Requete refusee (400)"; }
        if (code == 401 || code == 403) { return "Acces refuse"; }
        if (code == 404) { return "Introuvable (404)"; }
        if (code == 429) { return "Trop de requetes"; }
        if (code == 430) { return "Serveur occupe"; }
        if (code >= 500 && code <= 599) { return "Serveur indisponible"; }
        if (code < 0) { return "Erreur reseau " + code.toString(); }
        return "HTTP " + code.toString();
    }

    //! SHA-256 d'une chaine, rendu en hexadecimal minuscule.
    //! Utilise par l'en-tete Account-Id exige par l'API LibreLinkUp.
    //! @return String, ou null si le module Cryptography n'est pas disponible
    function sha256Hex(input) {
        if (input == null || !(input instanceof Lang.String) || input.length() == 0) {
            return null;
        }
        if (!(Toybox has :Cryptography)) {
            return null;
        }
        try {
            var bytes = StringUtil.convertEncodedString(input, {
                :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY
            });
            // La classe est Cryptography.Hash (et non Hasher) ; HASH_SHA256 est
            // le seul algorithme de hachage expose depuis Connect IQ 3.0.
            var hasher = new Toybox.Cryptography.Hash({
                :algorithm => Toybox.Cryptography.HASH_SHA256
            });
            hasher.update(bytes);
            var digest = hasher.digest();
            var hex = StringUtil.convertEncodedString(digest, {
                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX
            });
            if (hex == null) {
                return null;
            }
            return hex.toLower();
        } catch (e) {
            return null;
        }
    }

    //! Convertit en Number un champ JSON qui peut arriver en Number, Float ou String.
    function asNumber(value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Lang.Number) {
            return value;
        }
        if (value instanceof Lang.Float || value instanceof Lang.Double) {
            return value.toNumber();
        }
        if (value instanceof Lang.String) {
            return value.toNumber();
        }
        return null;
    }

    //! Comme asNumber, mais sans perdre la partie decimale.
    //! Indispensable pour une valeur en mmol/L : tronquer 6.9 en 6 avant
    //! conversion donnerait 108 mg/dL au lieu de 124.
    function asFloat(value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Lang.Float || value instanceof Lang.Double) {
            return value.toFloat();
        }
        if (value instanceof Lang.Number) {
            return value.toFloat();
        }
        if (value instanceof Lang.String) {
            return value.toFloat();
        }
        return null;
    }

    //! Lecture defensive d'une cle dans un Dictionary issu du JSON.
    function dictGet(dict, key) {
        if (dict == null || !(dict instanceof Lang.Dictionary)) {
            return null;
        }
        return dict[key];
    }
}
