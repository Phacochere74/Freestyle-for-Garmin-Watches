# Notes sur l'API LibreLinkUp

API **non officielle** : Abbott ne la documente pas et la fait évoluer sans
préavis. Ces notes décrivent ce que l'application implémente et d'où vient
l'information, pour pouvoir diagnostiquer une panne.

## Base d'URL

```
https://api-<region>.libreview.io
```

`<region>` vaut `eu` par défaut. Si le compte appartient à une autre région, la
réponse de login contient `data.redirect = true` et `data.region` : l'application
mémorise la nouvelle région (`Store.setRegion`) et rejoue la requête.

## En-têtes communs

| En-tête | Valeur | Remarque |
|---|---|---|
| `Content-Type` | `application/json` | |
| `product` | `llu.android` | obligatoire |
| `version` | `4.16.0` par défaut | **modifiable dans les réglages** : Abbott relève régulièrement la version minimale acceptée |
| `User-Agent` | `LibreLinkUp/<version>` | requis d'après plusieurs implémentations ; Connect IQ peut l'écraser |
| `Authorization` | `Bearer <token>` | requêtes authentifiées |
| `Account-Id` | SHA-256 hexadécimal minuscule de `data.user.id` | requis depuis les versions récentes de l'API |

## 1. Connexion

```
POST /llu/auth/login
{ "email": "...", "password": "..." }
```

Réponse utile :

- `status` : `0` = succès, `2` = identifiants refusés, `4` = conditions
  d'utilisation à accepter dans l'application LibreLinkUp
- `data.authTicket.token` : jeton Bearer
- `data.authTicket.expires` : expiration, epoch en secondes
- `data.user.id` : à hacher en SHA-256 pour l'en-tête `Account-Id`
- `data.redirect` / `data.region` : redirection de région

L'application conserve le jeton jusqu'à 5 minutes avant son expiration
(`Store.hasValidToken`), et rejoue une authentification complète sur un 401/403.

## 2. Dernière mesure

```
GET /llu/connections
```

Réponse : `data` est une liste de patients suivis. L'application prend le premier.

Champs lus dans `data[0].glucoseMeasurement` :

| Champ | Usage |
|---|---|
| `ValueInMgPerDl` | valeur canonique, toujours en mg/dL |
| `Value` + `data[0].uom` | repli (`uom` : 1 = mg/dL, 2 = mmol/L) |
| `FactoryTimestamp` | horodatage **UTC**, format `M/D/YYYY h:mm:ss AM/PM` |
| `Timestamp` | horodatage en heure locale du patient — **non utilisé** |
| `TrendArrow` | 1 = ↓, 2 = ↘, 3 = →, 4 = ↗, 5 = ↑ |

L'endpoint `/llu/connections/<patientId>/graph` existe et renvoie l'historique,
mais sa réponse est trop volumineuse pour être parsée sans risque dans la mémoire
d'une montre. L'application construit donc son historique localement, mesure après
mesure (`Store.appendHistory`).

## Pannes courantes

| Symptôme | Piste |
|---|---|
| « Email ou mot de passe refusé » | `status = 2` : vérifier le compte **suiveur**, pas le compte LibreView principal |
| « Conditions à accepter » | `status = 4` : ouvrir l'application LibreLinkUp et accepter les CGU |
| « Aucun capteur partagé » | l'invitation LibreLinkUp n'a pas été acceptée, ou le partage a été révoqué |
| 403 systématique après un login réussi | en-tête `version` trop ancien, ou `User-Agent` écrasé par Connect IQ |
| Valeur figée | le téléphone ne téléverse plus vers LibreView : vérifier d'abord dans l'application LibreLinkUp |

## Sources

- [nightscout-librelink-up (timoschlueter)](https://github.com/timoschlueter/nightscout-librelink-up) — implémentation de référence
- [HTTP dump de LibreLinkUp avec Libre 3 (gist khskekec)](https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2) — en-têtes et champs de réponse
- [LibreViewApi (InventivetalentDev)](https://github.com/InventivetalentDev/LibreViewApi/blob/master/LibreLinkUpApi.md) — description des endpoints
- [xDrip — discussion sur les 403 du web follower](https://github.com/NightscoutFoundation/xDrip/discussions/3808) — instabilités observées
- [Connect IQ — Communications.makeWebRequest](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html)
