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
-- Fractions of the current day, week (Monday first), month and year, with their bounds.
-- Bounds come from os.time on calendar fields, so DST days are 23 or 25 hours long.
function M.progress(now)
    local t = os.date('*t', now)
    local function at(y, mo, d) return os.time({year=y, month=mo, day=d, hour=0, min=0, sec=0}) end
    local wd = (t.wday + 5) % 7
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
function M.coreCount(raw)
    local n = tonumber(raw) or 1
    return M.clamp(math.floor(n), 1, 32)
end
return M
