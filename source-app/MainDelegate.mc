//
// MainDelegate - interactions sur l'ecran principal.
//
// Bouton SELECT (ou appui sur l'ecran tactile) : forcer une actualisation
// immediate sans attendre la periode configuree.
//
using Toybox.WatchUi;

class MainDelegate extends WatchUi.BehaviorDelegate {

    hidden var mView;

    function initialize(view) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onSelect() {
        mView.refresh(false);
        return true;
    }

    function onTap(clickEvent) {
        mView.refresh(false);
        return true;
    }
}
