//
// MainView - ecran principal : valeur courante, tendance, variation, courbe.
//
// Tout est dessine a la main (pas de layout XML) pour s'adapter aux ecrans
// ronds comme rectangulaires, de 208 a 454 px.
//
using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;
using Toybox.WatchUi;

class MainView extends WatchUi.View {

    // Periode du timer d'interface : rafraichit l'age affiche et declenche
    // une requete quand la periode configuree est ecoulee.
    const UI_TICK_MS = 30000;
    // Pas plus d'une alerte vibrante toutes les 15 minutes.
    const ALERT_COOLDOWN = 900;

    hidden var mFetcher;
    hidden var mTimer;
    hidden var mFetching;
    hidden var mLastAlertTime;
    hidden var mIsRound;

    function initialize() {
        View.initialize();
        mFetcher = new Fetcher();
        mTimer = null;
        mFetching = false;
        mLastAlertTime = 0;
        mIsRound = false;
    }

    function onLayout(dc) {
        var settings = System.getDeviceSettings();
        mIsRound = (settings != null && settings.screenShape == System.SCREEN_SHAPE_ROUND);
    }

    function onShow() {
        startTimer();
        refresh(true);
    }

    function onHide() {
        stopTimer();
    }

    // ---- Cycle de rafraichissement ----------------------------------------

    hidden function startTimer() {
        if (mTimer == null) {
            mTimer = new Timer.Timer();
        }
        mTimer.start(method(:onTick), UI_TICK_MS, true);
    }

    hidden function stopTimer() {
        if (mTimer != null) {
            mTimer.stop();
        }
    }

    function onTick() {
        var lastFetch = Store.getLastFetch();
        var now = Time.now().value();
        if (lastFetch == null || (now - lastFetch) >= Config.refreshSeconds()) {
            refresh(false);
        }
        WatchUi.requestUpdate();
    }

    //! Declenche une requete.
    //! @param initial true a l'ouverture : on tente d'amorcer la courbe.
    function refresh(initial) {
        if (mFetcher.isBusy()) {
            return;
        }
        // A l'ouverture, si la courbe est vide, on demande plus de points a
        // Nightscout (LibreLinkUp ne renvoie de toute facon que la derniere).
        var historyCount = 1;
        if (initial && Store.getHistory().size() < 3) {
            historyCount = 36;
        }
        // mFetching est positionne avant l'appel : en cas d'erreur immediate,
        // start() rappelle onFetch() de maniere synchrone et le remet a false.
        mFetching = true;
        mFetcher.start(method(:onFetch), historyCount);
        WatchUi.requestUpdate();
    }

    function onFetch(errorMessage, reading) {
        mFetching = false;
        if (errorMessage == null && reading != null) {
            maybeAlert(reading);
        }
        WatchUi.requestUpdate();
    }

    // ---- Alertes -----------------------------------------------------------

    hidden function maybeAlert(reading) {
        if (!Config.vibrateOnAlert()) {
            return;
        }
        var value = Store.readingValue(reading);
        if (value == null) {
            return;
        }
        // Ne jamais alerter sur une mesure que l'ecran grise deja comme perimee :
        // apres une reconnexion du telephone, une valeur basse vieille de deux
        // heures declencherait une vibration injustifiee.
        var age = Theme.ageOf(reading);
        if (age == null || age > Theme.STALE_SECONDS) {
            return;
        }
        var now = Time.now().value();
        if ((now - mLastAlertTime) < ALERT_COOLDOWN) {
            return;
        }
        var urgent = (value <= Config.urgentLow() || value >= Config.urgentHigh());
        var outOfRange = (value < Config.low() || value > Config.high());
        if (!outOfRange) {
            return;
        }
        mLastAlertTime = now;
        alert(urgent);
    }

    hidden function alert(urgent) {
        if (!(Toybox has :Attention)) {
            return;
        }
        var settings = System.getDeviceSettings();
        if (Attention has :vibrate && settings != null && settings.vibrateOn) {
            var profile;
            if (urgent) {
                profile = [
                    new Attention.VibeProfile(100, 400),
                    new Attention.VibeProfile(0, 200),
                    new Attention.VibeProfile(100, 400)
                ];
            } else {
                profile = [ new Attention.VibeProfile(75, 300) ];
            }
            Attention.vibrate(profile);
        }
        if (Attention has :playTone && settings != null && settings.tonesOn) {
            Attention.playTone(urgent ? Attention.TONE_ALERT_HI : Attention.TONE_ALERT_LO);
        }
    }

    // ---- Dessin ------------------------------------------------------------

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var reading = Store.getReading();
        var value = Store.readingValue(reading);
        var age = Theme.ageOf(reading);
        var mmol = Config.useMmol();
        var color = Theme.colorForReading(value, age);

        drawStatus(dc, width, height);
        drawValue(dc, width, height, value, Store.readingTrend(reading), color, mmol);
        drawDelta(dc, width, height, reading, mmol);
        drawChart(dc, width, height);
        drawFooter(dc, width, height, reading, age);
    }

    //! Ligne du haut : source, etat de la requete ou message d'erreur.
    hidden function drawStatus(dc, width, height) {
        var text;
        var color = Graphics.COLOR_LT_GRAY;

        if (!Config.isConfigured()) {
            text = "A configurer";
            color = Graphics.COLOR_ORANGE;
        } else if (mFetching) {
            text = "Actualisation...";
        } else {
            var error = Store.getError();
            if (error != null) {
                text = error;
                color = Graphics.COLOR_ORANGE;
            } else if (Config.backgroundEnabled() && !Wake.isRegistered()) {
                // Sans evenement temporel enregistre, la glance, le champ de
                // donnees et la complication ne sont plus alimentes : seule
                // l'ouverture de cet ecran declenche encore une requete. On le
                // dit au lieu de laisser croire a un simple retard.
                text = "Reveil non programme";
                color = Graphics.COLOR_ORANGE;
            } else {
                // On affiche l'age du dernier RELEVE reussi, distinct de l'age
                // de la mesure affiche en bas. Les deux ensemble disent si
                // l'application interroge bien l'API sans y trouver de
                // nouvelle mesure, ou si c'est elle qui n'interroge pas.
                var source = (Config.dataSource() == Config.SOURCE_NIGHTSCOUT) ? "Nightscout" : "Libre 3";
                var lastFetch = Store.getLastFetch();
                if (lastFetch == null) {
                    text = source;
                } else {
                    var since = Time.now().value() - lastFetch;
                    text = source + "  releve " + Fmt.formatAge(since);
                }
            }
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * 0.11).toNumber(), Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Valeur courante en gros, avec la fleche de tendance a droite.
    hidden function drawValue(dc, width, height, value, trend, color, mmol) {
        var text = Fmt.formatGlucose(value, mmol);
        var centerY = (height * 0.35).toNumber();
        var arrowSize = (width * 0.10).toNumber();
        var gap = (width * 0.04).toNumber();
        var hasArrow = (value != null && trend != Fmt.TREND_UNKNOWN);

        var font = (value == null)
            ? Graphics.FONT_LARGE
            : pickValueFont(dc, text, (width * 0.62).toNumber());
        var textWidth = dc.getTextWidthInPixels(text, font);
        var totalWidth = textWidth + (hasArrow ? (gap + arrowSize * 2) : 0);
        var startX = ((width - totalWidth) / 2).toNumber();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, centerY, font, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (hasArrow) {
            Arrow.draw(dc, startX + textWidth + gap + arrowSize, centerY, arrowSize, trend, color);
        }
    }

    //! Choisit la plus grande police numerique qui tient dans la largeur donnee.
    hidden function pickValueFont(dc, text, maxWidth) {
        var candidates = [
            Graphics.FONT_NUMBER_THAI_HOT,
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD
        ];
        for (var i = 0; i < candidates.size(); i += 1) {
            if (dc.getTextWidthInPixels(text, candidates[i]) <= maxWidth) {
                return candidates[i];
            }
        }
        return Graphics.FONT_NUMBER_MILD;
    }

    //! Variation depuis ~15 min et unite de mesure.
    hidden function drawDelta(dc, width, height, reading, mmol) {
        var text = Fmt.unitLabel(mmol);
        var timestamp = Store.readingTime(reading);
        var value = Store.readingValue(reading);
        if (timestamp != null && value != null) {
            var previous = Store.valueBefore(timestamp, 900);
            if (previous != null) {
                text = Fmt.formatDelta(value - previous, mmol) + "  " + text;
            }
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * 0.52).toNumber(), Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Bas de l'ecran : anciennete de la mesure et heure de la mesure.
    hidden function drawFooter(dc, width, height, reading, age) {
        var timestamp = Store.readingTime(reading);
        var text;
        if (timestamp == null) {
            text = "Aucune mesure";
        } else {
            text = "il y a " + Fmt.formatAge(age) + "  -  " + Fmt.formatClock(timestamp);
        }
        var color = Theme.isStale(age) ? Graphics.COLOR_ORANGE : Graphics.COLOR_LT_GRAY;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * 0.90).toNumber(), Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- Courbe ------------------------------------------------------------

    hidden function drawChart(dc, width, height) {
        var top = (height * 0.58).toNumber();
        var bottom = (height * 0.83).toNumber();
        var chartHeight = bottom - top;
        if (chartHeight < 12) {
            return;
        }

        // Sur un ecran rond, on rentre la courbe dans la corde la plus etroite
        // de la zone occupee (donc celle du bas).
        var margin = (width * 0.10).toNumber();
        if (mIsRound) {
            var half = chordHalfWidth(width, height, bottom);
            var inset = ((width / 2) - half).toNumber() + 6;
            if (inset > margin) {
                margin = inset;
            }
        }
        var left = margin;
        var chartWidth = width - (2 * margin);
        if (chartWidth < 30) {
            return;
        }

        var spanSeconds = Config.chartHours() * 3600;
        var now = Time.now().value();
        var minTime = now - spanSeconds;

        var lowThreshold = Config.low();
        var highThreshold = Config.high();
        var minValue = lowThreshold - 30;
        var maxValue = highThreshold + 40;

        var history = Store.getHistory();
        var visible = [];
        for (var i = 0; i < history.size(); i += 1) {
            var point = history[i];
            if (!(point instanceof Lang.Array) || point.size() < 2) {
                continue;
            }
            if (point[0] == null || point[1] == null || point[0] < minTime) {
                continue;
            }
            visible.add(point);
            if (point[1] < minValue) { minValue = point[1] - 10; }
            if (point[1] > maxValue) { maxValue = point[1] + 10; }
        }
        if (minValue < 40) { minValue = 40; }
        if (maxValue > 400) { maxValue = 400; }
        if ((maxValue - minValue) < 60) { maxValue = minValue + 60; }
        var valueSpan = maxValue - minValue;

        // Plage cible (entre les seuils bas et haut).
        var bandTop = valueToY(highThreshold, minValue, valueSpan, top, chartHeight);
        var bandBottom = valueToY(lowThreshold, minValue, valueSpan, top, chartHeight);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(left, bandTop, chartWidth, bandBottom - bandTop);

        // Axe du temps.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, bottom, left + chartWidth, bottom);

        if (visible.size() == 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, (top + chartHeight / 2), Graphics.FONT_XTINY, "pas d'historique",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var radius = (width > 280) ? 3 : 2;
        for (var i = 0; i < visible.size(); i += 1) {
            var point = visible[i];
            var x = left + (((point[0] - minTime).toFloat() / spanSeconds) * chartWidth);
            var y = valueToY(point[1], minValue, valueSpan, top, chartHeight);
            dc.setColor(Theme.colorForValue(point[1]), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x.toNumber(), y, radius);
        }
    }

    //! Convertit une glycemie en ordonnee ecran, bornee a la zone du graphique.
    hidden function valueToY(value, minValue, valueSpan, top, chartHeight) {
        var ratio = (value - minValue).toFloat() / valueSpan;
        if (ratio < 0) { ratio = 0.0; }
        if (ratio > 1) { ratio = 1.0; }
        return (top + chartHeight - (ratio * chartHeight)).toNumber();
    }

    //! Demi-largeur disponible a une ordonnee donnee sur un ecran rond.
    hidden function chordHalfWidth(width, height, y) {
        var radius = width / 2.0;
        var dy = (y - (height / 2.0)).abs();
        if (dy >= radius) {
            return 0.0;
        }
        return Math.sqrt((radius * radius) - (dy * dy));
    }
}
