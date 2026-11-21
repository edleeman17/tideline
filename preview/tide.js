// Tideline data logic. The Monkey C app does exactly this, step for step:
// same two Open-Meteo requests, same land-nudge, same tide maths, same output
// shape. Keep the two in sync: if you change one, change the other.
const Tideline = (() => {
  const CARD = ['N','NNE','NE','ENE','E','ESE','SE','SSE','S','SSW','SW','WSW','W','WNW','NW','NNW'];
  const card = d => d == null ? '' : CARD[Math.round(d / 22.5) % 16];
  const r1 = v => v == null ? null : Math.round(v * 10) / 10;

  // Request 1: weather. timeformat=unixtime so the watch never parses dates.
  const WX = 'https://api.open-meteo.com/v1/forecast?wind_speed_unit=kn&timeformat=unixtime&timezone=Europe%2FLondon&forecast_days=2'
    + '&current=temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code'
    + '&hourly=wind_speed_10m,wind_direction_10m,wind_gusts_10m,temperature_2m,precipitation_probability,weather_code'
    + '&daily=sunrise,sunset,temperature_2m_max,temperature_2m_min';
  // Request 2: marine. 3 days so the tide list always has the next few events.
  const MAR = 'https://marine-api.open-meteo.com/v1/marine?timeformat=unixtime&timezone=Europe%2FLondon&forecast_days=3'
    + '&hourly=wave_height,wave_period,wave_direction,swell_wave_height,swell_wave_period,swell_wave_direction,sea_level_height_msl,sea_surface_temperature';
  // Marine snaps to the nearest sea cell; further than this = inland.
  const INLAND_KM = 14;
  const km = (a1, o1, a2, o2) => { const p = Math.PI/180, a = Math.sin((a2-a1)*p/2)**2 + Math.cos(a1*p)*Math.cos(a2*p)*Math.sin((o2-o1)*p/2)**2; return 12742*Math.asin(Math.sqrt(a)); };

  async function getJson(url, headers) {
    const r = await fetch(url, {headers});
    if (!r.ok) throw new Error(r.status + ' ' + url.split('?')[0]);
    return r.json();
  }

  // High/low = local max/min of hourly sea level, refined with a parabola
  // through the 3 points (gets times to ~10 min instead of ±30).
  function modelTides(times, lv) {
    const out = [];
    for (let i = 1; i < lv.length - 1; i++) {
      const a = lv[i-1], b = lv[i], c = lv[i+1];
      if (a == null || b == null || c == null) continue;
      const hi = b > a && b >= c, lo = b < a && b <= c;
      if (!hi && !lo) continue;
      const den = a - 2*b + c, off = den ? 0.5 * (a - c) / den : 0;
      out.push({t: Math.round(times[i] + off * 3600), type: hi ? 'H' : 'L', h: Math.round((b - 0.25*(a-c)*off) * 100) / 100});
    }
    return out;
  }

  // Optional: real port predictions from UKHO (key from the phone settings).
  async function ukhoTides(lat, lon, key) {
    const H = {'Ocp-Apim-Subscription-Key': key}, B = 'https://admiraltyapi.azure-api.net/uktidalapi/api/V1';
    const st = (await getJson(B + '/Stations', H)).features.map(f => ({id: f.properties.Id, name: f.properties.Name, lat: f.geometry.coordinates[1], lon: f.geometry.coordinates[0]}));
    const d2 = s => (s.lat-lat)**2 + ((s.lon-lon)*Math.cos(lat*Math.PI/180))**2;
    const s = st.reduce((a, b) => d2(b) < d2(a) ? b : a);
    const ev = await getJson(B + '/Stations/' + s.id + '/TidalEvents?duration=4', H);
    return {src: 'UKHO', station: s.name, datum: 'CD',
      events: ev.map(e => ({t: Math.round(Date.parse(e.DateTime.split('.')[0] + 'Z') / 1000), type: e.EventType === 'HighWater' ? 'H' : 'L', h: Math.round((e.Height||0)*100)/100}))};
  }

  async function fetchConditions(lat, lon, ukhoKey) {
    const ll = (a, o) => '&latitude=' + a.toFixed(3) + '&longitude=' + o.toFixed(3);
    const w = await getJson(WX + ll(lat, lon));
    // Inland (canals, lakes): nearest sea cell > INLAND_KM away -> wind + weather only.
    let m = null, nudge = null;
    const t = await getJson(MAR + ll(lat, lon));
    const dist = km(lat, lon, t.latitude, t.longitude);
    if (dist <= INLAND_KM && t.hourly.wave_height.slice(0, 24).some(v => v != null)) { m = t; nudge = dist > 3 ? dist.toFixed(1) + ' km' : null; }
    const inland = !m;
    const now = Date.now() / 1000, wh = w.hourly;
    const mh = m ? m.hourly : {time: wh.time, wave_height: [], wave_period: [], wave_direction: [], swell_wave_height: [],
      swell_wave_period: [], swell_wave_direction: [], sea_level_height_msl: [], sea_surface_temperature: []};
    const idx = ts => Math.max(0, ts.findIndex(t => t > now - 3600)); // current hour
    const i = idx(wh.time), j = idx(mh.time);
    // Midnight today (local) = first hourly timestamp; curve covers 00..24
    const dayStart = mh.time[0];

    let tide = null;
    if (ukhoKey && !inland) { try { tide = await ukhoTides(lat, lon, ukhoKey); } catch (e) { console.warn('UKHO', e); } }
    if (!tide) tide = inland ? {src: 'none', station: '', datum: '', events: []} : {src: 'model', station: '', datum: 'MSL', events: modelTides(mh.time, mh.sea_level_height_msl)};
    tide.events = tide.events.filter(e => e.t > now - 7*3600).slice(0, 10);

    const hours = [];
    for (let k = 0; k < 12 && i + k < wh.time.length; k++) {
      const a = i + k, b = j + k;
      hours.push({h: new Date(wh.time[a]*1000).toLocaleString('en-GB', {hour: '2-digit', hour12: false, timeZone: 'Europe/London'}) | 0,
        ws: r1(wh.wind_speed_10m[a]), wg: r1(wh.wind_gusts_10m[a]), wd: wh.wind_direction_10m[a],
        wv: r1(mh.wave_height[b]), wp: r1(mh.wave_period[b]),
        t: r1(wh.temperature_2m[a]), pp: wh.precipitation_probability[a], wc: wh.weather_code[a]});
    }
    const c = w.current, d = w.daily, hhmm = t => new Date(t*1000).toLocaleTimeString('en-GB', {hour: '2-digit', minute: '2-digit', timeZone: 'Europe/London'});
    return {
      at: Math.round(now), lat, lon, inland, marineNudge: nudge, dayStart,
      wind: {kt: r1(c.wind_speed_10m), gust: r1(c.wind_gusts_10m), dir: c.wind_direction_10m, card: card(c.wind_direction_10m)},
      wave: {h: r1(mh.wave_height[j]), p: r1(mh.wave_period[j]), dir: mh.wave_direction[j], card: card(mh.wave_direction[j]),
             swell_h: r1(mh.swell_wave_height[j]), swell_p: r1(mh.swell_wave_period[j]), swell_card: card(mh.swell_wave_direction[j])},
      wx: {t: r1(c.temperature_2m), code: c.weather_code, hi: r1(d.temperature_2m_max[0]), lo: r1(d.temperature_2m_min[0]),
           pp: Math.max(0, ...wh.precipitation_probability.slice(i, i + 12).map(v => v || 0)),
           sea: r1(mh.sea_surface_temperature[j]), rise: hhmm(d.sunrise[0]), set: hhmm(d.sunset[0])},
      tide, curve: mh.sea_level_height_msl.slice(0, 25), hours,
    };
  }
  return {fetchConditions, modelTides, card};
})();

// WMO weather codes → short names (≤ 8 chars, fits the watch)
function wxName(c) {
  if (c == null) return '';
  if (c === 0) return 'CLEAR'; if (c <= 2) return 'P CLOUD'; if (c === 3) return 'CLOUDY';
  if (c <= 48) return 'FOG'; if (c <= 57) return 'DRIZZLE'; if (c <= 67) return 'RAIN';
  if (c <= 77) return 'SNOW'; if (c <= 82) return 'SHOWERS'; if (c <= 86) return 'SNOW';
  return 'THUNDER';
}
