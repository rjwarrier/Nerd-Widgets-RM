-- Run in Rainmeter's actual Lua 5.1 engine via tools/prepare_tests.py.
function Initialize()
    local root=SKIN:GetVariable('Source')
    local M=dofile(root..'Model.lua')
    local count=0
    local function check(value,message) assert(value,message);count=count+1 end
    check(M.battery(128,100,1,0).valid==false,'No-battery flag must never show 100%')
    check(M.battery(255,100,1,-1).status=='Battery unavailable','Unknown flags')
    check(M.battery(8,50,1,3600).charging,'Charging bit')
    check(M.battery(1,81,1,-1).status=='Plugged in','AC is not necessarily charging')
    check(M.battery(1,100,1,-1).status=='Fully charged','Full battery')
    check(M.battery(1,0,0,0).valid,'Measured zero must remain valid')
    check(not M.battery(1,255,0,1).valid,'Invalid percentage')
    check(M.battery(1,50,0,7200).life==7200,'Real Windows estimate')
    check(not M.battery(1,50,0,4294967295).life,'Unknown DWORD lifetime')
    check(not M.battery(1,50,1,7200).life,'Do not reuse discharge estimate on AC')
    check(M.duration(9000)=='2h 30m','Duration formatting')
    local v,u=M.rate(1048576);check(v=='1.0' and u=='MiB/s','Binary network conversion')
    local h={};check(M.append(h,1000,0,60),'History accepts measured zero')
    check(not M.append(h,1001,20,60),'History sample cadence')
    check(not M.append(h,1060,nil,60),'Unavailable is not zero')
    check(M.append(h,1060,10,60),'New sample after 60 sec')
    local clean=M.trim({{t=1,v=10},{t=10000,v=100},{t=10001,v=99},{t=9999,v=200}},10000,1)
    check(#clean==1 and clean[1].t==10000,'Prune old, future, invalid samples')
    local pv,pu=M.ping(14);check(pv=='14' and pu=='ms','Valid ping')
    local pv2,pu2=M.ping(30000);check(pv2=='--' and pu2=='Timeout','Ping timeout')
    local pv3,pu3=M.ping(-1);check(pv3=='--' and pu3=='Timeout','Ping negative')
    check(M.cpuName('Intel(R) Core(TM) i5 CPU'):find('Intel Core i5'),'Clean CPU name')
    check(M.cpuName('')=='Unknown CPU','Empty CPU name')
    local st,sp=M.swap(8589934592,17179869184);check(sp==50 and st:find('8.0 / 16.0 GB'),'Swap format')
    check(M.size('Scale',.1)==.25 and M.size('Scale',.27)==.25 and M.size('Scale',2)==1.5,'Scale clamps to 25-150%');check(M.coreCount('8')==8 and M.coreCount('0')==1 and M.coreCount('64')==32,'Core count clamp')
    check(M.isoWeek({year=2026,yday=310,wday=6})==45,'ISO week, Friday 6 Nov 2026')
    check(M.isoWeek({year=2021,yday=1,wday=6})==53,'1 Jan 2021 belongs to 2020-W53')
    check(M.isoWeek({year=2024,yday=366,wday=3})==1,'31 Dec 2024 belongs to 2025-W01')
    check(M.bcd(9,8) and M.bcd(9,1) and not M.bcd(9,4),'BCD bits')
    check(M.bytes(1610612736)=='1.5 GB' and M.bytes(524288000)=='500 MB','Byte formatting')
    check(M.mmss(1500)=='25:00' and M.mmss(59.6)=='01:00' and M.mmss(-5)=='00:00','Timer format')
    local fm,fs=M.focusNext('work',3);check(fm=='long' and fs==4,'4th session earns the long break')
    fm,fs=M.focusNext('work',0);check(fm=='break' and fs==1,'Short break after work')
    fm,fs=M.focusNext('long',4);check(fm=='work' and fs==4,'Breaks do not count sessions')
    local sample=[[{"current_units":{"temperature_2m":"C"},"current":{"time":"2026-11-07T00:00","interval":900,"temperature_2m":26.9,"apparent_temperature":30.7,"relative_humidity_2m":79,"wind_speed_10m":10.3,"weather_code":61,"is_day":0},"daily_units":{"time":"iso8601"},"daily":{"time":["2026-11-07","2026-11-08","2026-11-09","2026-11-10"],"weather_code":[3,3,51,95],"temperature_2m_max":[27.2,27.2,27.4,27.4],"temperature_2m_min":[26.5,26.5,26.4,26.2],"precipitation_probability_max":[2,8,20,47]}}]]
    local wx=M.weatherParse(sample)
    check(wx and wx.temp==26.9 and wx.humidity==79 and wx.code==61 and not wx.day,'Weather current fields')
    check(wx and #wx.days==4 and wx.days[4].code==95 and wx.days[3].rain==20 and wx.days[2].date=='2026-11-08','Weather daily fields')
    check(M.weatherParse('')==nil and M.weatherParse('{"error":true}')==nil,'Missing weather data')
    check(select(2,M.weatherInfo(61))=='rain' and select(2,M.weatherInfo(0))=='clear' and select(2,M.weatherInfo(96))=='storm','Weather codes')
    check(M.parseDate('2027-01-01 00:00')==os.time({year=2027,month=1,day=1,hour=0,min=0,sec=0}),'Countdown date')
    check(M.parseDate('2026-02-31')==nil and M.parseDate('soon')==nil and M.parseDate('2026-13-01')==nil,'Invalid dates')
    local dd,hh,mm,ss=M.split(90061);check(dd==1 and hh==1 and mm==1 and ss==1,'Countdown split')
    local pr=M.progress(os.time({year=2026,month=1,day=1,hour=12,min=0,sec=0}))
    check(math.abs(pr.day.fraction-.5)<1e-6 and pr.weekday==4,'Day progress, Thursday noon')
    check(math.abs(pr.week.fraction-3.5/7)<1e-6 and math.abs(pr.month.fraction-.5/31)<1e-6,'Week and month progress')
    check(pr.yearDays==365 and pr.monthDays==31 and math.abs(pr.year.fraction-.5/365)<1e-6,'Year progress')
    check(M.progress(os.time({year=2028,month=2,day=10,hour=0})).monthDays==29,'Leap February')
    local ps=M.progress(os.time({year=2026,month=1,day=1,hour=12,min=0,sec=0}),0)
    check(ps.weekday==5 and math.abs(ps.week.fraction-4.5/7)<1e-6,'Sunday-first week progress')
    check(M.weekStart('Sun')==0 and M.weekStart('sunday')==0 and M.weekStart('Mon')==1 and M.weekStart('')==1,'Week start setting')
    check(M.weekColumn(1,0)==0 and M.weekColumn(1,1)==6 and M.weekColumn(2,1)==0,'Week columns')
    local function near(h,expect) return h and math.abs(h-expect)<10/60 end
    -- Kochi, 7 Nov 2026 (IST): about 06:13 / 17:58.
    local kr,ks=M.sunTimes(9.93,76.27,311,5.5)
    check(near(kr,6+13/60) and near(ks,17+58/60),'Kochi sunrise/sunset')
    -- London, 21 Jun (BST): about 04:43 / 21:21.
    local lr,ls=M.sunTimes(51.5074,-0.1278,172,1)
    check(near(lr,4+43/60) and near(ls,21+21/60),'London midsummer')
    check(select(3,M.sunTimes(78.2,15.6,355,1))=='night' and select(3,M.sunTimes(78.2,15.6,172,2))=='day','Polar night and midnight sun')
    -- 8 Apr 2024 18:21 UTC eclipse new moon; half a month later is full.
    local mn=M.moon(1712600460)
    check(mn.illumination<.05 and (mn.age<1.2 or mn.age>M.synodic-1.2),'New moon at the 2024 eclipse')
    local mf=M.moon(1712600460+M.synodic*43200)
    check(mf.illumination>.95 and mf.name=='Full moon','Full moon half a cycle later')
    check(M.moon(1712600460+M.synodic*86400*.25).name=='First quarter','First quarter')
    local geoSample=[[{"results":[{"id":1859146,"name":"Kochi","latitude":33.55,"longitude":133.53333,"country":"Japan","admin1":"Kochi"},{"id":1273874,"name":"Kochi","latitude":9.93988,"longitude":76.26022,"postcodes":["682001","682002"],"country":"India","admin1":"Kerala"},{"id":3,"name":"A Very Long Place Name That Must Fit Somewhere","latitude":-33.9,"longitude":151.2,"country":"Australia","admin1":"New South Wales"},{"id":4,"name":"Four","latitude":1,"longitude":2},{"id":5,"name":"Five","latitude":1,"longitude":2}],"generationtime_ms":0.15}]]
    local places=M.geoParse(geoSample)
    check(#places==4 and places[2].lat==9.93988 and places[2].country=='India' and places[2].admin1=='Kerala' and places[4].country==nil,'Geocoding results')
    check(#M.geoParse('{"generationtime_ms":0.07}')==0 and #M.geoParse('')==0,'No geocoding results')
    check(M.urlEncode('New York, NY')=='New+York%2C+NY' and M.urlEncode('S\195\163o Paulo')=='S%C3%A3o+Paulo','URL encoding')
    local tiles=M.treemap({6,6,4,3,2,0,1},0,0,600,400)
    local area,inBounds,seen=0,true,{}
    for _,t in ipairs(tiles) do
      area=area+t.w*t.h;seen[t.i]=true
      inBounds=inBounds and t.x>=-1e-6 and t.y>=-1e-6 and t.x+t.w<=600+1e-6 and t.y+t.h<=400+1e-6
    end
    check(#tiles==6 and not seen[6] and math.abs(area-240000)<1e-3 and inBounds,'Treemap fills the area, skips zeros')
    check(math.abs(tiles[1].w*tiles[1].h-240000*6/22)<1e-3,'Treemap areas are proportional')
    check(#M.treemap({0,0},0,0,10,10)==0,'Empty treemap')
    local lo,hi=M.levelScale({{v=60},{v=64}});check(lo==57 and hi==67,'Auto scale pads a flat line to 10 points')
    lo,hi=M.levelScale({{v=1},{v=3}});check(lo==0 and hi==10,'Auto scale stays above 0')
    lo,hi=M.levelScale({{v=98},{v=100}});check(lo==90 and hi==100,'Auto scale stays below 100')
    lo,hi=M.levelScale({{v=20},{v=80}});check(lo==18 and hi==82,'Auto scale with headroom')
    lo,hi=M.levelScale({});check(lo==0 and hi==100,'Empty history uses 0-100')
    local function h(rows) local out={} for k,r in ipairs(rows) do out[k]={t=r[1],v=50,c=r[2]} end return out end
    local since,exact=M.onBatterySince(h({{0,2},{60,1},{120,0},{180,0},{240,0}}))
    check(since==120 and exact,'Unplugged at the first on-battery sample')
    since,exact=M.onBatterySince(h({{0,nil},{60,0},{120,0}}))
    check(since==60 and not exact,'Older rows: at least since the first known on-battery sample')
    since,exact=M.onBatterySince(h({{0,2},{60,0},{600,0},{660,0}}))
    check(since==600 and not exact,'A gap makes the time a lower bound')
    check(M.onBatterySince(h({{0,0},{60,2}}))==nil and M.onBatterySince({})==nil,'Not on battery')
    local utf16=('[NerdWidgets\\Battery]\r\nActive=2\r\nWindowX=10\r\n[NerdWidgets\\Clock]\r\nActive=0\r\n[Other\\Skin]\r\nActive=1\r\n'):gsub('.','%0\0')
    local cs=M.configState(utf16)
    check(cs.Battery.active==2 and cs.Battery.placed and cs.Clock.active==0 and not cs.Clock.placed and cs.Skin==nil,'Rainmeter.ini config state')
    local lay=M.flowLayout({{w=300,h=400},{w=300,h=400},{w=300,h=400},{w=800,h=40,wide=true}},1920,1080,16)
    check(lay[1].x==16 and lay[1].y==16 and lay[2].y==432 and lay[3].x==332 and lay[3].y==16,'Column layout')
    check(lay[4].x==16 and lay[4].y==1024,'Wide card along the bottom')
    check(M.batteryRange(25)==30 and M.batteryRange(1000)==1080 and M.batteryRange('x')==360 and M.batteryRange(5000)==1440,'Battery ranges snap')
    local hist={}
    for k=0,30 do hist[#hist+1]={t=k*60,v=50+k*.5} end
    local rates=M.chargeRates(hist)
    check(#rates>0 and math.abs(rates[#rates].v-30)<1e-6 and rates[1].t>=300,'Charge rate, 30 %/h')
    hist[#hist+1]={t=31*60+600,v=70}
    check(M.chargeRates(hist)[#M.chargeRates(hist)].t<31*60+600,'A gap restarts the rate window')
    local cases=0
    -- entry, kind, variant, height
    local entries={{'Battery','Battery','Battery',280},{'Compact','Battery','Compact',168},{'Network','Network','Network',230},
      {'NetworkCompact','Network','Compact',150},{'Vitals','Vitals','Vitals',270},{'VitalsCompact','Vitals','Compact',140},
      {'Clock','Clock','Clock',220},{'ClockCompact','Clock','Compact',120},{'Shortcuts','Shortcuts','Shortcuts',136},
      {'Audio','Audio','Audio',190},{'Spectrum','Spectrum','Spectrum',220},{'Cores','Cores','Cores',260},{'SysInfo','SysInfo','SysInfo',260},
      {'Diagnostics','Diagnostics','Diagnostics',280},{'Calendar','Calendar','Calendar',300},{'CalendarWeek','Calendar','CalendarWeek',160},{'WeatherCompact','Weather','Compact',130},
      {'GPUCompact','GPU','Compact',120},{'CoresRings','Cores','CoresRings',260},{'FocusCompact','Focus','Compact',140},
      {'CountdownCompact','Countdown','Compact',130},{'DiskIODrives','DiskIO','DiskIODrives',200},{'DiagnosticsCompact','Diagnostics','Compact',140},{'Processes','Processes','Processes',330},{'ProcessesMap','Processes','ProcessesMap',330},
      {'DiskIO','DiskIO','DiskIO',300},{'Binary','Binary','Binary',270},{'BinaryCompact','Binary','Compact',210},{'GPU','GPU','GPU',330},
      {'Focus','Focus','Focus',262},{'Countdown','Countdown','Countdown',250},{'Weather','Weather','Weather',330},
      {'Progress','Progress','Progress',270},{'SunMoon','SunMoon','SunMoon',330},{'SunMoonSouth','SunMoon','SunMoon',330},
      {'WeatherSearch','Weather','Weather',330},{'SunMoonSearch','SunMoon','SunMoon',330},
      {'Analog','Analog','Analog',260},{'StatusBar','StatusBar','StatusBar',46},{'Settings','Settings','Settings',642}}
    for _,e in ipairs(entries) do
      local entry,kind,variant,height=e[1],e[2],e[3],e[4]
      for _,theme in ipairs({'Dark','Light','Blacks','Instrument'}) do
       for _,scale in ipairs({.25,.75,1,1.5}) do
        for _,width in ipairs({320,340,500,800}) do
         for _,flags in ipairs({1,8,128,255}) do
          local options={}
          local vars={['@']=root..'..\\',Kind=kind,Variant=variant,Width=tostring(width),Height=height,
            -- Cores: half the flag cases exercise the dense 32-thread heatmap.
            Theme=(theme=='Blacks' or theme=='Instrument') and 'Dark' or theme,
            -- Label/number sizes vary with the flag case: default, the user's 105/70, and both extremes.
            TextScale=({[1]='1',[8]='1.05',[128]='1.5',[255]='0.7'})[flags],NumberScale=({[1]='1',[8]='0.7',[128]='0.5',[255]='1.5'})[flags],Style=(theme=='Blacks' or theme=='Instrument') and theme or 'Expressive',Scale=tostring(scale),Palette=({'Sage','Teal','Rose','Amber','Slate','Blue','Red'})[(width+flags+scale*4)%7+1],CoreCount=flags>=128 and '32' or '8',PingHost='1.1.1.1',
            BatteryRange=({[1]='30',[8]='1440',[128]='360',[255]='60'})[flags],BatteryAutoScale=(flags==1 or flags==128) and '1' or '0',
            WeatherEnabled=flags==255 and '0' or '1',WeatherCity='Test City',
            -- Sun & Moon: unset, tropical, polar (night or midnight sun by date), and the southern hemisphere.
            WeatherLatitude=flags==255 and '0' or entry=='SunMoonSouth' and '-33.87' or flags==128 and '78.2' or '9.93',
            WeatherLongitude=flags==255 and '0' or entry=='SunMoonSouth' and '151.21' or flags==128 and '15.6' or '76.27',
            AnalogSeconds=flags==8 and '0' or '1',WeekStart=(flags==8 or flags==128) and 'Sun' or 'Mon',
            CountdownTitle='Release',CountdownDate=flags==255 and 'soon' or (flags==128 and '2020-01-01 00:00' or '2027-01-01 00:00'),CountdownFrom='2026-11-01 00:00'}
          local readings={BatteryFlags=flags,BatteryPercent=81,BatteryAC=0,BatteryLife=-1,
            CPU=42,CPU0=42,RAM=8*1073741824,RAMTotal=16*1073741824,DiskTotal=512*1073741824,DiskFree=200*1073741824,
            Download=65536,Upload=1024,Uptime=10000,Ping=14,Internet=1,MeasureAudioVol=26,
            SwapUsed=8*1073741824,SwapTotal=16*1073741824,PeakL=.4,PeakR=.4}
          for b=0,15 do readings['Band'..b]=.5 end
          for i=1,5 do readings['ProcCPU'..i]=40/i;readings['ProcRAM'..i]=2^31/i end
          readings.GPULoad=37;readings.GPUShared=245669888;readings.GPUProc1=2.9;readings.GPUProc2=1.3
          readings.DiskRead=2^21;readings.DiskWrite=4096
          readings.FreeC=80*2^30;readings.TotalC=256*2^30;readings.FreeD=10*2^30;readings.TotalD=1024*2^30
          for c=1,32 do readings['CPU'..c]=c*3 end
          local stringReadings={CPUName='Intel Core i5-10210U',OSProd='Windows 11 Pro',OSBits='64',
            OSDisplay='24H2',OSBuild='26300',HostName='TEST-PC',IP='192.168.1.109',Gateway='192.168.1.1',
            Mask='255.255.255.0',DNS='1.1.1.1',MeasureAudioVol='Headphones',
            ProcCPU1='Rainmeter',ProcCPU2='msedge',ProcRAM1='AVeryLongProcessNameThatMustBeTrimmedToFit',ProcRAM2='java',WeatherData=sample,
            GPUName='Intel(R) UHD Graphics',GPUProc1='dwm',GPUProc2='Rainmeter',
            GeoSearch=flags==128 and '{"generationtime_ms":0.07}' or geoSample}
          local mock={}
          function mock:GetVariable(name,default) return vars[name] or default or '' end
          function mock:GetMeasure(name)
            return {GetValue=function() return readings[name] or 0 end,
                    GetStringValue=function() return stringReadings[name] or '' end}
          end
          function mock:Bang(bang,section,key,value)
            if bang=='!SetOption' then options[section]=options[section] or {};options[section][key]=value end
          end
          -- Battery reads a synthetic day of history: a sine-shaped level, charging every
          -- other three hours, a 20-minute gap, and old two-column rows.
          local function fakeHistory()
            local rows,now0={},os.time()
            for k=1440,0,-1 do
              if k<200 or k>220 then
                local c=k<120 and 0 or math.floor(k/180)%2*2-math.floor(k/360)%2
                local v=math.floor(55+40*math.sin(k/90))
                rows[#rows+1]=k>1200 and string.format('%d\t%d',now0-k*60,v) or string.format('%d\t%d\t%d',now0-k*60,v,c)
              end
            end
            local i=0
            return {lines=function() return function() i=i+1;return rows[i] end end,close=function() end}
          end
          local env=setmetatable({SKIN=mock,io={open=function(path,mode)
            if kind=='Battery' and flags~=255 and mode~='w' and tostring(path):match('battery%.tsv$') then return fakeHistory() end
            return nil end}},{__index=_G})
          local script=assert(loadfile(root..'Widget.lua'));setfenv(script,env);script()
          env.Initialize();env.Update();env.Update()
          if kind=='Settings' then env.LoadAll() end
          if entry:match('Search$') then
            -- Location search: searching, then results (or none, or a connection error).
            env.SearchLocation('Kochi');env.Update()
            if flags==255 then env.GeoFailed() else env.GeoDone() end
            env.Update()
          end
          if kind=='Focus' then
            -- Exercise the timer buttons: start, pause, resume, skip, reset.
            env.FocusToggle();env.Update();env.FocusToggle();env.FocusToggle();env.FocusSkip();env.Update();env.FocusReset();env.Update()
          end
          for name,o in pairs(options) do
            if name:match('^Text') and o.Hidden=='0' then
              check(tonumber(o.X)>=0 and tonumber(o.Y)>=0,'Negative position: '..kind)
              check(tonumber(o.W)>0,'Invalid text width: '..kind)
              check(tonumber(o.Y)+tonumber(o.H)<=tonumber(options.Canvas.H)+1,'Text overflows card: '..kind..' '..name)
              check(not o.Text:find('[\128-\255]'),'Unencoded Unicode: '..kind)
            end
          end
          for name in pairs(options) do
            local n=tonumber(name:match('^Text(%d+)$') or name:match('^SliderHit(%d+)$'))
            local limit=name:match('^Text') and 100 or 64
            check(not n or n<=limit,'Meter pool exceeded: '..kind..' '..name)
          end
          local cw,ch=tonumber(options.Canvas.W),tonumber(options.Canvas.H)
          for name,v in pairs(options.Canvas) do
            if name:match('^Shape') and type(v)=='string' then
              local ex,ey,er=v:match('^Ellipse ([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)')
              if ex then check(tonumber(ex)+tonumber(er)<=cw+1 and tonumber(ey)+tonumber(er)<=ch+1 and tonumber(ex)>=0 and tonumber(ey)>=0,'Dot outside card: '..kind..' '..name) end
              local rx,ry,rw,rh=v:match('^Rectangle ([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)')
              if rx then check(tonumber(rx)+tonumber(rw)<=cw+1 and tonumber(ry)+tonumber(rh)<=ch+1,'Shape outside card: '..kind..' '..name) end
            end
          end
          -- Nothing may cut partly into a chip: text, bars, segments, or dots.
          local function meets(a,b) return a[1]<b[1]+b[3]-.5 and b[1]<a[1]+a[3]-.5 and a[2]<b[2]+b[4]-.5 and b[2]<a[2]+a[4]-.5 end
          local function inside(a,b) return a[1]>=b[1]-.5 and a[2]>=b[2]-.5 and a[1]+a[3]<=b[1]+b[3]+.5 and a[2]+a[4]<=b[2]+b[4]+.5 end
          local boxes={}
          for name,o in pairs(options) do
            if name:match('^Text') and o.Hidden=='0' and o.Text~=' ' then
              local plain=o.Text:gsub('%[\\x%x+%]','?')
              local w=math.min(tonumber(o.W),#plain*.6*tonumber(o.FontSize)/.75)
              local x=tonumber(o.X)
              if o.StringAlign=='Center' then x=x-w/2 elseif o.StringAlign=='Right' then x=x-w end
              boxes[#boxes+1]={x,tonumber(o.Y)+2,w,tonumber(o.FontSize)/.75*1.2,name}
            end
          end
          for name,v in pairs(options.Canvas) do
            if name:match('^Shape') and type(v)=='string' then
              local rx,ry,rw,rh=v:match('^Rectangle ([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)')
              if rx then boxes[#boxes+1]={tonumber(rx),tonumber(ry),tonumber(rw),tonumber(rh),name} end
              local ex,ey,er=v:match('^Ellipse ([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)')
              if ex then boxes[#boxes+1]={ex-er,ey-er,2*er,2*er,name} end
            end
          end
          for _,c in ipairs(env.DebugChips or {}) do
            for _,b in ipairs(boxes) do
              if b[3]>0 and b[4]>0 and meets(c,b) then
                check(inside(b,c) or inside(c,b),'Overlaps a chip: '..entry..' '..b[5]..' scale '..scale..' flags '..flags)
              end
            end
          end
          -- Cores Rings shows load as rings; numbers appear only when a ring is big enough.
          if kind=='Cores' and variant~='CoresRings' then
            local n=tonumber(vars.CoreCount)
            local shown=0
            for name,o in pairs(options) do if name:match('^Text') and o.Hidden=='0' then shown=shown+1 end end
            check(shown<=64 and shown>=n,'Cores text pool covers '..n..' threads')
          end
          cases=cases+1
         end
        end
       end
      end
    end
    local message=string.format('PASS: %d assertions; %d renderer combinations',count,cases)
    SKIN:Bang('!Log',message,'Notice')
    local f=assert(io.open(SKIN:GetVariable('Result'),'w'));f:write(message);f:close()
end
