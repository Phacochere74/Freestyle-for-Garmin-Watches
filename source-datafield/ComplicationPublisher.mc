//
// ComplicationPublisher - version neutre pour le champ de donnees.
//
// Le code partage (Fetcher) appelle publish() a chaque mesure recue. Seule
// l'application publie reellement une complication : elle seule la declare
// dans ses ressources et porte la permission ComplicationPublisher.
//
// Ce module porte donc le meme nom et la meme signature, sans rien faire. Les
// deux versions ne coexistent jamais dans une meme compilation : chacune vit
// dans le dossier de source de son application.
//
// Sans ce fichier, la compilation du champ de donnees echouerait sur un
// symbole introuvable ; et embarquer la vraie version exigerait une permission
// inutile, pour une complication que ce champ ne declare pas.
//
(:glance, :background)
module ComplicationPublisher {

    //! Sans effet : le champ de donnees ne publie aucune complication.
    function publish(reading) {
    }
}
