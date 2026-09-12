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

En ligne de commande :

```bash
tools/build.sh fenix7 developer_key.der
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

## Limites connues, à lire avant de t'en servir

**Le code n'a pas été compilé.** Il a été écrit et relu hors d'un environnement
disposant du SDK Connect IQ (téléchargement bloqué). Attends-toi à devoir corriger
quelques erreurs de compilation au premier build — la structure et la logique sont
en place, mais rien ne remplace un `monkeyc` qui passe. C'est la première chose à
faire avant de juger le reste.

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
manifest.xml                 Identité de l'app, modèles ciblés, permissions
monkey.jungle                Fichier de projet Connect IQ
source/
  FreestyleApp.mc            Point d'entrée : vue, glance, service background
  MainView.mc                Écran principal (valeur, tendance, courbe)
  MainDelegate.mc            Boutons / tactile
  FreestyleGlanceView.mc     Résumé dans la liste des widgets
  BackgroundService.mc       Rafraîchissement toutes les 5 min
  Fetcher.mc                 Aiguillage entre les sources
  LibreLinkUpClient.mc       Client API LibreLinkUp (login, région, Account-Id)
  NightscoutClient.mc        Client API Nightscout
  Store.mc                   Persistance : mesure, historique, session
  Config.mc                  Lecture des réglages
  Fmt.mc                     Unités, dates, formatage
  Net.mc                     Codes d'erreur, SHA-256
  Theme.mc                   Couleurs selon les seuils
  Arrow.mc                   Flèche de tendance dessinée
resources/                   Chaînes, réglages, propriétés, icône
tools/build.sh               Compilation en ligne de commande
tools/make_icon.py           Génération de l'icône de lancement
docs/api-librelinkup.md      Notes sur l'API et ses sources
```

---

## Licence

MIT — voir `LICENSE`.
