# Démarrer avec Connect IQ sous Windows

Guide pour quelqu'un qui n'a jamais programmé pour une montre Garmin.
Compte 45 minutes pour l'installation, une fois.

---

## 1. Les idées de base

### Ce que tu connais ne s'applique pas ici

| Ton réflexe | La réalité Connect IQ |
|---|---|
| Anaconda, `pip`, environnement virtuel | Rien de tout ça. Aucun Python n'intervient. |
| Interpréteur qui exécute ton `.py` | Un **compilateur** produit un fichier binaire signé |
| `pip install` une dépendance | Pas de gestionnaire de paquets. Tout est dans le SDK. |

Une montre Garmin n'a ni Python, ni navigateur, ni système de fichiers ouvert.
Elle exécute une machine virtuelle minuscule, avec quelques centaines de kilo-octets
de mémoire. Tout l'écosystème est conçu autour de cette contrainte.

### Le vocabulaire

- **Connect IQ** — la plateforme d'applications de Garmin. L'équivalent du Play Store,
  plus le SDK qui va avec.
- **Monkey C** — le langage. Syntaxe proche de Java/C, typage optionnel, ramasse-miettes.
  Si tu lis du Python, tu lis du Monkey C sans difficulté : accolades au lieu
  d'indentation, `var` pour déclarer, `function` pour les fonctions.
- **SDK** — l'ensemble compilateur + simulateur + définitions d'appareils.
- **`.prg`** — ton application compilée pour **un** modèle de montre précis. C'est le
  fichier que tu copies sur la montre.
- **Sideload** — installer un `.prg` en branchant la montre en USB, sans passer par
  le store. C'est ce qu'on fait ici.
- **Clé développeur** — une clé RSA 4096 bits qui signe ton application. Garde-la :
  sans elle tu ne peux plus publier de mise à jour de la même app.

### Les quatre formes d'application

C'est le premier choix structurant quand on crée un projet Connect IQ :

| Type | Ce que c'est |
|---|---|
| **Watch app** | Une application qu'on lance depuis le menu. **C'est notre cas.** |
| **Watch face** | Un cadran : remplace l'affichage de l'heure |
| **Data field** | Un champ affiché pendant une activité (course, vélo) |
| **Widget** | Ancien format, remplacé par les *glances* |

Une *glance* est le petit résumé horizontal qu'on voit en faisant défiler les
raccourcis depuis le cadran. Notre application en a une, en plus de son écran complet.

### La chaîne d'outils

```
Java (JDK)          ← prérequis, le SDK est écrit en Java
    ↓
SDK Connect IQ      ← compilateur + simulateur + fiches des montres
    ↓
VS Code + extension Monkey C   ← ton éditeur, pilote le compilateur
    ↓
Simulateur          ← tu testes sur PC, sans toucher la montre
    ↓
fichier .prg → copié en USB dans GARMIN\APPS de la montre
```

### La contrainte qui explique tout le reste

Ton application ne tourne pas dans un seul contexte, mais dans **trois**, chacun
avec sa propre limite de mémoire :

- l'**application complète** (quand tu l'ouvres) : la plus généreuse ;
- la **glance** : quelques dizaines de Ko ;
- le **service en arrière-plan** : le plus serré, et il doit se terminer vite.

C'est pour ça que le code du projet est parsemé d'annotations `(:glance)` et
`(:background)` : elles disent au compilateur quel bout de code embarquer dans
quel contexte. Sans elles, tout serait copié partout et la glance dépasserait
sa limite.

---

## 2. Installation

### Étape 1 — Java

Le SDK Garmin est écrit en Java, il lui faut donc un JDK. Prends **Temurin 17**
(version à support long terme).

```powershell
winget install EclipseAdoptium.Temurin.17.JDK
```

Sinon, l'installeur `.msi` est sur [adoptium.net](https://adoptium.net/).
Vérifie ensuite dans un **nouveau** terminal :

```powershell
java -version
```

> Garmin documente Java 1.8 comme minimum, mais les SDK récents se comportent
> mieux avec un JDK moderne. Si le SDK Manager refuse de démarrer, c'est presque
> toujours Java qui manque ou n'est pas dans le `PATH`.

### Étape 2 — VS Code

```powershell
winget install Microsoft.VisualStudioCode
```

Ou depuis [code.visualstudio.com](https://code.visualstudio.com/).

### Étape 3 — L'extension Monkey C

Dans VS Code : icône **Extensions** dans la barre latérale → cherche `Monkey C` →
installe celle **publiée par Garmin** (il existe des extensions tierces qui ne
fournissent que la coloration syntaxique). Redémarre VS Code.

### Étape 4 — Le SDK Manager

Télécharge le **Connect IQ SDK Manager** sur
[developer.garmin.com/connect-iq/sdk](https://developer.garmin.com/connect-iq/sdk/).
Une connexion avec un compte Garmin gratuit peut être demandée.

Lance-le, puis :

1. Onglet **SDK** : installe la dernière version, et réponds **Yes** à
   « utiliser ce SDK comme SDK actif ».
2. Onglet **Devices** : coche ta montre. Pour une **Epix Pro (Gen 2)**, choisis la
   bonne taille de boîtier — `42mm`, `47mm` ou `51mm`. Ce sont trois appareils
   distincts pour le compilateur.

Sans le device installé, la compilation échouera avec un message du genre
« device not found ».

### Étape 5 — Vérifier

Dans VS Code : `Ctrl+Shift+P` → tape `Verify Installation` → **Monkey C: Verify Installation**.

Fais cette étape maintenant. Elle te dira précisément ce qui manque, plutôt que
de le découvrir au milieu d'une erreur de compilation.

### Étape 6 — La clé développeur

`Ctrl+Shift+P` → **Monkey C: Generate a Developer Key**.

L'extension crée la clé pour toi, tu n'as pas besoin d'`openssl`. Note où elle est
enregistrée et **sauvegarde-la ailleurs** (elle n'est pas dans le dépôt Git, et
c'est voulu : une clé privée ne se partage pas).

### Étape 7 — Git et le projet

```powershell
winget install Git.Git
```

Puis, dans le dossier de ton choix :

```powershell
git clone https://github.com/Phacochere74/Freestyle-for-Garmin-Watches.git
cd Freestyle-for-Garmin-Watches
git checkout claude/garmin-freestyle-libre-app-vygum7
```

Dans VS Code : **Fichier → Ouvrir le dossier** → sélectionne
`Freestyle-for-Garmin-Watches`. Ouvre bien **le dossier**, pas un fichier isolé :
l'extension a besoin de voir `manifest.xml` et `monkey.jungle` à la racine pour
reconnaître un projet Connect IQ.

---

## 3. Compiler

Le dépôt contient **deux applications** : l'app (écran complet + glance) et le
champ de données. Compile l'app **en premier** — 80 % du code est partagé, donc
les corrections d'erreurs profiteront ensuite au champ de données gratuitement.

`Ctrl+Shift+P` → **Monkey C: Build for Device** → choisis `epix2pro47mm`
(ou ta taille de boîtier).

> Cette commande compile le projet actif. Pour le champ de données, ouvre
> `datafield.jungle` avant de la lancer. En ligne de commande :
> `tools/build.sh both epix2pro47mm`.

Deux issues possibles :

- **Ça compile** → un fichier `.prg` apparaît dans `bin/`.
- **Ça échoue** → les erreurs s'affichent dans le panneau **Problems**
  (`Ctrl+Shift+M`). Chacune donne un fichier, une ligne et un message.
  Copie-les-moi telles quelles, je corrige.

C'est l'étape normale. Un premier build qui échoue sur une poignée d'erreurs de
syntaxe n'a rien d'anormal, surtout sur du code qui n'a jamais été compilé.

---

## 4. Tester dans le simulateur

`Ctrl+Shift+P` → **Monkey C: Run App**. Une fenêtre s'ouvre avec une montre à
l'écran. Les requêtes réseau y fonctionnent vraiment : tu peux valider la connexion
LibreLinkUp sans toucher à ta montre.

### Saisir tes identifiants dans le simulateur

C'est l'étape qui bloque souvent, parce qu'elle n'est pas là où on l'attend.
Dans la fenêtre du simulateur :

**File → Edit Persistent Storage → Edit Application.Properties data**
(raccourci `Ctrl+P`)

Un tableau s'ouvre avec toutes les propriétés du fichier
`resources/properties/properties.xml`. Remplis `lluEmail` et `lluPassword` avec
ton compte suiveur LibreLinkUp, valide, et relance l'application.

Pour repartir de zéro : **File → Reset All App Data**.

### Lire les traces

Les `System.println()` du code s'affichent dans l'onglet **Output** de VS Code.
Le débogueur (points d'arrêt, inspection des variables) fonctionne aussi, via
`F5` au lieu de *Run App*.

---

## 5. Installer sur la montre

1. Branche la montre en USB. Windows la monte comme un lecteur.
2. Copie les `.prg` produits dans le dossier **`GARMIN\APPS`** de la montre.
3. Éjecte proprement et débranche.
4. L'application apparaît dans la liste des applications ; le champ de données
   apparaît quand tu personnalises un écran de données d'une activité
   (**Paramètres de l'activité → Écrans de données → ajouter un champ →
   Connect IQ**).

Les réglages se font depuis le téléphone : **Garmin Connect Mobile →
Appareils → ta montre → Applications Connect IQ → ⚙️ Paramètres**.

> **Les deux applications ont des réglages séparés.** Connect IQ cloisonne
> totalement les applications : tes identifiants LibreLinkUp sont à saisir une
> fois pour l'app, une fois pour le champ de données. C'est une contrainte de la
> plateforme.

> Une application chargée en sideload n'est pas signée par le store : c'est normal,
> elle fonctionne exactement pareil. Elle n'est simplement visible que par toi.

---

## 6. Quand ça casse

| Symptôme | Cause la plus probable |
|---|---|
| Le SDK Manager ne démarre pas | Java absent ou hors du `PATH` |
| « Device not found » à la compilation | Le device n'est pas coché dans le SDK Manager |
| Aucune commande `Monkey C:` dans la palette | Mauvaise extension, ou dossier ouvert sans `manifest.xml` à la racine |
| « No developer key » | Étape 6 non faite, ou chemin de la clé non renseigné dans les réglages de l'extension |
| L'app se ferme aussitôt sur la montre | Dépassement de mémoire — à diagnostiquer d'abord au simulateur |
| Compilation OK mais l'app n'apparaît pas | `.prg` copié au mauvais endroit : c'est `GARMIN\APPS`, pas `GARMIN` |
| « A critical error has occurred » | Option `-r` (build *release*) : elle fait planter le compilateur sur le projet `datafield` avec le SDK 9.2.0. Compile sans `-r` |
| « Glance applications are not supported for app type 'datafield' » | Avertissement normal : le code partagé porte l'annotation `(:glance)` utile à l'application, que le champ de données ignore. Sans effet |
| L'application affiche « À configurer » alors que le `.prg` contient les identifiants | La montre a mémorisé les réglages vides du premier lancement. Utilise `source-common/Credentials.mc`, prioritaire sur les réglages mémorisés |
| La montre n'est pas détectée par le script, alors qu'elle est branchée | Elle se monte en **MTP** (sans lettre de lecteur), comme un téléphone. Copie le `.prg` à la main dans `Ce PC > [montre] > Internal Storage > GARMIN > Apps` |
| **La montre se fige en ouvrant les réglages depuis Garmin Connect** | Limitation Garmin : impossible pour une application installée manuellement. Renseigne les identifiants dans `source-common/Credentials.mc` **avant** de compiler |

---

## 7. Pour aller plus loin

- [Connect IQ — Getting Started](https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/)
- [Extension VS Code Monkey C — guide de référence](https://developer.garmin.com/connect-iq/reference-guides/visual-studio-code-extension/)
- [Documentation de l'API (Toybox)](https://developer.garmin.com/connect-iq/api-docs/)
- [Forum développeurs Connect IQ](https://forums.garmin.com/developer/connect-iq/) — la
  meilleure source quand un comportement est inexplicable ; les ingénieurs Garmin y répondent.
