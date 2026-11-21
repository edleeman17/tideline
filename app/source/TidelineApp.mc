import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.Time;
import Toybox.WatchUi;

// App state shared by the views. Spot = {"n" => name, "la" => lat, "lo" => lon}.
(:glance)
class TidelineApp extends Application.AppBase {
    var spot as Dictionary? = null;
    var data as Dictionary? = null;
    var status as String = "";
    var busy as Boolean = false;
    var err as Boolean = false;

    function initialize() { AppBase.initialize(); }

    function onStart(state) as Void {
        spot = Application.Storage.getValue("spot");
        data = Application.Storage.getValue("data");
    }

    (:glance)
    function getGlanceView() {
        return [new TideGlance()];
    }

    function getInitialView() {
        var v = new MainView();
        if (spot == null) {
            useGps();
        } else if (data == null || Time.now().value() - data["at"] > 1800) {
            refresh();
        }
        return [v, new MainDelegate(v)];
    }

    function onSettingsChanged() as Void { refresh(); }

    function setSpot(s as Dictionary) as Void {
        spot = s;
        data = null;
        Application.Storage.setValue("spot", s);
        Application.Storage.deleteValue("data");
        refresh();
    }

    function key(s as Dictionary) as String { return s["la"].format("%.3f") + "," + s["lo"].format("%.3f"); }

    function noTide() as Boolean {
        var l = Application.Storage.getValue("notide");
        return spot != null && l != null && l.indexOf(key(spot)) >= 0;
    }

    function toggleNoTide() as Void {
        var l = Application.Storage.getValue("notide");
        if (l == null) { l = []; }
        var k = key(spot);
        if (l.indexOf(k) >= 0) { l.remove(k); } else { l.add(k); }
        Application.Storage.setValue("notide", l);
        refresh();
    }

    function favs() as Array {
        var f = Application.Storage.getValue("favs");
        return f == null ? [] : f;
    }

    function isFav() as Boolean {
        var f = favs();
        for (var i = 0; i < f.size(); i++) { if (key(f[i]).equals(key(spot))) { return true; } }
        return false;
    }

    function toggleFav() as Void {
        var f = favs(), out = [], found = false;
        for (var i = 0; i < f.size(); i++) {
            if (key(f[i]).equals(key(spot))) { found = true; } else { out.add(f[i]); }
        }
        if (!found) { out.add(spot); }
        Application.Storage.setValue("favs", out);
    }

    // GPS: last known position if any, else a one-shot fix.
    function useGps() as Void {
        status = "FINDING GPS";
        err = false;
        var info = Position.getInfo();
        if (info != null && info.position != null && info.accuracy != Position.QUALITY_NOT_AVAILABLE) {
            var d = info.position.toDegrees();
            if (d[0].abs() < 90 && !(d[0] == 180 && d[1] == 180)) {
                setSpot({"n" => "Here", "la" => d[0].toFloat(), "lo" => d[1].toFloat()});
                return;
            }
        }
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPos));
        WatchUi.requestUpdate();
    }

    function onPos(info as Position.Info) as Void {
        var d = info.position.toDegrees();
        setSpot({"n" => "Here", "la" => d[0].toFloat(), "lo" => d[1].toFloat()});
    }

    function refresh() as Void {
        if (spot == null || busy) { return; }
        busy = true;
        err = false;
        status = "LOADING";
        new Fetcher(spot["la"], spot["lo"], noTide(), method(:onData)).start();
        WatchUi.requestUpdate();
    }

    function onData(res, e) as Void {
        busy = false;
        if (res != null) {
            data = res;
            status = "";
            Application.Storage.setValue("data", res);
            Application.Storage.setValue("glance", glanceSummary(res));
        } else {
            status = e; // keep showing the last data with the error
            err = true;
        }
        WatchUi.requestUpdate();
    }

    // Small dict for the glance (64 KB memory limit there).
    function glanceSummary(d as Dictionary) as Dictionary {
        var g = {"n" => spot["n"], "kt" => d["wind"]["kt"], "g" => d["wind"]["g"], "d" => d["wind"]["d"],
                 "inl" => d["inl"], "at" => d["at"], "ev" => [], "wv" => d["wave"] == null ? null : d["wave"]["h"]};
        var ev = d["tide"]["ev"];
        for (var i = 0; i < ev.size() && g["ev"].size() < 4; i++) { g["ev"].add(ev[i]); }
        return g;
    }
}

(:glance)
function app() as TidelineApp { return Application.getApp() as TidelineApp; }

// Wind speed in the chosen unit (data is always knots).
(:glance)
function spd(kt) as String {
    if (kt == null) { return "--"; }
    var u = Application.Properties.getValue("units");
    var f = u == 1 ? 1.15078 : u == 2 ? 1.852 : 1.0;
    return Math.round(kt * f).toNumber().toString();
}

(:glance)
function unitName() as String {
    var u = Application.Properties.getValue("units");
    return u == 1 ? "mph" : u == 2 ? "km/h" : "kt";
}
