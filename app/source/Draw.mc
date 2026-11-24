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

// Layouts are drawn on a 454x454 design grid; SC scales them to the real
// screen (set per onUpdate). The glance draws in real pixels (SC = 1).
(:glance)
var SC as Float = 1.0;

(:glance)
function sc(v) { return v * SC; }

(:glance)
function pen(dc as Graphics.Dc, w as Number) as Void {
    var p = (w * SC + 0.5).toNumber();
    dc.setPenWidth(p < 1 ? 1 : p);
}

// Vector Roboto where the watch has it; otherwise the largest system font
// that fits the requested pixel height (some watches lack the Roboto faces).
(:glance)
function font(dc as Graphics.Dc, size as Number, bold as Boolean) {
    var k = size * 2 + (bold ? 1 : 0);
    var f = fontCache[k];
    if (f == null) {
        if (Graphics has :getVectorFont) {
            f = Graphics.getVectorFont({:face => bold ? ["RobotoCondensedBold", "RobotoBold", "RobotoRegular"]
                                                      : ["RobotoCondensedRegular", "RobotoRegular"], :size => size});
        }
        if (f == null) { f = sysFont(dc, size); }
        fontCache[k] = f;
    }
    return f;
}

(:glance)
function digits(s as String) as Boolean {
    var a = s.toCharArray();
    for (var i = 0; i < a.size(); i++) { if (a[i] < '0' || a[i] > '9') { return false; } }
    return a.size() > 0;
}

(:glance)
function numFont(dc as Graphics.Dc, size as Number) {
    var fs = [Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_HOT];
    var best = Graphics.FONT_LARGE;
    for (var i = 0; i < fs.size(); i++) {
        if (dc.getFontHeight(fs[i]) <= size * 1.15) { best = fs[i]; }
    }
    return best;
}

// Glances only accept the glance fonts.
(:glance)
var inGlance as Boolean = false;

(:glance)
function sysFont(dc as Graphics.Dc, size as Number) {
    if (inGlance) { return Graphics has :FONT_GLANCE ? Graphics.FONT_GLANCE : Graphics.FONT_XTINY; }
    var fs = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL, Graphics.FONT_MEDIUM, Graphics.FONT_LARGE];
    var best = fs[0];
    for (var i = 1; i < fs.size(); i++) {
        if (dc.getFontHeight(fs[i]) <= size * 1.15) { best = fs[i]; }
    }
    return best;
}

// align: -1 left, 0 centre, 1 right; y is the vertical centre.
(:glance)
function txt(dc as Graphics.Dc, s as String, x, y, size as Number, col as Number, align as Number, bold as Boolean) as Void {
    if (SC != 1.0) {
        x = x * SC; y = y * SC;
        // text shrinks less than the layout so small screens stay readable
        size = (size * (SC < 1.0 ? Math.pow(SC, 0.7) : SC) + 0.5).toNumber();
        if (size < 11) { size = 11; }
    }
    var j = align < 0 ? Graphics.TEXT_JUSTIFY_LEFT : align > 0 ? Graphics.TEXT_JUSTIFY_RIGHT : Graphics.TEXT_JUSTIFY_CENTER;
    dc.setColor(col, Graphics.COLOR_TRANSPARENT);
    var f = font(dc, size, bold);
    if (size >= 40 && (f instanceof Number) && digits(s)) { f = numFont(dc, size); }
    try {
        dc.drawText(x, y, f, s, j | Graphics.TEXT_JUSTIFY_VCENTER);
    } catch (e) {
        f = sysFont(dc, size);
        fontCache[size * 2 + (bold ? 1 : 0)] = f;
        dc.drawText(x, y, f, s, j | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Arrow pointing where the wind is GOING (fromDeg + 180).
(:glance)
function arrow(dc as Graphics.Dc, x, y, r, fromDeg, col as Number) as Void {
    if (fromDeg == null) { return; }
    x = x * SC; y = y * SC; r = r * SC;
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
