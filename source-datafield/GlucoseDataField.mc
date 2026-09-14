//
// GlucoseDataField - le champ affiche pendant une activite.
//
// Il ne fait aucune requete : il relit la derniere mesure ecrite par le service
// en arriere-plan. La mise en page s'adapte a la taille reellement allouee au
// champ, qui depend de l'ecran de donnees choisi par l'utilisateur (un champ
// plein ecran, ou un tiers de ligne).
//
using Toybox.Activity;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class GlucoseDataField extends WatchUi.DataField {

    // compute() est appele environ une fois par seconde : relire le stockage a
    // cette cadence serait inutile et couteux. La mesure ne change que toutes
    // les 5 minutes.
    const READ_EVERY_TICKS = 5;

    hidden var mValue;
    hidden var mTrend;
    hidden var mAge;
    hidden var mTicks;

    function initialize() {
        DataField.initialize();
        mValue = null;
        mTrend = Fmt.TREND_UNKNOWN;
        mAge = null;
        mTicks = READ_EVERY_TICKS;
    }

    function compute(info) {
        mTicks += 1;
        if (mTicks >= READ_EVERY_TICKS) {
            mTicks = 0;
            var reading = Store.getReading();
            mValue = Store.readingValue(reading);
            mTrend = Store.readingTrend(reading);
            mAge = Theme.ageOf(reading);
        }
        return mValue;
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var background = getBackgroundColor();
        var foreground = (background == Graphics.COLOR_WHITE)
            ? Graphics.COLOR_BLACK
            : Graphics.COLOR_WHITE;

        dc.setColor(background, background);
        dc.clear();

        var mmol = Config.useMmol();
        var valueColor = Theme.adaptToBackground(
            Theme.colorForReading(mValue, mAge), background);

        // Le champ peut n'occuper qu'un tiers de ligne : on n'affiche le libelle
        // et l'anciennete que si la hauteur le permet reellement.
        var showLabel = (height >= 58);
        var showAge = (height >= 88);

        var centerY = height / 2;
        if (showLabel && !showAge) {
            centerY = (height * 0.60).toNumber();
        } else if (showLabel && showAge) {
            centerY = (height * 0.52).toNumber();
        }

        if (showLabel) {
            dc.setColor(foreground, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, (height * 0.14).toNumber(), Graphics.FONT_XTINY,
                "GLYCEMIE", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Un champ de donnees n'a pas de place pour un message : on affiche un
        // code court plutot que de laisser un "--" muet qui ne dit pas quoi faire.
        var text;
        var numeric = true;
        if (!Config.isConfigured()) {
            text = "REGL";
            numeric = false;
            valueColor = Theme.adaptToBackground(Graphics.COLOR_ORANGE, background);
        } else if (!Config.backgroundEnabled()) {
            text = "OFF";
            numeric = false;
            valueColor = Theme.adaptToBackground(Graphics.COLOR_ORANGE, background);
        } else {
            text = Fmt.formatGlucose(mValue, mmol);
        }
        var hasArrow = (numeric && mValue != null && mTrend != Fmt.TREND_UNKNOWN);
        var arrowSize = (height * 0.13).toNumber();
        if (arrowSize < 5) {
            arrowSize = 5;
        }
        var gap = 6;

        var available = width - (2 * 6);
        if (hasArrow) {
            available -= (gap + arrowSize * 2);
        }

        // Les polices numeriques ne contiennent que des chiffres : tout texte
        // non numerique doit passer par une police de texte.
        var font = (!numeric || mValue == null)
            ? pickTextFont(dc, text, available, height * 0.5)
            : pickFont(dc, text, available, (showAge || showLabel) ? (height * 0.52) : (height * 0.80));

        var textWidth = dc.getTextWidthInPixels(text, font);
        var total = textWidth + (hasArrow ? (gap + arrowSize * 2) : 0);
        var startX = ((width - total) / 2).toNumber();

        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, centerY, font, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (hasArrow) {
            Arrow.draw(dc, startX + textWidth + gap + arrowSize, centerY, arrowSize,
                mTrend, valueColor);
        }

        if (showAge && numeric) {
            var ageText = (mAge == null) ? "--" : Fmt.formatAge(mAge);
            dc.setColor(foreground, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, (height * 0.87).toNumber(), Graphics.FONT_XTINY,
                ageText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Plus grande police numerique tenant dans la largeur ET la hauteur allouees.
    hidden function pickFont(dc, text, maxWidth, maxHeight) {
        var candidates = [
            Graphics.FONT_NUMBER_THAI_HOT,
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL
        ];
        for (var i = 0; i < candidates.size(); i += 1) {
            var font = candidates[i];
            if (dc.getTextWidthInPixels(text, font) <= maxWidth
                && dc.getFontHeight(font) <= maxHeight) {
                return font;
            }
        }
        return Graphics.FONT_XTINY;
    }

    //! Meme principe, mais parmi les polices de texte (chiffres + lettres).
    hidden function pickTextFont(dc, text, maxWidth, maxHeight) {
        var candidates = [
            Graphics.FONT_LARGE,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
            Graphics.FONT_TINY
        ];
        for (var i = 0; i < candidates.size(); i += 1) {
            var font = candidates[i];
            if (dc.getTextWidthInPixels(text, font) <= maxWidth
                && dc.getFontHeight(font) <= maxHeight) {
                return font;
            }
        }
        return Graphics.FONT_XTINY;
    }
}
