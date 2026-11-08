-- Pure data rules, also exercised independently by tools/ModelTests.lua.
local M = {}
function M.clamp(v, low, high) return math.max(low, math.min(high, v)) end
-- Scale's 26 slider stops + 17 + 21 exactly fill the 64 SliderHit meters.
M.sizes={Scale={min=.25,max=1.5,step=.05},TextScale={min=.7,max=1.5,step=.05},NumberScale={min=.5,max=1.5,step=.05}}
function M.size(key,value)
    local spec=M.sizes[key]
    local n=tonumber(value)
    if not spec or not n or n~=n or n==math.huge or n==-math.huge then return nil end
    n=spec.min+math.floor((M.clamp(n,spec.min,spec.max)-spec.min)/spec.step+.5)*spec.step
    return math.floor(n*100+.5)/100
end
function M.battery(flags, percent, ac, seconds)
    local unknown = flags == 255 or flags < 0
    local present = not unknown and math.floor(flags / 128) % 2 == 0
    local valid = present and percent >= 0 and percent <= 100
    local charging = valid and math.floor(flags / 8) % 2 == 1
    local status = 'On battery'
    if unknown then status = 'Battery unavailable'
    elseif not present then status = 'No battery detected'
    elseif not valid then status = 'Level unavailable'
    elseif charging then status = 'Charging'
    elseif ac == 1 then status = percent >= 100 and 'Fully charged' or 'Plugged in'
    elseif ac ~= 0 then status = 'Power source unknown' end
    local life = valid and ac == 0 and seconds > 0 and seconds < 604800 and seconds or nil
    return {valid=valid, present=present, percent=valid and percent or nil,
        charging=charging, status=status, life=life, ac=ac}
end
function M.duration(seconds)
    local minutes = math.floor(math.max(0, seconds) / 60)
    if minutes < 60 then return minutes .. 'm' end
    return math.floor(minutes / 60) .. 'h ' .. (minutes % 60) .. 'm'
end
function M.rate(bytes)
    bytes = math.max(0, bytes)
    if bytes >= 1048576 then return string.format('%.1f',bytes/1048576), 'MiB/s' end
    if bytes >= 1024 then return string.format('%.0f',bytes/1024), 'KiB/s' end
    return string.format('%.0f',bytes), 'B/s'
end
function M.trim(history, now, hours)
    local result = {}
    for _, p in ipairs(history) do
        if p.t >= now-hours*3600 and p.t <= now and p.v >= 0 and p.v <= 100 then
            result[#result+1] = p
        end
    end
    while #result > 1441 do table.remove(result,1) end
    return result
end
function M.append(history, now, value, interval)
    local last = history[#history]
    if value and (not last or now-last.t >= interval) then
        history[#history+1]={t=now,v=value}
        return true
    end
    return false
end
-- Battery graph ranges in minutes; any other value snaps to the nearest one.
M.batteryRanges = {30, 60, 180, 360, 720, 1080, 1440}
function M.batteryRange(minutes)
    minutes = tonumber(minutes) or 360
    local best = M.batteryRanges[1]
    for _, r in ipairs(M.batteryRanges) do
        if math.abs(r - minutes) < math.abs(best - minutes) then best = r end
    end
    return best
end
-- When the battery was last unplugged, from history rows whose c is 0 (on battery),
-- 1 (charging) or 2 (on AC, not charging). Walks back over unbroken on-battery samples.
-- Returns the time and whether it is exact; false means the history runs out first
-- (a gap, rows from before the power column, or the start of the file), so the real
-- unplug time is at least that long ago. nil when the latest sample is not on battery.
function M.onBatterySince(history)
    local last = history[#history]
    if not last or last.c ~= 0 then return nil end
    local since = last.t
    for i = #history - 1, 1, -1 do
        local p = history[i]
        if history[i + 1].t - p.t > 150 or p.c == nil then return since, false end
        if p.c ~= 0 then return since, true end
        since = p.t
    end
    return since, false
end
-- Auto-scaled level axis: the visible min to max with a little headroom, at least 10
-- points tall, kept within 0-100. Returns low, high.
function M.levelScale(points)
    local lo, hi = math.huge, -math.huge
    for _, p in ipairs(points) do lo = math.min(lo, p.v); hi = math.max(hi, p.v) end
    if lo > hi then return 0, 100 end
    lo, hi = math.floor(lo - 2), math.ceil(hi + 2)
    if hi - lo < 10 then
        local mid = (lo + hi) / 2
        lo, hi = math.floor(mid - 5), math.floor(mid - 5) + 10
    end
    if lo < 0 then hi, lo = hi - lo, 0 end
    if hi > 100 then lo, hi = math.max(0, lo - (hi - 100)), 100 end
    return lo, hi
end
-- Charge rate in % per hour at each sample, over a trailing window (default 10 minutes).
-- Whole-percent readings make short windows jumpy, so a sample needs at least half a
-- window of unbroken history behind it (gaps over 150 s break the history).
function M.chargeRates(history, window)
    window = window or 600
    local out, start = {}, 1
    for i = 1, #history do
        if i > 1 and history[i].t - history[i - 1].t > 150 then start = i end
        local j = start
        while j < i and history[i].t - history[j + 1].t >= window do j = j + 1 end
        local dt = history[i].t - history[j].t
        if dt >= window / 2 then
            out[#out + 1] = {t=history[i].t, v=(history[i].v - history[j].v) / dt * 3600}
        end
    end
    return out
end
function M.ping(ms)
    local n = tonumber(ms)
    if not n or n < 0 or n >= 30000 then return '--', 'Timeout' end
    return string.format('%.0f', n), 'ms'
end
function M.cpuName(raw)
    if not raw or raw == '' then return 'Unknown CPU' end
    local s = tostring(raw):gsub('%(R%)', ''):gsub('%(TM%)', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return s
end
function M.swap(used, total)
    used = math.max(0, tonumber(used) or 0)
    total = math.max(0, tonumber(total) or 0)
    local pct = total > 0 and M.clamp(used / total * 100, 0, 100) or 0
    local text = total > 0 and string.format('%.1f / %.1f GB', used / 1073741824, total / 1073741824) or 'Unavailable'
    return text, pct
end
function M.bytes(n)
    n = math.max(0, tonumber(n) or 0)
    if n >= 1073741824 then return string.format('%.1f GB', n / 1073741824) end
    if n >= 1048576 then return string.format('%.0f MB', n / 1048576) end
    return string.format('%.0f KB', n / 1024)
end
function M.weeksInYear(y)
    local function p(x) return (x + math.floor(x / 4) - math.floor(x / 100) + math.floor(x / 400)) % 7 end
    return (p(y) == 4 or p(y - 1) == 3) and 53 or 52
end
-- ISO 8601 week number from an os.date('*t') table (wday: Sunday=1, yday: Jan 1=1).
function M.isoWeek(t)
    local wday = (t.wday + 5) % 7 + 1
    local week = math.floor((t.yday - wday + 10) / 7)
    if week < 1 then return M.weeksInYear(t.year - 1) end
    if week > M.weeksInYear(t.year) then return 1 end
    return week
end
-- Binary-coded decimal: is bit value `bit` (8/4/2/1) set in decimal digit d?
function M.bcd(d, bit) return math.floor(d / bit) % 2 == 1 end
function M.mmss(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + .5))
    return string.format('%02d:%02d', math.floor(seconds / 60), seconds % 60)
end
-- Pomodoro: a completed work period counts a session; every 4th earns the long break.
function M.focusNext(mode, sessions)
    if mode == 'work' then
        sessions = sessions + 1
        return (sessions % 4 == 0) and 'long' or 'break', sessions
    end
    return 'work', sessions
end
-- 'YYYY-MM-DD' or 'YYYY-MM-DD HH:MM' (local time); nil for anything invalid, e.g. 2026-02-31.
function M.parseDate(s)
    s = tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local y, mo, d, h, mi = s:match('^(%d%d%d%d)%-(%d%d?)%-(%d%d?)[ T](%d%d?):(%d%d)$')
    if not y then y, mo, d = s:match('^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$'); h, mi = 0, 0 end
    if not y then return nil end
    y, mo, d, h, mi = tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi)
    if mo < 1 or mo > 12 or d < 1 or d > 31 or h > 23 or mi > 59 then return nil end
    local t = os.time({year=y, month=mo, day=d, hour=h, min=mi, sec=0})
    local back = t and os.date('*t', t)
    if not back or back.day ~= d or back.month ~= mo then return nil end
    return t
end
-- Whole days, hours, minutes and seconds in a non-negative span.
function M.split(seconds)
    seconds = math.max(0, math.floor(seconds))
    return math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60), seconds % 60
end
-- WMO weather codes as used by Open-Meteo: a label and a drawn icon kind.
function M.weatherInfo(code)
    code = tonumber(code) or -1
    if code == 0 then return 'Clear', 'clear' end
    if code == 1 then return 'Mainly clear', 'partly' end
    if code == 2 then return 'Partly cloudy', 'partly' end
    if code == 3 then return 'Overcast', 'cloud' end
    if code == 45 or code == 48 then return 'Fog', 'fog' end
    if code >= 51 and code <= 57 then return 'Drizzle', 'rain' end
    if code >= 61 and code <= 67 then return 'Rain', 'rain' end
    if code >= 71 and code <= 77 then return 'Snow', 'snow' end
    if code >= 80 and code <= 82 then return 'Rain showers', 'rain' end
    if code == 85 or code == 86 then return 'Snow showers', 'snow' end
    if code >= 95 then return 'Thunderstorm', 'storm' end
    return 'Unknown', 'cloud'
end
-- Pulls the fields the Weather card uses out of an Open-Meteo forecast response.
function M.weatherParse(json)
    json = tostring(json or '')
    local current = json:match('"current":%s*(%b{})')
    local daily = json:match('"daily":%s*(%b{})')
    if not current or not daily then return nil end
    local function field(block, key) return tonumber(block:match('"' .. key .. '":%s*([%-%d%.]+)')) end
    local function list(key, numeric)
        local out = {}
        local body = daily:match('"' .. key .. '":%s*%[(.-)%]') or ''
        for item in body:gmatch('[^,]+') do
            item = item:gsub('"', ''):gsub('^%s+', ''):gsub('%s+$', '')
            out[#out + 1] = numeric and tonumber(item) or item
        end
        return out
    end
    local w = {temp=field(current, 'temperature_2m'), feels=field(current, 'apparent_temperature'),
        humidity=field(current, 'relative_humidity_2m'), wind=field(current, 'wind_speed_10m'),
        code=field(current, 'weather_code'), day=field(current, 'is_day') ~= 0, days={}}
    if not w.temp or not w.code then return nil end
    local dates, codes, highs, lows, rain = list('time'), list('weather_code', true), list('temperature_2m_max', true),
        list('temperature_2m_min', true), list('precipitation_probability_max', true)
    for i = 1, #dates do
        w.days[i] = {date=dates[i], code=codes[i], high=highs[i], low=lows[i], rain=rain[i]}
    end
    return w
end
-- WeekStart setting: 0 for Sunday, 1 for Monday (the default).
function M.weekStart(value)
    return tostring(value or ''):lower():sub(1, 3) == 'sun' and 0 or 1
end
-- Column (0-6) of a weekday in a week that starts on `start`; wday is os.date's 1 = Sunday.
function M.weekColumn(wday, start) return (wday - 1 - (start or 1)) % 7 end
-- Fractions of the current day, week, month and year, with their bounds.
-- Bounds come from os.time on calendar fields, so DST days are 23 or 25 hours long.
function M.progress(now, start)
    local t = os.date('*t', now)
    local function at(y, mo, d) return os.time({year=y, month=mo, day=d, hour=0, min=0, sec=0}) end
    local wd = M.weekColumn(t.wday, start)
    local spans = {
        day={at(t.year, t.month, t.day), at(t.year, t.month, t.day + 1)},
        week={at(t.year, t.month, t.day - wd), at(t.year, t.month, t.day - wd + 7)},
        month={at(t.year, t.month, 1), at(t.year, t.month + 1, 1)},
        year={at(t.year, 1, 1), at(t.year + 1, 1, 1)}}
    local out = {weekday=wd + 1}
    for k, s in pairs(spans) do
        out[k] = {fraction=M.clamp((now - s[1]) / math.max(1, s[2] - s[1]), 0, 1), start=s[1], stop=s[2],
            left=math.max(0, s[2] - now)}
    end
    out.monthDays = math.floor((spans.month[2] - spans.month[1]) / 86400 + .5)
    out.yearDays = math.floor((spans.year[2] - spans.year[1]) / 86400 + .5)
    return out
end
-- Sunrise and sunset in local hours (0-24) for day-of-year yday, at the official zenith.
-- tz is the local UTC offset in hours. Returns nil plus 'night' or 'day' at polar latitudes.
-- Simplified NOAA algorithm (Almanac for Computers, 1990); good to a minute or two.
function M.sunTimes(lat, lon, yday, tz)
    local rad, deg = math.pi / 180, 180 / math.pi
    local function event(rising)
        local lngHour = lon / 15
        local t = yday + ((rising and 6 or 18) - lngHour) / 24
        local m = 0.9856 * t - 3.289
        local l = (m + 1.916 * math.sin(m * rad) + 0.020 * math.sin(2 * m * rad) + 282.634) % 360
        local ra = (math.atan(0.91764 * math.tan(l * rad)) * deg) % 360
        ra = (ra + math.floor(l / 90) * 90 - math.floor(ra / 90) * 90) / 15
        local sinDec = 0.39782 * math.sin(l * rad)
        local cosDec = math.cos(math.asin(sinDec))
        local cosH = (math.cos(90.833 * rad) - sinDec * math.sin(lat * rad)) / (cosDec * math.cos(lat * rad))
        if cosH > 1 then return nil, 'night' end
        if cosH < -1 then return nil, 'day' end
        local h = (rising and 360 - math.acos(cosH) * deg or math.acos(cosH) * deg) / 15
        local ut = (h + ra - 0.06571 * t - 6.622 - lngHour) % 24
        return (ut + tz) % 24
    end
    local rise, polar = event(true)
    if not rise then return nil, nil, polar end
    return rise, event(false)
end
-- Moon phase from the mean synodic month, counted from the 6 Jan 2000 18:14 UTC new moon.
M.synodic = 29.530588853
function M.moon(now)
    local age = ((now - 947182440) / 86400) % M.synodic
    local p = age / M.synodic
    local names = {{.0339, 'New moon'}, {.216, 'Waxing crescent'}, {.284, 'First quarter'}, {.466, 'Waxing gibbous'},
        {.534, 'Full moon'}, {.716, 'Waning gibbous'}, {.784, 'Last quarter'}, {.966, 'Waning crescent'}, {1.01, 'New moon'}}
    local name
    for _, n in ipairs(names) do if p < n[1] then name = n[2]; break end end
    local day = 86400 * M.synodic
    return {age=age, phase=p, illumination=(1 - math.cos(2 * math.pi * p)) / 2, name=name,
        nextFull=now + ((p < .5 and .5 or 1.5) - p) * day, nextNew=now + (1 - p) * day}
end
-- Query-string encoding: spaces as '+', everything but unreserved characters as %XX (UTF-8 bytes).
function M.urlEncode(s)
    return (tostring(s or ''):gsub('[^%w%-%._~ ]', function(c) return string.format('%%%02X', c:byte()) end):gsub(' ', '+'))
end
-- Up to four places from an Open-Meteo geocoding response; an empty list when nothing matched.
function M.geoParse(json)
    local list = tostring(json or ''):match('"results":%s*(%b[])')
    local out = {}
    if not list then return out end
    for obj in list:gmatch('%b{}') do
        local function s(k) return obj:match('"' .. k .. '":%s*"(.-)"') end
        local function n(k) return tonumber(obj:match('"' .. k .. '":%s*([%-%d%.]+)')) end
        local lat, lon = n('latitude'), n('longitude')
        if lat and lon then
            out[#out + 1] = {name=s('name') or '?', lat=lat, lon=lon, country=s('country'), admin1=s('admin1')}
        end
        if #out >= 4 then break end
    end
    return out
end
-- Squarified treemap (Bruls, Huizing & van Wijk): tiles for the positive values, areas in
-- proportion, kept close to square. Returns {i=index into values, x, y, w, h}, largest first.
function M.treemap(values, x, y, w, h)
    local items, total = {}, 0
    for i, v in ipairs(values) do
        if v and v > 0 then items[#items + 1] = {i=i, v=v}; total = total + v end
    end
    local out = {}
    if total <= 0 or w <= 0 or h <= 0 then return out end
    table.sort(items, function(a, b) return a.v > b.v end)
    for _, it in ipairs(items) do it.a = it.v / total * w * h end
    local function worst(row, side)
        local sum, hi, lo = 0, 0, math.huge
        for _, it in ipairs(row) do sum = sum + it.a; hi = math.max(hi, it.a); lo = math.min(lo, it.a) end
        return math.max(side * side * hi / (sum * sum), sum * sum / (side * side * lo))
    end
    local function place(row)
        local sum = 0
        for _, it in ipairs(row) do sum = sum + it.a end
        if w >= h then
            local cw, yy = sum / h, y
            for _, it in ipairs(row) do
                local rh = it.a / cw
                out[#out + 1] = {i=it.i, x=x, y=yy, w=cw, h=rh}; yy = yy + rh
            end
            x, w = x + cw, w - cw
        else
            local rh, xx = sum / w, x
            for _, it in ipairs(row) do
                local cw = it.a / rh
                out[#out + 1] = {i=it.i, x=xx, y=y, w=cw, h=rh}; xx = xx + cw
            end
            y, h = y + rh, h - rh
        end
    end
    local row, k = {}, 1
    while k <= #items do
        local side = math.min(w, h)
        local trial = {unpack(row)}
        trial[#trial + 1] = items[k]
        if #row == 0 or worst(trial, side) <= worst(row, side) then row = trial; k = k + 1
        else place(row); row = {} end
    end
    if #row > 0 then place(row) end
    return out
end
-- NerdWidgets configs listed in Rainmeter.ini (UTF-16; NUL bytes are dropped first):
-- name -> {active=index of the loaded .ini or 0, placed=has a saved window position}.
function M.configState(ini)
    local out = {}
    ini = tostring(ini or ''):gsub('%z', '')
    for name, body in ini:gmatch('%[NerdWidgets\\(%w+)%]([^%[]*)') do
        out[name] = {active=tonumber(body:match('Active=(%d+)')) or 0,
            placed=body:match('WindowX=') ~= nil}
    end
    return out
end
-- Column-by-column placement for cards of {w, h} within an area, with a gap around each.
-- A card wider than a column (the Status Bar) goes along the bottom edge instead.
function M.flowLayout(cards, areaW, areaH, gap)
    gap = gap or 16
    local out, x, y, colW, bottom = {}, gap, gap, 0, areaH
    for i, c in ipairs(cards) do
        if c.wide then
            out[i] = {x=gap, y=math.max(gap, areaH - c.h - gap)}
            bottom = math.min(bottom, out[i].y)
        end
    end
    for i, c in ipairs(cards) do
        if not c.wide then
            if y + c.h > bottom - gap and y > gap then x, y, colW = x + colW + gap, gap, 0 end
            -- Past the right edge, start again from the left rather than leave the screen.
            if x + c.w > areaW then x = gap end
            out[i] = {x=x, y=y}
            y, colW = y + c.h + gap, math.max(colW, c.w)
        end
    end
    return out
end
function M.coreCount(raw)
    local n = tonumber(raw) or 1
    return M.clamp(math.floor(n), 1, 32)
end
-- Now Playing: the helper writes key=value lines (UTF-8) for Windows' current media session.
function M.parseMedia(text)
    local m = {}
    for line in tostring(text or ''):gmatch('[^\r\n]+') do
        local k, v = line:match('^(%w+)=(.*)$')
        if k then m[k] = v end
    end
    for _, k in ipairs({'duration', 'position', 'updated', 'heartbeat'}) do m[k] = tonumber(m[k]) end
    m.playing = m.status == 'Playing'
    m.active = (m.title or '') ~= '' and m.status ~= 'Closed'
    return m
end
-- Position now: the session reports it only on changes, so a playing track runs on from then.
function M.mediaPosition(m, now)
    if not m.duration or m.duration <= 0 or not m.position then return nil end
    local p = m.position
    if m.playing and m.updated and m.updated > 0 then p = p + math.max(0, now - m.updated) end
    return M.clamp(p, 0, m.duration)
end
function M.trackTime(seconds)
    seconds = math.floor(math.max(0, seconds or 0))
    local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
    if h > 0 then return string.format('%d:%02d:%02d', h, m, s) end
    return string.format('%d:%02d', m, s)
end
-- Friendly player name from the session's app id (an exe name or a packaged app id).
function M.mediaSource(id)
    id = tostring(id or '')
    local lower = id:lower()
    local known = {{'spotify', 'Spotify'}, {'zunemusic', 'Media Player'}, {'zunevideo', 'Films & TV'},
        {'msedge', 'Edge'}, {'chrome', 'Chrome'}, {'firefox', 'Firefox'}, {'308046b0af4a39cb', 'Firefox'},
        {'brave', 'Brave'}, {'opera', 'Opera'}, {'vlc', 'VLC'}, {'applemusic', 'Apple Music'}, {'itunes', 'iTunes'},
        {'foobar', 'foobar2000'}, {'musicbee', 'MusicBee'}, {'amazonmusic', 'Amazon Music'}, {'tidal', 'TIDAL'},
        {'deezer', 'Deezer'}, {'youtube', 'YouTube Music'}}
    for _, k in ipairs(known) do if lower:find(k[1], 1, true) then return k[2] end end
    local name = id:match('([^\\/!]+)$') or id
    name = name:gsub('%.exe$', ''):gsub('_.*$', '')
    return name ~= '' and name or 'Media'
end
-- Trims to a character count without cutting a UTF-8 sequence.
function M.utf8Trim(value, maxChars)
    value = tostring(value or '')
    local chars, cut = 0, nil
    for pos in value:gmatch('()[^\128-\191]') do
        chars = chars + 1
        if chars == maxChars then cut = pos end
    end
    if chars <= maxChars then return value end
    return value:sub(1, cut - 1) .. '…'
end
-- Today's network traffic: rates (bytes/s) times the seconds since the last sample, restarting
-- when the date changes. A gap over 5 s (sleep, a closed skin) counts as one second, since the
-- rate says nothing about the time Rainmeter did not see.
function M.addTraffic(day, date, down, up, seconds)
    if day.date ~= date then day.date = date; day.down = 0; day.up = 0 end
    local dt = tonumber(seconds) or 0
    if dt > 5 then dt = 1 elseif dt < 0 then dt = 0 end
    day.down = day.down + math.max(0, tonumber(down) or 0) * dt
    day.up = day.up + math.max(0, tonumber(up) or 0) * dt
    return day
end
-- The saved day: "YYYY-MM-DD<tab>down<tab>up".
function M.parseTraffic(text)
    local date, down, up = tostring(text or ''):match('^(%d%d%d%d%-%d%d%-%d%d)\t([%d%.]+)\t([%d%.]+)')
    if not date then return {} end
    return {date = date, down = tonumber(down), up = tonumber(up)}
end
function M.formatTraffic(day)
    return string.format('%s\t%.0f\t%.0f\n', day.date or '', day.down or 0, day.up or 0)
end

return M
