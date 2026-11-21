// Glance: one line from the last fetch (no network here; 64 KB limit).
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

(:glance)
class TideGlance extends WatchUi.GlanceView {
    function initialize() { GlanceView.initialize(); }

    function onUpdate(dc as Graphics.Dc) as Void {
        var g = Application.Storage.getValue("glance");
        var w = dc.getWidth(), h = dc.getHeight();
        if (g == null) {
            txt(dc, "TIDELINE", 0, h / 2, 22, C_FG, -1, true);
            return;
        }
        txt(dc, "TIDELINE · " + short(g["n"], 20), 0, h * 0.28, 16, C_DIM, -1, true);
        arrow(dc, 14, h * 0.68, 13, g["d"], C_WIND);
        txt(dc, spd(g["kt"]) + " " + card(g["d"]), 34, h * 0.68, 26, C_FG, -1, true);
        var now = Time.now().value();
        var ev = g["ev"];
        var n = null;
        for (var i = 0; i < ev.size(); i++) { if (ev[i]["t"] > now) { n = ev[i]; break; } }
        if (g["inl"] || n == null) {
            txt(dc, "GUST " + spd(g["g"]), w * 0.42, h * 0.68, 22, C_GUST, -1, true);
        } else {
            var hi = n["y"].equals("H");
            txt(dc, (hi ? "HI " : "LO ") + hhmm(n["t"]), w * 0.42, h * 0.68, 22, hi ? C_HI : C_LO, -1, true);
        }
        if (!g["inl"] && g["wv"] != null) { txt(dc, f1(g["wv"]) + "m", w * 0.80, h * 0.68, 20, C_WAVE, -1, true); }
    }
}
