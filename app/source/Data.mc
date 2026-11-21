// Fetches conditions straight from Open-Meteo (and optionally UKHO) through
// the phone. No server. Mirrors tide.js in the browser preview (preview/) step for step.
import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

const WX_URL = "https://api.open-meteo.com/v1/forecast";
const MAR_URL = "https://marine-api.open-meteo.com/v1/marine";
const UKHO_URL = "https://admiraltyapi.azure-api.net/uktidalapi/api/V1";
// Open-Meteo Marine snaps a point to the nearest sea cell. If that cell is
// more than INLAND_KM away (or has no data) the spot is treated as inland.
const INLAND_KM = 14.0;

(:glance)
function card(d) as String {
    if (d == null) { return ""; }
    var c = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    return c[((d.toFloat() / 22.5) + 0.5).toNumber() % 16];
}

(:glance)
function r1(v) {
    if (v == null) { return null; }
    return Math.round(v.toFloat() * 10.0) / 10.0;
}

(:glance)
function hhmm(t) as String {
    var i = Gregorian.info(new Time.Moment(t), Time.FORMAT_SHORT);
    return i.hour.format("%02d") + ":" + i.min.format("%02d");
}

function wxName(c) as String {
    if (c == null) { return ""; }
    if (c == 0) { return "CLEAR"; } if (c <= 2) { return "P CLOUD"; } if (c == 3) { return "CLOUDY"; }
    if (c <= 48) { return "FOG"; } if (c <= 57) { return "DRIZZLE"; } if (c <= 67) { return "RAIN"; }
    if (c <= 77) { return "SNOW"; } if (c <= 82) { return "SHOWERS"; } if (c <= 86) { return "SNOW"; }
    return "THUNDER";
}

// High/low = local max/min of hourly sea level, refined with a parabola.
function modelTides(times as Array, lv as Array) as Array {
    var out = [];
    for (var i = 1; i < lv.size() - 1; i++) {
        var a = lv[i - 1], b = lv[i], c = lv[i + 1];
        if (a == null || b == null || c == null) { continue; }
        a = a.toFloat(); b = b.toFloat(); c = c.toFloat();
        var hi = b > a && b >= c;
        var lo = b < a && b <= c;
        if (!hi && !lo) { continue; }
        var den = a - 2 * b + c;
        var off = den != 0 ? 0.5 * (a - c) / den : 0.0;
        out.add({"t" => times[i] + (off * 3600).toNumber(), "y" => hi ? "H" : "L",
                 "h" => Math.round((b - 0.25 * (a - c) * off) * 100) / 100.0});
    }
    return out;
}

class Fetcher {
    var lat as Float, lon as Float, noTide as Boolean, cb as Method;
    var w = null, m = null, tide = null;

    function initialize(la as Float, lo as Float, nt as Boolean, callback as Method) {
        lat = la; lon = lo; noTide = nt; cb = callback;
    }

    function ll(la as Float, lo as Float) as Dictionary {
        return {"latitude" => la.format("%.3f"), "longitude" => lo.format("%.3f"),
                "timeformat" => "unixtime", "timezone" => "Europe/London"};
    }

    function get(url as String, params as Dictionary, headers, handler as Method) as Void {
        var opt = {:method => Communications.HTTP_REQUEST_METHOD_GET,
                   :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON};
        if (headers != null) { opt[:headers] = headers; }
        Communications.makeWebRequest(url, params, opt, handler);
    }

    function start() as Void {
        var p = ll(lat, lon);
        p["wind_speed_unit"] = "kn";
        p["forecast_days"] = "2";
        p["current"] = "temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code";
        p["hourly"] = "wind_speed_10m,wind_direction_10m,wind_gusts_10m,temperature_2m,precipitation_probability,weather_code";
        p["daily"] = "sunrise,sunset,temperature_2m_max,temperature_2m_min";
        get(WX_URL, p, null, method(:onWx));
    }

    function onWx(code as Number, data) as Void {
        if (code != 200 || !(data instanceof Dictionary)) { cb.invoke(null, "WEATHER " + code); return; }
        w = data;
        if (noTide) { finish(); } else { marine(); }
    }

    function marine() as Void {
        var p = ll(lat, lon);
        p["forecast_days"] = "3";
        p["hourly"] = "wave_height,wave_period,wave_direction,swell_wave_height,swell_wave_period,swell_wave_direction,sea_level_height_msl,sea_surface_temperature";
        get(MAR_URL, p, null, method(:onMarine));
    }

    function onMarine(code as Number, data) as Void {
        if (code == 200 && data instanceof Dictionary) {
            var wh = data["hourly"]["wave_height"];
            var near = km(lat, lon, data["latitude"], data["longitude"]) <= INLAND_KM;
            for (var i = 0; near && i < 24 && i < wh.size(); i++) {
                if (wh[i] != null) { m = data; break; }
            }
        } else {
            cb.invoke(null, "MARINE " + code); return;
        }
        var key = Application.Properties.getValue("ukhoKey");
        if (m != null && key != null && key.length() > 10) {
            get(UKHO_URL + "/Stations", {}, {"Ocp-Apim-Subscription-Key" => key}, method(:onStations));
        } else {
            finish();
        }
    }

    // UKHO: nearest station, then its next 4 days of events. Any failure -> model.
    var stName = "";
    function onStations(code as Number, data) as Void {
        if (code != 200 || !(data instanceof Dictionary)) { finish(); return; }
        var best = null, bd = 1e9;
        var f = data["features"];
        var k = Math.cos(lat * Math.PI / 180);
        for (var i = 0; i < f.size(); i++) {
            var c = f[i]["geometry"]["coordinates"];
            var dy = c[1] - lat, dx = (c[0] - lon) * k;
            var d = dy * dy + dx * dx;
            if (d < bd) { bd = d; best = f[i]["properties"]; }
        }
        if (best == null) { finish(); return; }
        stName = best["Name"];
        var key = Application.Properties.getValue("ukhoKey");
        get(UKHO_URL + "/Stations/" + best["Id"] + "/TidalEvents", {"duration" => "4"},
            {"Ocp-Apim-Subscription-Key" => key}, method(:onEvents));
    }

    function onEvents(code as Number, data) as Void {
        if (code == 200 && data instanceof Array) {
            var ev = [];
            for (var i = 0; i < data.size(); i++) {
                var e = data[i];
                var s = e["DateTime"]; // 2026-11-21T08:31:00(.000) UTC
                var t = Gregorian.moment({:year => s.substring(0, 4).toNumber(), :month => s.substring(5, 7).toNumber(),
                    :day => s.substring(8, 10).toNumber(), :hour => s.substring(11, 13).toNumber(),
                    :minute => s.substring(14, 16).toNumber(), :second => 0}).value();
                var h = e["Height"];
                ev.add({"t" => t, "y" => e["EventType"].equals("HighWater") ? "H" : "L",
                        "h" => h == null ? 0.0 : Math.round(h.toFloat() * 100) / 100.0});
            }
            tide = {"src" => "UKHO", "st" => stName, "dat" => "CD", "ev" => ev};
        }
        finish();
    }

    function finish() as Void {
        var now = Time.now().value();
        var wh = w["hourly"];
        var inland = m == null;
        var mh = inland ? null : m["hourly"];
        var i = idx(wh["time"], now);
        var j = inland ? 0 : idx(mh["time"], now);

        if (tide == null) {
            tide = inland ? {"src" => "none", "st" => "", "dat" => "", "ev" => []}
                          : {"src" => "model", "st" => "", "dat" => "MSL", "ev" => modelTides(mh["time"], mh["sea_level_height_msl"])};
        }
        var ev = [];
        var all = tide["ev"];
        for (var k = 0; k < all.size() && ev.size() < 10; k++) {
            if (all[k]["t"] > now - 7 * 3600) { ev.add(all[k]); }
        }
        tide["ev"] = ev;

        var hours = [];
        for (var k = 0; k < 12 && i + k < wh["time"].size(); k++) {
            var a = i + k, b = j + k;
            hours.add({"h" => Gregorian.info(new Time.Moment(wh["time"][a]), Time.FORMAT_SHORT).hour,
                "ws" => r1(wh["wind_speed_10m"][a]), "wg" => r1(wh["wind_gusts_10m"][a]), "wd" => wh["wind_direction_10m"][a],
                "wv" => inland ? null : r1(mh["wave_height"][b])});
        }
        var pp = 0;
        for (var k = i; k < i + 12 && k < wh["precipitation_probability"].size(); k++) {
            var v = wh["precipitation_probability"][k];
            if (v != null && v > pp) { pp = v; }
        }
        var curve = [];
        if (!inland) {
            var sl = mh["sea_level_height_msl"];
            for (var k = 0; k < 25 && k < sl.size(); k++) { curve.add(sl[k] == null ? null : r1(sl[k])); }
        }
        var c = w["current"], d = w["daily"];
        var res = {
            "at" => now, "inl" => inland, "day0" => wh["time"][0],
            "wind" => {"kt" => r1(c["wind_speed_10m"]), "g" => r1(c["wind_gusts_10m"]), "d" => c["wind_direction_10m"]},
            "wave" => inland ? null : {"h" => r1(mh["wave_height"][j]), "p" => r1(mh["wave_period"][j]),
                "sh" => r1(mh["swell_wave_height"][j]), "sp" => r1(mh["swell_wave_period"][j]), "sd" => mh["swell_wave_direction"][j]},
            "wx" => {"t" => r1(c["temperature_2m"]), "c" => c["weather_code"], "hi" => r1(d["temperature_2m_max"][0]),
                "lo" => r1(d["temperature_2m_min"][0]), "pp" => pp, "sea" => inland ? null : r1(mh["sea_surface_temperature"][j]),
                "rise" => d["sunrise"][0], "set" => d["sunset"][0]},
            "tide" => tide, "curve" => curve, "hours" => hours
        };
        w = null; m = null;
        cb.invoke(res, null);
    }

    // Index of the current hour in an hourly unixtime array.
    function idx(ts as Array, now as Number) as Number {
        for (var k = 0; k < ts.size(); k++) { if (ts[k] > now - 3600) { return k; } }
        return 0;
    }
}
