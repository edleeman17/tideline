// Drawing helpers: vector fonts at exact pixel sizes (same sizes as the
// browser preview in preview/), falling back to system fonts if a face is missing.
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

const C_FG = 0xFFFFFF;
const C_DIM = 0x8A8A8A;
const C_WIND = 0x55DDFF;
const C_GUST = 0x66AADD;
const C_GUSTBAR = 0x1D4D6D;
const C_WAVE = 0x55FFAA;
const C_HI = 0xFFCC33;
const C_LO = 0x4499FF;
const C_WARN = 0xFF5544;
const C_PAST = 0x555555;

(:glance)
var fontCache as Dictionary = {};

(:glance)
function font(size as Number, bold as Boolean) {
    var k = size * 2 + (bold ? 1 : 0);
    var f = fontCache[k];
    if (f == null) {
        if (Graphics has :getVectorFont) {
            f = Graphics.getVectorFont({:face => bold ? ["RobotoCondensedBold", "RobotoBold", "RobotoRegular"]
                                                      : ["RobotoCondensedRegular", "RobotoRegular"], :size => size});
        }
        if (f == null) {
            f = size >= 80 ? Graphics.FONT_NUMBER_HOT : size >= 36 ? Graphics.FONT_LARGE : size >= 24 ? Graphics.FONT_MEDIUM
              : size >= 18 ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
        }
        fontCache[k] = f;
    }
    return f;
}

// align: -1 left, 0 centre, 1 right; y is the vertical centre.
(:glance)
function txt(dc as Graphics.Dc, s as String, x, y, size as Number, col as Number, align as Number, bold as Boolean) as Void {
    var j = align < 0 ? Graphics.TEXT_JUSTIFY_LEFT : align > 0 ? Graphics.TEXT_JUSTIFY_RIGHT : Graphics.TEXT_JUSTIFY_CENTER;
    dc.setColor(col, Graphics.COLOR_TRANSPARENT);
    dc.drawText(x, y, font(size, bold), s, j | Graphics.TEXT_JUSTIFY_VCENTER);
}

// Arrow pointing where the wind is GOING (fromDeg + 180).
(:glance)
function arrow(dc as Graphics.Dc, x, y, r, fromDeg, col as Number) as Void {
    if (fromDeg == null) { return; }
    var a = (fromDeg + 180) * Math.PI / 180.0;
    var s = Math.sin(a), c = Math.cos(a);
    var pts = [[0, -r], [r * 0.6, r * 0.7], [0, r * 0.35], [-r * 0.6, r * 0.7]];
    var out = [];
    for (var i = 0; i < pts.size(); i++) {
        var px = pts[i][0], py = pts[i][1];
        out.add([x + px * c - py * s, y + px * s + py * c]);
    }
    dc.setColor(col, Graphics.COLOR_TRANSPARENT);
    dc.fillPolygon(out);
}

(:glance)
function f1(v) as String { return v == null ? "--" : v.format("%.1f"); }

// Cut long names at a word boundary.
(:glance)
function short(s as String, n as Number) as String {
    s = s.toUpper();
    if (s.length() <= n) { return s; }
    var cut = s.substring(0, n + 1);
    var last = -1;
    for (var i = 0; i < cut.length(); i++) { if (cut.substring(i, i + 1).equals(" ")) { last = i; } }
    return last > 6 ? s.substring(0, last) : s.substring(0, n);
}
