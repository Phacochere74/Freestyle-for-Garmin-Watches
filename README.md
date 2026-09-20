# Freestyle for Garmin Watches

Application Connect IQ qui affiche sur une montre Garmin la glycémie mesurée par
un capteur **FreeStyle Libre 3**, telle qu'elle est remontée par l'application
Android FreeStyle Libre 3.

*Écran principal : valeur courante, flèche de tendance, variation sur 15 min,
et courbe des dernières heures avec la plage cible.*

---

## ⚠️ Avertissement

Ce projet **n'est pas un dispositif médical** et n'est ni approuvé ni soutenu par
Abbott ou Garmin. Il affiche des données à titre informatif, avec un décalage de
plusieurs minutes. **Ne prends aucune décision thérapeutique (insuline, resucrage)
sur la seule base de cet affichage** : confirme toujours avec l'application
officielle ou une glycémie capillaire. Les alarmes du capteur et du téléphone
restent ta référence — celles de cette application ne les remplacent pas.

---

## Comment ça marche

Le capteur Libre 3 ne parle pas directement à une montre Garmin, et Connect IQ ne
peut pas lire la mémoire de l'application Libre 3 sur le téléphone. Le chemin
utilisé est donc celui du partage officiel d'Abbott :

```
Capteur Libre 3  ──BLE──▶  App FreeStyle Libre 3 (Android)
                                      │ téléversement automatique
                                      ▼
                              Cloud LibreView
                                      │ API LibreLinkUp (compte « suiveur »)
                                      ▼
                    Montre Garmin ──── HTTPS via Bluetooth/Wi-Fi ────┘
```

La montre interroge l'API LibreLinkUp elle-même : **aucune application compagnon
à installer sur le téléphone**, juste Garmin Connect (déjà présent).

Une source alternative est prévue : **Nightscout**, si tu utilises déjà xDrip+,
Juggluco ou un pont LibreLinkUp → Nightscout. C'est l'option la plus fiable des
deux (API publique, documentée et stable), mais elle suppose un serveur.

### Deux applications

Le dépôt produit **deux applications Connect IQ distinctes**, à installer
séparément :

| | Où ça s'affiche |
|---|---|
| **L'application** (`monkey.jungle`) | Écran complet depuis le menu, plus une *glance* accessible d'un balayage depuis le cadran |
| **Le champ de données** (`datafield.jungle`) | Dans un écran de données **pendant une activité** (course, vélo, marche) |

Elles partagent le même code (`source-common/`), **identifiants compris** :
`Credentials.mc` étant dans le code commun, le champ de données est configuré
d'office dès que l'application l'est. Chacune interroge LibreLinkUp de son côté,
avec son propre service en arrière-plan — Connect IQ cloisonne le stockage de
chaque application.

### Où voir ta glycémie, concrètement

| Surface | Disponible | Comment |
|---|---|---|
| Écran complet | ✅ | Menu des applications de la montre |
| **Glance** | ✅ | Un balayage depuis le cadran, sans ouvrir d'application |
| Champ de données | ✅ | Dans un écran de données, pendant une activité |
| **Sur ton cadran actuel** | ❌ | Voir ci-dessous |

**Pourquoi pas sur le cadran ?** Garmin propose un mécanisme de *complications*
Connect IQ — une application publie une valeur, un cadran l'affiche. Mais **les
cadrans d'origine Garmin n'acceptent pas les complications tierces** ; seuls
certains cadrans du store Connect IQ les prennent en charge. Deux contournements
possibles, à implémenter&nbsp;:

- installer un cadran tiers compatible complications, et ajouter la publication
  de complication à ce projet&nbsp;;
- ou écrire notre propre cadran affichant la glycémie — il remplacerait alors ton
  cadran actuel.

En pratique, **la glance couvre déjà le besoin** : un balayage depuis le cadran,
sans ouvrir d'application, et elle affiche la valeur mise à jour par le service
en arrière-plan.

### Fonctionnalités

- Valeur courante en gros caractères, colorée selon tes seuils
- Flèche de tendance (dessinée, donc lisible sur toutes les montres)
- Variation sur les 15 dernières minutes
- Courbe glissante de 1 à 6 h, avec la plage cible matérialisée
- Âge de la mesure (grisé et signalé au-delà de 15 min)
- *Glance* : résumé dans la liste des widgets, sans ouvrir l'application
- Rafraîchissement en arrière-plan toutes les 5 min (minimum imposé par Connect IQ)
- Vibration quand la valeur sort de la plage cible (application ouverte)
- Affichage en mg/dL ou mmol/L

---

## Prérequis côté Libre 3

L'API LibreLinkUp lit les données d'un **compte suiveur**, distinct de ton compte
LibreView principal. Concrètement :

1. Crée une seconde adresse e-mail (ou utilise un alias, par ex. `moi+llu@gmail.com`).
2. Dans l'application **FreeStyle Libre 3**, ouvre le menu, section
   *Applications connectées* / *Partage de connexion* → **LibreLinkUp**, et invite
   cette adresse comme soignant/suiveur.
   *(Le libellé exact varie selon la version de l'application — cherche la section
   qui parle de LibreLinkUp.)*
3. Installe **LibreLinkUp** (Android ou iOS), crée le compte avec cette adresse et
   accepte l'invitation. Vérifie que tu vois bien ta glycémie dans LibreLinkUp :
   si elle n'y apparaît pas, l'application montre ne verra rien non plus.
4. Renseigne cet e-mail et ce mot de passe dans les réglages de l'application montre.

> **Sur le mot de passe.** Connect IQ ne propose pas de champ masqué : le mot de
> passe est stocké en clair dans les réglages de l'application et transite par
> Garmin Connect. C'est une raison de plus d'utiliser un compte suiveur dédié,
> avec un mot de passe unique, et surtout pas celui de ton compte LibreView
> principal.

---

## Installation

### 1. Outils

- [SDK Connect IQ](https://developer.garmin.com/connect-iq/sdk/) (SDK Manager, puis
  installe au moins un SDK 6.x ou 7.x et le device de ta montre)
- [VS Code](https://code.visualstudio.com/) + extension **Monkey C** (Garmin)
- Une clé développeur : dans VS Code, `Ctrl/Cmd+Shift+P` →
  **Monkey C: Generate a Developer Key**. Sauvegarde-la : sans elle, plus de mise
  à jour possible de la même application.

  *(Équivalent en ligne de commande, si tu préfères :
  `openssl genrsa -out developer_key.pem 4096` puis
  `openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt`)*

**Jamais fait de développement Garmin ?** Suis
[`docs/demarrage-windows.md`](docs/demarrage-windows.md) : installation pas à pas
sous Windows, principes de la plateforme et diagnostic des erreurs courantes.

### 2. Vérifier que ta montre est dans la liste

`manifest.xml` contient une liste `<iq:products>`. **Si ton modèle n'y est pas, la
compilation ne le ciblera pas** ; à l'inverse, un identifiant inconnu du SDK fait
échouer la compilation.

Dans VS Code : `Ctrl/Cmd+Shift+P` → **Monkey C: Edit Products** → coche ta montre.
C'est la manière sûre de modifier cette liste.

Sont déjà couverts : Fenix 6/7, Epix (Gen 2) et **Epix Pro (Gen 2) en 42, 47 et
51 mm**, Forerunner 245/255/265/745/945/955/965, Venu/Venu 2/Venu Sq,
Vivoactive 4, Instinct 2, Descent Mk2, Approach S62, D2 Air.
Attention : les variantes « Pro » ont leur propre identifiant (`epix2pro47mm` et
non `epix2`) — un modèle Pro absent de la liste ne serait tout simplement pas
ciblé par la compilation.

### 3. Compiler et installer

Dans VS Code : `Ctrl/Cmd+Shift+P` → **Monkey C: Build for Device**, choisis ta
montre, puis copie le `.prg` produit dans `GARMIN/APPS/` de la montre branchée en
USB. Débranche : l'application apparaît dans la liste.

Attention&nbsp;: la commande **Build for Device** compile le projet sélectionné.
Pour le champ de données, ouvre `datafield.jungle` avant de lancer la commande
(ou utilise le script ci-dessous).

En ligne de commande :

```bash
tools/build.sh app       epix2pro47mm    # l'application
tools/build.sh datafield epix2pro47mm    # le champ de données
tools/build.sh both      epix2pro47mm    # les deux
```

Pour tester sans montre : **Monkey C: Run App** lance le simulateur (les requêtes
réseau y fonctionnent).

### 4. Régler l'application

Dans **Garmin Connect Mobile** → *Appareils* → ta montre → *Applications Connect IQ*
→ **Freestyle** → ⚙️ *Paramètres* :

| Réglage | Rôle |
|---|---|
| Source des données | LibreLinkUp ou Nightscout |
| LibreLinkUp : email / mot de passe | Compte suiveur |
| LibreLinkUp : région | `eu` par défaut ; l'application suit la redirection automatiquement |
| LibreLinkUp : version d'API | En-tête `version` (défaut `4.16.0`) — à relever si la connexion est refusée |
| Nightscout : URL / jeton | URL complète en `https://`, jeton de lecture facultatif |
| Affichage en mmol/L | Sinon mg/dL |
| Seuils hypo/hyper | **Toujours en mg/dL**, même si l'affichage est en mmol/L |
| Rafraîchissement | 30 à 600 s, application ouverte |
| Durée du graphique | 1 à 6 h |
| Mise à jour en arrière-plan | Actualise toutes les 5 min application fermée |
| Vibrer hors plage | Alerte à l'ouverture de l'application |

---

## Ce qui a été vérifié, et comment

Le SDK Connect IQ n'étant pas disponible dans l'environnement où ce code a été
écrit, deux garde-fous ont précédé la compilation — imparfaitement, mais ils ont
fait le gros du travail : sur ~2 000 lignes jamais compilées, le premier build
réel n'a remonté que trois erreurs, toutes de nomenclature d'API.

**Une revue de code critique** a été passée sur l'ensemble du projet. Sept
défauts réels ont été trouvés et corrigés, dont un bloquant :

| Défaut | Conséquence si non corrigé |
|---|---|
| Le champ de données ne pouvait jamais s'authentifier | Il aurait affiché `--` indéfiniment |
| Troncature de `Value` avant conversion mmol→mg/dL | 6,9 mmol/L lu comme 108 au lieu de 124 mg/dL, et 3,9 comme 54 → fausse alerte d'hypo sévère |
| Jeton non conservé en mémoire | Boucle de « session refusée » si l'écriture en stockage échoue |
| Alerte possible sur une mesure périmée | Vibration sur une valeur basse vieille de deux heures |
| `http://` accepté comme URL Nightscout | Service en arrière-plan tournant toutes les 5 min pour rien |
| Région LibreView réapprise à chaque enregistrement des réglages | Allers-retours de redirection inutiles |
| Champ de données ignorant le réglage d'arrière-plan | Champ figé silencieusement |

**Trois erreurs de compilation** ont été trouvées et corrigées au premier build
réel — exactement la catégorie que ni la revue ni les tests ne pouvaient
attraper, faute d'accès à la documentation Garmin depuis l'environnement de
développement :

| Erreur | Correction |
|---|---|
| `Undefined symbol ':Hasher'` | La classe de hachage est `Cryptography.Hash`, pas `Cryptography.Hasher` |
| Callback refusé par `makeWebRequest` (×3) | `Communications.ResponseCallback` impose une signature typée `(Number, Dictionary or String or Null) as Void` |
| Branche morte dans `NightscoutClient` | Nightscout renvoie un tableau JSON racine, absent du type imposé au callback |

Il subsiste **20 avertissements** « Cannot determine if container access is using
container type » : le vérificateur de types ne peut pas prouver le type des
valeurs lues dans un dictionnaire ou un tableau non annoté. Ils n'empêchent ni
la compilation ni l'exécution.

**Un banc de test de la logique**, qui transcrit en Python les fonctions pures
de `source-common/` et les confronte à des cas limites réels :

```bash
python3 tools/verif_logique.py
```

47 tests : horodatages LibreLinkUp (minuit et midi en AM/PM, format 24 h,
entrées malformées), `dateString` Nightscout, extraction de la mesure et repli
`Value`+`uom`, conversions d'unités, deltas, ancienneté, tendances, purge et
plafonnement de l'historique, couleurs aux bornes exactes des seuils.

> **Ce que ça ne valide pas** : ni la syntaxe Monkey C, ni les appels d'API
> Garmin. Seule une compilation avec `monkeyc` peut le faire. Le banc vérifie
> que les **règles de calcul** sont justes — pas que le code compile.

## ⚠️ Configuration d'une application installée manuellement

**N'ouvre pas les réglages de l'application depuis Garmin Connect Mobile :
ça fait planter la montre.**

Les réglages Connect IQ ne sont modifiables depuis le téléphone que pour les
applications installées **depuis la boutique** : leurs métadonnées sont
conservées côté serveur, pas sur la montre. Pour une application chargée
manuellement, l'entrée apparaît parfois dans Garmin Connect, mais l'ouvrir fait
planter l'appareil. C'est une limitation connue de Garmin, pas un défaut de
cette application.

**Le plus simple — un script fait tout** (Windows). Depuis le dossier du projet :

```powershell
powershell -ExecutionPolicy Bypass -File tools\installer-windows.ps1 -Email "moncompte.suiveur@exemple.com" -Password "monMotDePasse"
```

Il écrit les identifiants (en gérant l'échappement XML), détecte le SDK et la clé
développeur, compile, vérifie le `.prg` produit, détecte la montre branchée en USB
et y copie l'application. Chaque étape affiche `OK` ou `ECHEC` avec sa raison, et
il s'arrête à la première qui échoue.

Les fois suivantes, les identifiants étant enregistrés, la commande sans argument
suffit. `-DataField` compile le champ de données, `-NoCopy` compile sans installer.

**À la main**, si tu préfères : renseigne tes identifiants dans
`source-common/Credentials.mc` **avant de compiler**.

```monkeyc
const LLU_EMAIL = "ton.compte.suiveur@exemple.com";
const LLU_PASSWORD = "tonMotDePasse";
```

Si ton mot de passe contient un antislash ou un guillemet, double-les :
`\` → `\\`, `"` → `\"`.

> **Pourquoi pas `properties.xml` ?** Parce que ça ne marche pas sur une
> installation manuelle. Connect IQ mémorise les réglages **sur la montre**,
> indexés par identifiant d'application : les valeurs vides enregistrées au
> premier lancement gagnent contre les nouvelles valeurs par défaut d'un `.prg`
> recompilé. Les constantes de `Credentials.mc` sont donc prioritaires sur les
> réglages mémorisés — ce que tu compiles est ce qui s'exécute.
>
> Laisse-les vides pour une installation depuis la boutique : les réglages du
> téléphone reprennent alors la main.

Même chose pour les seuils, l'unité d'affichage et la durée du graphique :
modifie la valeur par défaut, recompile, recopie le `.prg`.

> **Conséquences.** Ton mot de passe se retrouve en clair dans le `.prg` installé
> sur ta montre et dans ton dossier de projet. Acceptable pour un usage personnel,
> à condition d'utiliser un compte **suiveur** LibreLinkUp dédié avec un mot de
> passe unique — jamais celui du compte LibreView principal. Et ne publie jamais
> le `Credentials.mc` renseigné.

## Limites connues, à lire avant de t'en servir

**Le code compile, mais n'a pas encore tourné sur une vraie montre.**
Compilation vérifiée le 18/09/2026 avec le **SDK Connect IQ 9.2.0** pour
`epix2pro47mm` : **les deux applications compilent**, zéro erreur, avertissements
de typage sans effet (voir ci-dessous).

> ⚠️ **Ne compile pas avec l'option `-r`** (build *release*) : elle fait planter le
> compilateur sur le projet `datafield` (« A critical error has occurred »), sans
> indiquer la cause. Elle est inutile pour une installation manuelle sur la montre.
> `tools/build.sh` ne l'emploie pas. Restent à valider sur l'appareil : la connexion réelle à
LibreLinkUp, le rendu à l'écran et la tenue en mémoire du service en
arrière-plan.

**L'API LibreLinkUp n'est pas publique.** Abbott ne la documente pas et la fait
évoluer sans préavis : en-tête `version` minimal relevé, en-tête `Account-Id`
ajouté, 403 sporadiques. L'application gère la redirection de région, le
rafraîchissement de jeton et l'en-tête `Account-Id` (SHA-256 de l'identifiant de
compte), mais elle peut cesser de fonctionner du jour au lendemain.

**Le `User-Agent` est un point d'incertitude.** Certaines implémentations doivent
en envoyer un pour que `/llu/connections` réponde. L'application le positionne,
mais Connect IQ se réserve le droit d'écraser cet en-tête. Si tu obtiens un 403
persistant alors que la connexion réussit, c'est la piste n°1 — et l'argument pour
basculer sur Nightscout.

**Latence.** Compte 1 à 5 minutes entre la mesure du capteur et son affichage sur
la montre : le téléphone téléverse vers LibreView, puis la montre interroge le
cloud. Ce n'est pas du temps réel.

**Alertes.** Elles ne se déclenchent que lorsque l'application est ouverte : un
service en arrière-plan Connect IQ n'a pas le droit de faire vibrer la montre. Les
alarmes du capteur et du téléphone restent indispensables.

**Arrière-plan et mémoire.** Le service en arrière-plan dispose d'une mémoire très
réduite (~32 Ko sur beaucoup de modèles). Pour y tenir, il ne se ré-authentifie pas
auprès de LibreLinkUp : il n'agit que si un jeton valide est déjà en cache, sinon
il attend la prochaine ouverture de l'application. Sur une montre à mémoire serrée
(Instinct 2 par exemple), désactive ce réglage si l'application plante.

**Historique.** LibreLinkUp ne renvoie que la dernière mesure ; la courbe se
construit donc progressivement, à mesure que l'application relève les valeurs.
Avec Nightscout, elle est amorcée d'un coup (36 points) à la première ouverture.

**Langue.** L'interface et les réglages sont en français, dans le dossier
`resources/` qui sert aussi de repli par défaut. Pour ajouter l'anglais : créer
`resources-eng/strings/strings.xml` avec les mêmes identifiants et déclarer la
langue dans `manifest.xml`.

---

## Structure du projet

```
manifest.xml                 L'application : identité, modèles ciblés, permissions
manifest-datafield.xml       Le champ de données (identifiant d'app distinct)
monkey.jungle                Projet Connect IQ de l'application
datafield.jungle             Projet Connect IQ du champ de données

source-common/               Code partagé par les deux applications
  Fetcher.mc                 Aiguillage entre les sources
  LibreLinkUpClient.mc       Client API LibreLinkUp (login, région, Account-Id)
  NightscoutClient.mc        Client API Nightscout
  BackgroundService.mc       Rafraîchissement toutes les 5 min
  Store.mc                   Persistance : mesure, historique, session
  Config.mc                  Lecture des réglages
  Fmt.mc                     Unités, dates, formatage
  Net.mc                     Codes d'erreur, SHA-256
  Theme.mc                   Couleurs selon les seuils
  Arrow.mc                   Flèche de tendance dessinée

source-app/                  Spécifique à l'application
  FreestyleApp.mc            Point d'entrée : vue, glance, service background
  MainView.mc                Écran principal (valeur, tendance, courbe)
  MainDelegate.mc            Boutons / tactile
  FreestyleGlanceView.mc     Résumé dans la liste des raccourcis

source-datafield/            Spécifique au champ de données
  FreestyleDataFieldApp.mc   Point d'entrée + service background
  GlucoseDataField.mc        Rendu adaptatif selon la taille allouée

resources/                   Chaînes, réglages, propriétés, icônes (partagés)
resources-app/               Ressources de l'application seule
  complications/             Déclaration de la complication publiée
tools/build.sh               Compilation en ligne de commande
tools/make_icon.py           Génération de l'icône de lancement
docs/demarrage-windows.md    Installation de l'environnement, pas à pas
docs/api-librelinkup.md      Notes sur l'API et ses sources
```

---

## Licence

MIT — voir `LICENSE`.
