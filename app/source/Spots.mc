// START menu: pick where conditions are for.
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.WatchUi;

function openSpotsMenu() as Void {
    var a = app();
    var m = new WatchUi.Menu2({:title => "SPOTS"});
    m.addItem(new WatchUi.MenuItem("Here (GPS)", "use my position", :gps, null));
    m.addItem(new WatchUi.MenuItem("Nearby spots", "UK surf + SUP", :near, null));
    m.addItem(new WatchUi.MenuItem("Favourites", a.favs().size() + " saved", :favs, null));
    addMapItem(m);
    if (a.spot != null) {
        m.addItem(new WatchUi.MenuItem(a.isFav() ? "Remove favourite" : "Save as favourite", short(a.spot["n"], 18), :fav, null));
        m.addItem(new WatchUi.MenuItem(a.noTide() ? "Tide: OFF here" : "Tide: auto", "off for canals by the sea", :notide, null));
        m.addItem(new WatchUi.MenuItem("Refresh", null, :refresh, null));
    }
    WatchUi.pushView(m, new SpotsDelegate(), WatchUi.SLIDE_UP);
}

// Map picker only on watches with maps (monkey.jungle excludes :maps elsewhere).
(:maps)
function addMapItem(m as WatchUi.Menu2) as Void {
    m.addItem(new WatchUi.MenuItem("Pick on map", "move target, START", :map, null));
}
(:maps)
function openMap() as Void {
    var a = app();
    var c = a.spot != null ? [a.spot["la"], a.spot["lo"]] : [50.78, -0.98];
    var v = new MapPick(c[0], c[1]);
    WatchUi.pushView(v, new MapPickDelegate(v), WatchUi.SLIDE_LEFT);
}
(:nomaps)
function addMapItem(m as WatchUi.Menu2) as Void {}
(:nomaps)
function openMap() as Void {}

function km(la1, lo1, la2, lo2) as Float {
    var p = Math.PI / 180;
    var a = Math.pow(Math.sin((la2 - la1) * p / 2), 2) + Math.cos(la1 * p) * Math.cos(la2 * p) * Math.pow(Math.sin((lo2 - lo1) * p / 2), 2);
    return (12742 * Math.asin(Math.sqrt(a))).toFloat();
}

class SpotsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var a = app();
        var id = item.getId();
        if (id == :gps) { WatchUi.popView(WatchUi.SLIDE_DOWN); a.useGps(); }
        else if (id == :near) { nearbyMenu(); }
        else if (id == :favs) { favsMenu(); }
        else if (id == :map) { openMap(); }
        else if (id == :fav) { a.toggleFav(); WatchUi.popView(WatchUi.SLIDE_DOWN); }
        else if (id == :notide) { WatchUi.popView(WatchUi.SLIDE_DOWN); a.toggleNoTide(); }
        else if (id == :refresh) { WatchUi.popView(WatchUi.SLIDE_DOWN); a.refresh(); }
    }

    function nearbyMenu() as Void {
        var a = app();
        var c = a.spot != null ? [a.spot["la"], a.spot["lo"]] : [50.78, -0.98];
        var all = WatchUi.loadResource(Rez.JsonData.Spots) as Array;
        var ds = [];
        for (var i = 0; i < all.size(); i++) { ds.add([km(c[0], c[1], all[i][1], all[i][2]), i]); }
        // partial selection sort: 15 nearest
        var m = new WatchUi.Menu2({:title => "NEARBY"});
        for (var k = 0; k < 15 && k < ds.size(); k++) {
            var b = k;
            for (var i = k + 1; i < ds.size(); i++) { if (ds[i][0] < ds[b][0]) { b = i; } }
            var t = ds[k]; ds[k] = ds[b]; ds[b] = t;
            var s = all[ds[k][1]];
            m.addItem(new WatchUi.MenuItem(s[0], ds[k][0].format("%.0f") + " km", {"n" => s[0], "la" => s[1].toFloat(), "lo" => s[2].toFloat()}, null));
        }
        WatchUi.pushView(m, new PickDelegate(), WatchUi.SLIDE_LEFT);
    }

    function favsMenu() as Void {
        var f = app().favs();
        var m = new WatchUi.Menu2({:title => "FAVOURITES"});
        if (f.size() == 0) { m.addItem(new WatchUi.MenuItem("None yet", "pick a spot, then Save", :none, null)); }
        for (var i = 0; i < f.size(); i++) { m.addItem(new WatchUi.MenuItem(f[i]["n"], null, f[i], null)); }
        WatchUi.pushView(m, new PickDelegate(), WatchUi.SLIDE_LEFT);
    }
}

// Selecting a spot item: close the menus and load it.
class PickDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var s = item.getId();
        if (!(s instanceof Dictionary)) { return; }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        app().setSpot(s);
    }
}

// Map picker. MapView can't report where the user browsed to, so the app
// owns the visible area: drag or UP/DOWN to move/zoom, START picks the centre.
(:maps)
class MapPick extends WatchUi.MapView {
    var la as Float, lo as Float;
    var span as Float = 0.2; // degrees of latitude shown
    // Buttons only (touch is often off on the water): UP/DOWN act on the
    // current mode; hold UP (menu) cycles mode.
    var mode as Number = 0;
    const MODES = ["UP/DN: north-south", "UP/DN: east-west", "UP/DN: zoom"];
    const SPANS = [0.05, 0.1, 0.2, 0.5, 1.5, 4.0];

    function initialize(lat as Float, lon as Float) {
        MapView.initialize();
        la = lat; lo = lon;
        setMapMode(WatchUi.MAP_MODE_PREVIEW);
        var sw = System.getDeviceSettings().screenWidth;
        setScreenVisibleArea(0, 0, sw, sw);
        var all = WatchUi.loadResource(Rez.JsonData.Spots) as Array;
        var mk = [];
        for (var i = 0; i < all.size(); i++) {
            var m = new WatchUi.MapMarker(new Position.Location({:latitude => all[i][1], :longitude => all[i][2], :format => :degrees}));
            m.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
            mk.add(m);
        }
        setMapMarker(mk);
        apply();
    }

    function apply() as Void {
        var w = span / Math.cos(la * Math.PI / 180);
        setMapVisibleArea(
            new Position.Location({:latitude => la + span / 2, :longitude => lo - w / 2, :format => :degrees}),
            new Position.Location({:latitude => la - span / 2, :longitude => lo + w / 2, :format => :degrees}));
        WatchUi.requestUpdate();
    }

    function zoom(step as Number) as Void {
        var i = SPANS.indexOf(span);
        i = i < 0 ? 2 : i + step;
        if (i < 0) { i = 0; } if (i >= SPANS.size()) { i = SPANS.size() - 1; }
        span = SPANS[i];
        apply();
    }

    function pan(dx as Number, dy as Number) as Void {
        var deg = span / 454.0;
        la = la + dy * deg;
        lo = lo - dx * deg / Math.cos(la * Math.PI / 180);
        apply();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        MapView.onUpdate(dc);
        SC = dc.getWidth() / 454.0;
        // crosshair: black outline under white so it shows on any map colour
        for (var k = 0; k < 2; k++) {
            dc.setColor(k == 0 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            pen(dc, k == 0 ? 8 : 4);
            dc.drawLine(sc(227), sc(187), sc(227), sc(213)); dc.drawLine(sc(227), sc(241), sc(227), sc(267));
            dc.drawLine(sc(187), sc(227), sc(213), sc(227)); dc.drawLine(sc(241), sc(227), sc(267), sc(227));
            dc.drawCircle(sc(227), sc(227), sc(6));
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(sc(97), sc(370), sc(260), sc(62), sc(10));
        txt(dc, MODES[mode], 227, 386, 18, C_FG, 0, true);
        txt(dc, "hold UP: mode · START: pick", 227, 412, 16, C_DIM, 0, false);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(sc(147), sc(26), sc(160), sc(30), sc(8));
        txt(dc, la.format("%.3f") + ", " + lo.format("%.3f"), 227, 41, 18, C_FG, 0, true);
    }
}

(:maps)
class MapPickDelegate extends WatchUi.BehaviorDelegate {
    var v as MapPick;
    var sx = null, sy = null;
    function initialize(view as MapPick) { BehaviorDelegate.initialize(); v = view; }
    function step(dir as Number) as Void {
        if (v.mode == 0) { v.pan(0, dir * 120); }        // UP = north
        else if (v.mode == 1) { v.pan(-dir * 120, 0); }  // UP = east
        else { v.zoom(-dir); }                           // UP = zoom in
    }
    function onPreviousPage() as Boolean { step(1); return true; }
    function onNextPage() as Boolean { step(-1); return true; }
    function onMenu() as Boolean { v.mode = (v.mode + 1) % 3; WatchUi.requestUpdate(); return true; }
    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        app().setSpot({"n" => "Pin " + v.la.format("%.2f") + "," + v.lo.format("%.2f"), "la" => v.la, "lo" => v.lo});
        return true;
    }
    function onDrag(e as WatchUi.DragEvent) as Boolean {
        var c = e.getCoordinates();
        if (e.getType() == WatchUi.DRAG_TYPE_START) { sx = c[0]; sy = c[1]; }
        else if (e.getType() == WatchUi.DRAG_TYPE_STOP && sx != null) { v.pan(((c[0] - sx) / SC).toNumber(), ((c[1] - sy) / SC).toNumber()); sx = null; }
        return true;
    }
    // Swipes are coarse pans on screens without drag events.
    function onSwipe(e as WatchUi.SwipeEvent) as Boolean {
        var d = e.getDirection();
        if (d == WatchUi.SWIPE_LEFT) { v.pan(-150, 0); } else if (d == WatchUi.SWIPE_RIGHT) { v.pan(150, 0); }
        else if (d == WatchUi.SWIPE_UP) { v.pan(0, -150); } else { v.pan(0, 150); }
        return true;
    }
}
