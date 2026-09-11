//
// GlanceView - resume affiche dans la liste des widgets/glances.
//
// La glance est volontairement passive : elle relit la derniere mesure ecrite
// par le service background, sans requete reseau. Cela respecte la limite
// memoire tres basse de ce contexte et evite de vider la batterie.
//
using Toybox.Graphics;
using Toybox.WatchUi;

(:glance)
class FreestyleGlanceView extends WatchUi.GlanceView {

    function initialize() {
        WatchUi.GlanceView.initialize();
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        var reading = Store.getReading();
        var value = Store.readingValue(reading);
        var trend = Store.readingTrend(reading);
        var age = Theme.ageOf(reading);
        var mmol = Config.useMmol();
        var color = Theme.colorForReading(value, age);

        var valueText = Fmt.formatGlucose(value, mmol);
        var valueFont = (value == null) ? Graphics.FONT_SMALL : Graphics.FONT_NUMBER_MILD;
        var topY = (height * 0.34).toNumber();
        var bottomY = (height * 0.78).toNumber();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, topY, valueFont, valueText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var x = dc.getTextWidthInPixels(valueText, valueFont);
        var arrowSize = (height * 0.16).toNumber();
        if (arrowSize < 4) {
            arrowSize = 4;
        }
        if (value != null) {
            Arrow.draw(dc, x + (arrowSize * 2), topY, arrowSize, trend, color);
            x += arrowSize * 4;
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 6, topY, Graphics.FONT_XTINY, Fmt.unitLabel(mmol),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var subtitle;
        if (!Config.isConfigured()) {
            subtitle = "Reglages a completer";
        } else if (Store.readingTime(reading) == null) {
            var error = Store.getError();
            subtitle = (error == null) ? "En attente de mesure" : error;
        } else {
            subtitle = "il y a " + Fmt.formatAge(age);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, bottomY, Graphics.FONT_XTINY, subtitle,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
