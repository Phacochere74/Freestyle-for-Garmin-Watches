<#
    Installation complete sous Windows, en une commande.

    Enchaine : identifiants -> compilation -> verification -> copie sur la
    montre. Chaque etape affiche OK ou ECHEC avec sa raison, et le script
    s'arrete net a la premiere qui echoue.

    Usage, depuis le dossier du projet :

        powershell -ExecutionPolicy Bypass -File tools\installer-windows.ps1 -Email "moncompte@exemple.com" -Password "monMotDePasse"

    Les fois suivantes, les identifiants etant deja enregistres :

        powershell -ExecutionPolicy Bypass -File tools\installer-windows.ps1

    Options :
        -Device     modele Garmin vise (defaut : epix2pro47mm)
        -Key        chemin de la cle developpeur, si la detection echoue
        -DataField  compile le champ de donnees au lieu de l'application
        -NoCopy     compile sans copier sur la montre
#>

param(
    [string] $Email = "",
    [string] $Password = "",
    [string] $Device = "epix2pro47mm",
    [string] $Key = "",
    [switch] $DataField,
    [switch] $NoCopy
)

function Etape($texte)   { Write-Host ""; Write-Host "== $texte" -ForegroundColor Cyan }
function Bon($texte)     { Write-Host "   OK      $texte" -ForegroundColor Green }
function Info($texte)    { Write-Host "           $texte" -ForegroundColor DarkGray }
function Abandon($texte) {
    Write-Host "   ECHEC   $texte" -ForegroundColor Red
    Write-Host ""
    Write-Host "Copie tout l'affichage ci-dessus dans la conversation." -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------- 1. Le projet
Etape "Localisation du projet"

$racine = Split-Path -Parent $PSScriptRoot
$creds  = Join-Path $racine "source-common\Credentials.mc"

if ($DataField) {
    $nomJungle = "datafield.jungle"
    $nomPrg    = "FreestyleDataField.prg"
} else {
    $nomJungle = "monkey.jungle"
    $nomPrg    = "Freestyle.prg"
}
$jungle = Join-Path $racine $nomJungle
$binDir = Join-Path $racine "bin"
$sortie = Join-Path $binDir $nomPrg

if (-not (Test-Path $creds))  { Abandon "Credentials.mc introuvable. Ce script doit rester dans le dossier tools du projet." }
if (-not (Test-Path $jungle)) { Abandon "$nomJungle introuvable dans $racine" }
Bon $racine

# ----------------------------------------------------------------- 2. Java
Etape "Verification de Java"

$java = Get-Command java -ErrorAction SilentlyContinue
if ($null -eq $java) { Abandon "java introuvable. Ouvre un NOUVEAU terminal, ou reinstalle le JDK Temurin 17." }
Bon $java.Source

# ------------------------------------------------------------------ 3. SDK
Etape "Recherche du SDK Connect IQ"

$dossierSdks = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
if (-not (Test-Path $dossierSdks)) { Abandon "Aucun SDK dans $dossierSdks. Lance le SDK Manager." }

$sdks = @(Get-ChildItem -Path $dossierSdks -Directory | Sort-Object Name -Descending)
if ($sdks.Count -eq 0) { Abandon "Le dossier $dossierSdks est vide." }

$compilateur = Join-Path $sdks[0].FullName "bin\monkeybrains.jar"
if (-not (Test-Path $compilateur)) { Abandon "monkeybrains.jar absent de $($sdks[0].FullName)" }
Bon $sdks[0].Name

# ------------------------------------------------------------------ 4. Cle
Etape "Recherche de la cle developpeur"

$cle = ""
if ($Key -ne "" -and (Test-Path $Key)) {
    $cle = (Resolve-Path $Key).Path
} else {
    $parent      = Split-Path -Parent $racine
    $grandParent = Split-Path -Parent $parent
    $aFouiller   = @($racine, $parent, $grandParent)
    foreach ($dossier in $aFouiller) {
        if ($cle -ne "") { continue }
        if ($null -eq $dossier -or $dossier -eq "") { continue }
        if (-not (Test-Path $dossier)) { continue }
        $trouves = @(Get-ChildItem -Path $dossier -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -eq "developer_key" -or $_.Extension -eq ".der" })
        if ($trouves.Count -gt 0) { $cle = $trouves[0].FullName }
    }
}
if ($cle -eq "") { Abandon "Cle developpeur introuvable. Relance en ajoutant : -Key `"C:\chemin\vers\developer_key`"" }
Bon $cle

# ---------------------------------------------------------- 5. Identifiants
Etape "Identifiants LibreLinkUp"
Info "ecrits dans le code : la montre conserve sinon les reglages du 1er lancement"

if ($Email -ne "" -or $Password -ne "") {
    # Echappement Monkey C : l'antislash d'abord, sinon on echapperait
    # les antislash que l'on vient d'introduire.
    # En PowerShell, le motif est une regex mais le remplacement est litteral :
    #   motif '\\' = un antislash, remplacement '\\' = deux antislashes.
    $emailEch = $Email    -replace '\\', '\\' -replace '"', '\"'
    $mdpEch   = $Password -replace '\\', '\\' -replace '"', '\"'

    $sortieLignes = @()
    foreach ($ligne in (Get-Content -Path $creds)) {
        if ($Email -ne "" -and $ligne -match '^\s*const LLU_EMAIL\s*=') {
            $sortieLignes += ('    const LLU_EMAIL = "' + $emailEch + '";')
        } elseif ($Password -ne "" -and $ligne -match '^\s*const LLU_PASSWORD\s*=') {
            $sortieLignes += ('    const LLU_PASSWORD = "' + $mdpEch + '";')
        } else {
            $sortieLignes += $ligne
        }
    }
    # UTF-8 sans BOM : le compilateur Monkey C n'apprecie pas la marque d'ordre.
    $encodage = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($creds, $sortieLignes, $encodage)
    Info "Credentials.mc mis a jour, echappement pris en charge"
}

$emailLu = ""
$mdpLu    = ""
foreach ($ligne in (Get-Content -Path $creds)) {
    if ($ligne -match '^\s*const LLU_EMAIL\s*=\s*"(.*)"\s*;')    { $emailLu = $matches[1] }
    if ($ligne -match '^\s*const LLU_PASSWORD\s*=\s*"(.*)"\s*;') { $mdpLu   = $matches[1] }
}
if ($Email -ne "")    { $emailLu = $Email }
if ($Password -ne "") { $mdpLu   = $Password }

if ($emailLu.Trim() -eq "" -or $mdpLu.Trim() -eq "") {
    Abandon "Identifiants vides. Relance en ajoutant : -Email `"...`" -Password `"...`""
}
Bon "$emailLu, mot de passe de $($mdpLu.Length) caracteres"

# ----------------------------------------------------------- 6. Compilation
Etape "Compilation pour $Device"
Info "sans l'option -r, qui fait planter le compilateur sur ce projet"

if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Force -Path $binDir | Out-Null }
if (Test-Path $sortie) { Remove-Item -Path $sortie -Force }

$brut = & java -jar $compilateur -f $jungle -o $sortie -y $cle -d $Device -w 2>&1
$journal = @($brut | ForEach-Object { [string] $_ })

$erreurs = @($journal | Where-Object { $_ -like "ERROR:*" })
$alertes = @($journal | Where-Object { $_ -like "WARNING:*" })

if ($erreurs.Count -gt 0) {
    Write-Host ""
    foreach ($e in $erreurs) { Write-Host "   $e" -ForegroundColor Red }
    Abandon "$($erreurs.Count) erreur(s) de compilation."
}
if (-not (Test-Path $sortie)) {
    Write-Host ""
    foreach ($l in $journal) { Write-Host "   $l" -ForegroundColor DarkGray }
    Abandon "Aucun fichier produit."
}

$prg = Get-Item -Path $sortie
Bon "$nomPrg, $([math]::Round($prg.Length / 1KB)) Ko, $($alertes.Count) avertissement(s) sans effet"

# ------------------------------------------- 7. Verification du .prg produit
Etape "Verification du fichier compile"

$octets = [System.IO.File]::ReadAllBytes($sortie)
$texte  = [System.Text.Encoding]::ASCII.GetString($octets)
if ($texte.Contains($emailLu)) {
    Bon "l'adresse est presente dans le .prg"
} else {
    Info "adresse non reperee en clair ; le compilateur peut encoder les chaines"
    Info "ce n'est pas bloquant, on continue"
}

# -------------------------------------------------------------- 8. La montre
if ($NoCopy) {
    Etape "Copie ignoree (-NoCopy)"
    Info "fichier pret : $sortie"
    exit 0
}

Etape "Recherche de la montre"

$dossierApps = ""
$lecteurs = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)
foreach ($lecteur in $lecteurs) {
    if ($dossierApps -ne "") { continue }
    if ($null -eq $lecteur.Root -or $lecteur.Root -eq "") { continue }
    $candidat = Join-Path $lecteur.Root "GARMIN\APPS"
    if (Test-Path -Path $candidat -ErrorAction SilentlyContinue) { $dossierApps = $candidat }
}

if ($dossierApps -eq "") {
    # Les montres recentes (Epix Pro, Fenix 8...) se montent en MTP, comme un
    # telephone : elles apparaissent sous "Ce PC" mais SANS lettre de lecteur.
    # Windows ne permet pas de copier vers un peripherique MTP en ligne de
    # commande de maniere fiable ; la copie se fait donc a la main.
    Write-Host "   A FAIRE  copie manuelle" -ForegroundColor Yellow
    Info "Aucun lecteur Garmin avec une lettre (D:, E:...) n'a ete trouve."
    Info "C'est normal sur les montres recentes : elles se montent en MTP."
    Info ""
    Info "L'explorateur Windows va s'ouvrir sur le fichier compile."
    Info "Glisse-le dans :  Ce PC > [ta montre] > Internal Storage > GARMIN > Apps"
    Info "Puis ejecte la montre, debranche, laisse-la redemarrer."
    Info ""
    Info "Fichier : $sortie"

    $argument = '/select,"' + $sortie + '"'
    Start-Process -FilePath "explorer.exe" -ArgumentList $argument

    Write-Host ""
    Write-Host "Compilation terminee. Il ne reste que la copie." -ForegroundColor Green
    exit 0
}
Bon $dossierApps

Etape "Copie sur la montre"
Copy-Item -Path $sortie -Destination $dossierApps -Force
Bon "$nomPrg copie"

Write-Host ""
Write-Host "Termine." -ForegroundColor Green
Write-Host "Ejecte la montre proprement, debranche, laisse-la redemarrer." -ForegroundColor Yellow
Write-Host "Le .prg disparaitra du dossier APPS : c'est le signe que l'installation a eu lieu." -ForegroundColor Yellow
