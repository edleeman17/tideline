// Four pages (three inland): NOW, TIDE, NEXT 12H, WEATHER. Layout matches
// the browser preview (preview/) pixel for pixel (454x454).
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

class MainView extends WatchUi.View {
    var page as Number = 0;
    const MID = 227;

    function initialize() { View.initialize(); }

    function pages() as Number {
        var d = app().data;
        return d != null && d["inl"] ? 3 : 4;
    }

    function move(step as Number) as Void {
        var n = pages();
        page = (page + step + n) % n;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var a = app();
        var d = a.data;
        if (d == null) {
            txt(dc, a.spot == null ? "TIDELINE" : short(a.spot["n"], 18), MID, 180, 26, C_DIM, 0, true);
            txt(dc, a.status.equals("") ? "LOADING" : a.status, MID, 240, 30, a.err ? C_WARN : C_DIM, 0, true);
            txt(dc, "START = spots", MID, 300, 20, C_DIM, 0, false);
            return;
        }
        if (page >= pages()) { page = pages() - 1; }
        var p = d["inl"] ? [0, 2, 3][page] : page;
        if (p == 0) { drawNow(dc, d); } else if (p == 1) { drawTide(dc, d); }
        else if (p == 2) { drawHours(dc, d); } else { drawWx(dc, d); }

        var age = (Time.now().value() - d["at"]) / 60;
        var foot = a.busy ? "updating…" : !a.status.equals("") ? a.status : age < 1 ? "just now" : age < 120 ? age + "m ago" : (age / 60) + "h ago";
        txt(dc, foot, MID, 430, 16, a.err && !a.busy ? C_WARN : C_PAST, 0, false);
    }

    function header(dc, title as String) as Void {
        txt(dc, short(app().spot["n"], 18), MID, 40, 20, C_DIM, 0, true);
        txt(dc, title, MID, 66, 20, C_DIM, 0, false);
        var n = pages();
        for (var i = 0; i < n; i++) {
            dc.setColor(i == page ? C_FG : 0x444444, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(436, MID - 24 + i * 16, 4);
        }
    }

    function nextTide(d) {
        var now = Time.now().value();
        var ev = d["tide"]["ev"];
        for (var i = 0; i < ev.size(); i++) { if (ev[i]["t"] > now) { return ev[i]; } }
        return null;
    }

    function drawNow(dc, d) as Void {
        header(dc, "NOW");
        var w = d["wind"];
        arrow(dc, 140, 175, 56, w["d"], C_WIND);
        txt(dc, spd(w["kt"]), 300, 160, 96, C_FG, 0, true);
        txt(dc, unitName() + "  " + card(w["d"]), 300, 222, 22, C_WIND, 0, true);
        txt(dc, "GUST " + spd(w["g"]), 140, 262, 26, C_GUST, 0, true);
        if (d["inl"]) {
            txt(dc, "INLAND", 316, 262, 24, C_DIM, 0, true);
        } else {
            txt(dc, f1(d["wave"]["h"]) + "m " + Math.round(d["wave"]["p"] == null ? 0 : d["wave"]["p"]).toNumber() + "s", 316, 262, 26, C_WAVE, 0, true);
        }
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(70, 292, 314, 2);
        var n = nextTide(d);
        if (d["inl"] || d["tide"]["src"].equals("none")) {
            var mx = 0.0;
            var h = d["hours"];
            for (var i = 0; i < h.size(); i++) { if (h[i]["wg"] != null && h[i]["wg"] > mx) { mx = h[i]["wg"]; } }
            txt(dc, "MAX GUST " + spd(mx) + " next 12h", MID, 330, 28, mx >= 20 ? C_WARN : C_FG, 0, false);
            txt(dc, d["inl"] ? "no tide · no waves" : "tide off for this spot", MID, 372, 20, C_DIM, 0, false);
        } else if (n != null) {
            txt(dc, (n["y"].equals("H") ? "HIGH " : "LOW ") + hhmm(n["t"]), MID, 330, 40, n["y"].equals("H") ? C_HI : C_LO, 0, false);
            var mins = (n["t"] - Time.now().value()) / 60;
            txt(dc, "in " + (mins / 60) + "h" + (mins % 60).format("%02d"), MID, 372, 22, C_DIM, 0, false);
        }
        var x = d["wx"];
        if (x["t"] != null) { txt(dc, Math.round(x["t"]).toNumber() + "°  " + wxName(x["c"]), MID, 404, 20, C_DIM, 0, false); }
    }

    function drawTide(dc, d) as Void {
        var t = d["tide"];
        header(dc, t["src"].equals("UKHO") ? "TIDE " + short(t["st"], 12) : "TIDE (model)");
        var c = d["curve"];
        if (c.size() > 1) {
            var x0 = 50, x1 = 404, y0 = 110, y1 = 230;
            var mn = 99.0, mx = -99.0;
            for (var i = 0; i < c.size(); i++) { if (c[i] != null) { if (c[i] < mn) { mn = c[i]; } if (c[i] > mx) { mx = c[i]; } } }
            var rng = mx - mn > 0 ? mx - mn : 1.0;
            dc.setColor(C_WAVE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            var px = null, py = null;
            for (var i = 0; i < c.size(); i++) {
                if (c[i] == null) { px = null; continue; }
                var X = x0 + (x1 - x0) * i / 24.0, Y = y1 - (y1 - y0) * (c[i] - mn) / rng;
                if (px != null) { dc.drawLine(px, py, X, Y); }
                px = X; py = Y;
            }
            var hr = (Time.now().value() - d["day0"]) / 3600.0;
            if (hr >= 0 && hr <= 24) {
                var X = x0 + (x1 - x0) * hr / 24.0;
                dc.setColor(C_WARN, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawLine(X, y0 - 6, X, y1 + 6);
            }
            dc.setPenWidth(1);
            for (var h = 0; h <= 24; h += 6) { txt(dc, (h % 24).format("%02d"), x0 + (x1 - x0) * h / 24, y1 + 18, 16, C_DIM, 0, false); }
        }
        var now = Time.now().value();
        var ev = t["ev"];
        var row = 0;
        for (var i = 0; i < ev.size() && row < 4; i++) {
            var e = ev[i];
            if (e["t"] < now - 3 * 3600) { continue; }
            var y = 272 + row * 34;
            var past = e["t"] < now;
            var hi = e["y"].equals("H");
            txt(dc, hi ? "HIGH" : "LOW", 92, y, 26, past ? C_PAST : hi ? C_HI : C_LO, -1, true);
            txt(dc, hhmm(e["t"]), 196, y, 26, past ? C_PAST : C_FG, -1, true);
            var hs = (e["h"] > 0 && t["dat"].equals("MSL") ? "+" : "") + e["h"].format("%.1f") + "m";
            txt(dc, hs, 300, y, 22, past ? C_PAST : C_DIM, -1, false);
            row++;
        }
    }

    function drawHours(dc, d) as Void {
        header(dc, "NEXT 12H");
        var hs = d["hours"];
        if (hs.size() == 0) { return; }
        var x0 = 48, bw = 358.0 / hs.size(), base = 270;
        var mx = 15.0;
        for (var i = 0; i < hs.size(); i++) { if (hs[i]["wg"] != null && hs[i]["wg"] > mx) { mx = hs[i]["wg"]; } }
        for (var i = 0; i < hs.size(); i++) {
            var h = hs[i];
            var x = x0 + i * bw;
            var hg = 150 * (h["wg"] == null ? 0 : h["wg"]) / mx, hw = 150 * (h["ws"] == null ? 0 : h["ws"]) / mx;
            dc.setColor(C_GUSTBAR, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 3, base - hg, bw - 6, hg);
            dc.setColor(C_WIND, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 3, base - hw, bw - 6, hw);
            if (i % 2 == 0) { txt(dc, spd(h["ws"]), x + bw / 2, base - hg - 14, 18, C_FG, 0, true); }
            arrow(dc, x + bw / 2, base + 20, 9, h["wd"], C_DIM);
            if (i % 3 == 0) { txt(dc, h["h"].format("%02d"), x + bw / 2, base + 44, 17, C_DIM, 0, false); }
            if (h["wv"] != null) {
                txt(dc, h["wv"] >= 10 ? Math.round(h["wv"]).toNumber().toString() : f1(h["wv"]), x + bw / 2, base + 72, 16, C_WAVE, 0, false);
            }
        }
        txt(dc, "wind " + unitName() + " · gust" + (d["inl"] ? "" : " · wave m"), MID, 380, 18, C_DIM, 0, false);
    }

    function drawWx(dc, d) as Void {
        header(dc, "WEATHER");
        var x = d["wx"];
        txt(dc, x["t"] == null ? "--" : Math.round(x["t"]).toNumber() + "°", MID, 150, 84, C_FG, 0, true);
        txt(dc, wxName(x["c"]), MID, 210, 26, C_DIM, 0, true);
        txt(dc, "H " + Math.round(x["hi"]).toNumber() + "°  L " + Math.round(x["lo"]).toNumber() + "°", MID, 250, 24, C_FG, 0, false);
        txt(dc, "RAIN " + x["pp"] + "% next 12h", MID, 286, 22, x["pp"] >= 50 ? C_WARN : C_DIM, 0, false);
        if (!d["inl"]) { txt(dc, "SEA " + f1(x["sea"]) + "°", MID, 322, 26, C_WAVE, 0, true); }
        txt(dc, "RISE " + hhmm(x["rise"]) + "  SET " + hhmm(x["set"]), MID, 360, 24, C_HI, 0, false);
        if (!d["inl"]) {
            var w = d["wave"];
            txt(dc, "SWELL " + f1(w["sh"]) + "m " + Math.round(w["sp"] == null ? 0 : w["sp"]).toNumber() + "s " + card(w["sd"]), MID, 396, 18, C_DIM, 0, false);
        }
    }
}

class MainDelegate extends WatchUi.BehaviorDelegate {
    var view as MainView;
    function initialize(v as MainView) { BehaviorDelegate.initialize(); view = v; }
    function onNextPage() as Boolean { view.move(1); return true; }
    function onPreviousPage() as Boolean { view.move(-1); return true; }
    function onSelect() as Boolean { openSpotsMenu(); return true; }
    function onMenu() as Boolean { openSpotsMenu(); return true; }
}
