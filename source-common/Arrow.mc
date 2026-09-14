//
// Arrow - dessin de la fleche de tendance.
//
// Dessinee geometriquement plutot qu'avec un caractere Unicode : les polices
// embarquees des montres Garmin ne contiennent pas les fleches diagonales.
//
using Toybox.Graphics;
using Toybox.Math;

(:glance)
module Arrow {

    //! Dessine la fleche de tendance centree sur (centerX, centerY).
    //! @param size demi-longueur de la fleche en pixels
    function draw(dc, centerX, centerY, size, trend, color) {
        if (trend == Fmt.TREND_UNKNOWN) {
            return;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var angle = Fmt.trendAngle(trend);
        if (trend == Fmt.TREND_DOUBLE_UP || trend == Fmt.TREND_DOUBLE_DOWN) {
            var offset = (size * 0.55).toNumber();
            drawSingle(dc, centerX - offset, centerY, size * 0.9, angle);
            drawSingle(dc, centerX + offset, centerY, size * 0.9, angle);
        } else {
            drawSingle(dc, centerX, centerY, size, angle);
        }
    }

    function drawSingle(dc, centerX, centerY, size, angleDegrees) {
        var radians = Math.toRadians(angleDegrees);
        var cosA = Math.cos(radians);
        var sinA = Math.sin(radians);

        // Repere local : la fleche pointe vers +x ; l'axe y de l'ecran est inverse.
        var tail = rotate(centerX, centerY, -size, 0, cosA, sinA);
        var neck = rotate(centerX, centerY, size * 0.2, 0, cosA, sinA);
        var tip = rotate(centerX, centerY, size, 0, cosA, sinA);
        var left = rotate(centerX, centerY, size * 0.2, size * 0.55, cosA, sinA);
        var right = rotate(centerX, centerY, size * 0.2, -size * 0.55, cosA, sinA);

        var penWidth = (size * 0.32).toNumber();
        if (penWidth < 1) {
            penWidth = 1;
        }
        dc.setPenWidth(penWidth);
        dc.drawLine(tail[0], tail[1], neck[0], neck[1]);
        dc.setPenWidth(1);
        dc.fillPolygon([ tip, left, right ]);
    }

    //! Rotation d'un point local (x, y) autour de (centerX, centerY),
    //! avec inversion de l'axe vertical pour passer en coordonnees ecran.
    function rotate(centerX, centerY, x, y, cosA, sinA) {
        var rx = (x * cosA) - (y * sinA);
        var ry = (x * sinA) + (y * cosA);
        return [ (centerX + rx).toNumber(), (centerY - ry).toNumber() ];
    }
}
