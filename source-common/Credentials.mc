//
// Credentials - identifiants embarques a la compilation.
//
// POURQUOI CE FICHIER EXISTE
//
// Connect IQ memorise les reglages d'une application SUR LA MONTRE, indexes par
// identifiant d'application. Les valeurs par defaut d'un nouveau .prg ne les
// ecrasent pas : une fois qu'une valeur vide a ete enregistree au premier
// lancement, elle gagne contre toute recompilation. Et pour une application
// installee manuellement, l'ecran de reglages du telephone est inutilisable
// (il fait planter la montre).
//
// Consequence : sur une installation manuelle, le seul moyen fiable de fournir
// des identifiants est de les compiler dans l'application. Les constantes
// ci-dessous sont donc PRIORITAIRES sur les reglages memorises : ce que tu
// compiles est ce qui s'execute, sans surprise.
//
// Laisse-les vides si tu installes depuis la boutique Connect IQ : les reglages
// du telephone reprennent alors la main.
//
// Le script tools/installer-windows.ps1 renseigne ce fichier automatiquement,
// en echappant ce qui doit l'etre. Si tu l'edites a la main, double chaque
// antislash et chaque guillemet :  \  ->  \\      "  ->  \"
//
// Ne publie jamais ce fichier une fois renseigne.
//
(:glance, :background)
module Credentials {

    // -- DEBUT DES VALEURS RENSEIGNEES PAR LE SCRIPT --
    const LLU_EMAIL = "";
    const LLU_PASSWORD = "";
    // -- FIN DES VALEURS RENSEIGNEES PAR LE SCRIPT --

    // Cadence de rafraichissement quand l'application est OUVERTE, en secondes.
    // 0 = utiliser le reglage (60 s par defaut).
    //
    // Meme raison que pour les identifiants : sur une installation manuelle,
    // les reglages du telephone sont inutilisables, cette constante est donc
    // le seul moyen d'ajuster la valeur.
    //
    // Descendre sous 60 s n'apporte pratiquement rien : le capteur Libre ne
    // publie qu'une mesure toutes les 5 minutes. Cela ne fait que reduire le
    // delai entre la publication et son affichage, au prix de la batterie et
    // de requetes inutiles vers l'API.
    const REFRESH_SECONDS = 0;
}
