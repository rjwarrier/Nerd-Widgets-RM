-- Native vector/text rendering. No external process, service, or downloaded plugin.
local M, kind, variant, W, H, S, C, shapes, texts, cache, history, down, up, cpu, pingList, reads, writes
local lastShape, lastText, historyFile, sampleTime, sessionStart, sessionLevel, sessionAC
local T,N,baseH,hits,lastHit,drag,look,gpuList
local spectrumPeaks,media={},nil
-- Spectrum idles when silent: updates since the last sound, and whether the meters are slowed.
local spectrumQuiet,spectrumIdle,spectrumLoud,spectrumSkip=0,false,false,0
-- Forward-declared so cards defined earlier in the file can use it.
local button
local palettes = {
    Sage={dark={'181,211,166','219,229,197','35,47,32','18,23,18','30,37,29','232,237,224','167,179,161','68,81,63'},
          light={'67,106,52','83,102,62','220,234,207','246,248,239','233,239,224','29,38,26','95,108,88','204,215,195'}},
    Lavender={dark={'204,190,255','238,190,211','49,42,69','22,20,28','36,32,46','238,232,246','181,172,196','79,69,98'},
          light={'104,79,164','145,73,107','233,221,255','250,247,255','240,233,248','37,29,49','110,98,123','217,205,230'}},
    Blue={dark={'165,203,246','173,216,205','29,46,65','17,23,30','27,37,48','226,236,248','163,181,201','57,79,100'},
          light={'45,97,151','39,111,96','214,232,255','245,249,255','229,238,249','25,37,52','89,109,131','195,213,232'}},
    Peach={dark={'244,188,157','221,203,159','61,42,30','27,21,18','43,33,27','247,233,220','198,173,153','97,73,55'},
          light={'151,84,47','123,105,43','255,224,204','255,248,242','248,233,219','48,33,23','131,103,83','231,206,184'}},
    Teal={dark={'128,216,208','176,204,240','24,58,58','14,22,22','22,34,34','222,240,238','160,186,184','52,82,80'},
          light={'0,106,100','70,96,140','196,236,232','244,251,250','228,242,240','18,38,36','82,108,106','190,214,212'}},
    Rose={dark={'255,178,192','230,196,150','70,32,42','28,18,20','42,28,32','248,228,232','204,166,174','100,62,72'},
          light={'152,64,90','120,90,40','255,217,226','255,247,248','250,232,236','50,26,32','128,90,100','232,200,208'}},
    Amber={dark={'250,206,110','200,214,150','64,48,16','24,20,12','38,32,20','246,238,220','200,186,156','96,80,48'},
          light={'124,88,0','90,100,40','255,228,170','255,250,240','248,238,218','40,32,14','116,102,72','226,210,176'}},
    Slate={dark={'200,208,220','160,190,230','44,48,54','20,22,25','30,33,37','232,234,238','160,166,176','70,76,86'},
          light={'60,68,82','60,100,150','220,224,230','248,249,251','236,238,242','24,26,30','100,106,116','206,210,218'}},
    -- Red: a pure 255,0,0 accent, made for Blacks; deeper tones keep Light readable.
    Red={dark={'255,0,0','255,110,110','64,10,10','24,14,14','38,20,20','246,228,228','200,160,160','96,48,48'},
          light={'190,0,0','150,60,60','255,218,218','255,248,248','250,232,232','48,16,16','128,90,90','232,200,200'}}
}
local paletteOrder={'Sage','Lavender','Blue','Peach','Teal','Rose','Amber','Slate','Red'}
-- Instrument (phone lab look) per palette: accent, secondary, chip, surface, panel, text, muted, border, track.
-- Blue is the exact Pixel sample; the others keep its structure in their own hue.
local instrument={
    Blue={'174,198,252','240,184,180','0,68,147','15,25,61','22,34,72','228,232,250','162,170,204','62,76,118','43,55,95'},
    Sage={'181,222,166','240,200,150','32,92,48','14,34,22','20,44,30','226,240,228','160,186,166','58,90,68','38,64,46'},
    Lavender={'214,190,255','255,182,210','86,52,150','30,18,56','40,26,70','238,230,252','186,170,212','84,66,124','58,42,92'},
    Peach={'255,190,150','250,214,140','140,58,24','48,22,14','60,30,20','252,234,224','214,176,156','112,64,46','82,44,30'},
    Teal={'140,230,220','250,190,170','0,96,96','8,34,38','14,46,50','224,246,244','158,196,194','44,92,96','26,66,70'},
    Rose={'255,182,200','200,200,255','130,30,72','46,12,28','58,20,38','252,230,238','216,168,184','110,52,78','80,34,54'},
    Amber={'255,214,120','255,170,150','110,70,0','36,26,6','48,36,12','252,242,220','214,196,150','100,80,36','70,54,20'},
    Slate={'210,220,236','180,210,255','52,60,74','22,26,32','30,35,43','232,236,242','166,174,188','74,82,98','50,56,68'},
    Red={'255,0,0','255,150,150','120,0,0','40,6,6','54,12,12','252,228,228','214,166,166','110,40,40','80,24,24'}
}
local function var(name, default) return SKIN:GetVariable(name, default or '') end
local function num(name, default) return tonumber(var(name)) or default end
-- Measure handles live as long as the skin, so each is looked up once.
local handles={}
local function handle(name)
    local m=handles[name]
    if m==nil then m=SKIN:GetMeasure(name) or false;handles[name]=m end
    return m
end
local function measure(name)
    local m=handle(name)
    return m and m:GetValue() or 0
end
local function measureString(name, default)
    local m=handle(name)
    return m and m:GetStringValue() or default or ''
end
local function set(section, option, value)
    value=tostring(value)
    local key=section..'/'..option
    if cache[key]~=value then SKIN:Bang('!SetOption',section,option,value);cache[key]=value end
end
local function f(n) return string.format('%.2f',n*S) end
local function unicode(value)
    -- Lua 5.1 strings pass through Windows ANSI in Rainmeter's Bang interface.
    -- Character references keep UTF-8 source labels and icon glyphs lossless.
    return tostring(value):gsub('[\194-\244][\128-\191]+',function(s)
        local first=s:byte(1)
        local code=first % (2^(7-#s))
        for i=2,#s do code=code*64+(s:byte(i)%64) end
        return string.format('[\\x%04X]',code)
    end)
end
local function shape(s) shapes[#shapes+1]=s end
local function rect(x,y,w,h,r,color,stroke)
    shape('Rectangle '..f(x)..','..f(y)..','..f(math.max(0,w))..','..f(h)..','..f(r)..
        ' | Fill Color '..color..' | StrokeWidth '..(stroke and f(1) or '0')..
        (stroke and ' | Stroke Color '..stroke or ''))
end
local function line(x,y,x2,y2,color,width)
    shape('Line '..f(x)..','..f(y)..','..f(x2)..','..f(y2)..' | StrokeWidth '..f(width or 1)..' | Stroke Color '..color)
end
local function circle(x,y,r,color)
    shape('Ellipse '..f(x)..','..f(y)..','..f(r)..' | StrokeWidth 0 | Fill Color '..color)
end
local function path(points,color,width)
    if #points<2 then return end
    local p=f(points[1][1])..','..f(points[1][2])
    for i=2,#points do p=p..' | LineTo '..f(points[i][1])..','..f(points[i][2]) end
    local name='Path'..(#shapes+1)
    set('Canvas',name,p)
    shape('Path '..name..' | Fill Color 0,0,0,0 | StrokeWidth '..f(width or 2)..' | Stroke Color '..color..' | StrokeLineJoin Round | StrokeStartCap Round | StrokeEndCap Round')
end
-- Closed, filled polygon (the lit part of the moon).
local function poly(points,color)
    if #points<3 then return end
    local p=f(points[1][1])..','..f(points[1][2])
    for i=2,#points do p=p..' | LineTo '..f(points[i][1])..','..f(points[i][2]) end
    local name='Path'..(#shapes+1)
    set('Canvas',name,p..' | ClosePath 1')
    shape('Path '..name..' | Fill Color '..color..' | StrokeWidth 0')
end
local function fontSize(value,size,width,role,font)
    size=size*(role=='number' and N or role=='fixed' and 1 or T)
    font=font or var('Font','JetBrains Mono')
    if font=='JetBrains Mono' then
        local plain=tostring(value):gsub('%[\\x%x+%]','?'):gsub('[\194-\244][\128-\191]+','?')
        size=math.min(size,(width-2)/math.max(1,#plain*.6))
    end
    return size
end
local function labelHeight(size) return size*T*1.4+4 end
-- Font sizes are design pixels; widths fit monospace text, while rows reflow below.
local function text(value,x,y,size,color,width,action,align,font,role)
    width=width or W-x-24
    size=fontSize(value,size,width,role,font)
    texts[#texts+1]={Text=unicode(value),X=f(x),Y=f(y),W=f(width),H=f(size*1.4+4),
        FontSize=string.format('%.2f',size*S*.75),FontColor=color or C.text,
        FontFace=font or var('Font','JetBrains Mono'),StringAlign=align or 'Left',
        LeftMouseUpAction=action or '',MouseActionCursor=action and '1' or '0',Hidden='0',
        ToolTipText=action and unicode(value) or '',SolidColor='0,0,0,0'}
end
local function action(code) return '[!CommandMeasure MeasureRenderer "'..code..'"]' end
local settingsAction='[!ActivateConfig "NerdWidgets\\Settings" "Settings.ini"]'
local function header(title,subtitle)
    -- Title and optional subtitle share the row left of the menu dots.
    local titleW=subtitle and math.max(120,#title*7.6*T+8) or W-90
    text(title,24,19,12,C.muted,titleW)
    if subtitle then text(subtitle,W-56,21,10,C.muted,W-80-titleW-8,nil,'Right') end
    text('•••',W-42,15,18,C.muted,30,settingsAction,nil,nil,'fixed')
end
local function chipHeight() return math.max(49,14+labelHeight(10)+labelHeight(15)) end
local function chip(label,value,x,y,w)
    -- Recorded so ModelTests can check nothing else intrudes on a chip.
    DebugChips[#DebugChips+1]={x*S,y*S,w*S,chipHeight()*S}
    rect(x,y,w,chipHeight(),13,C.chip)
    text(label,x+12,y+6,10,C.muted,w-24)
    text(value,x+12,y+6+labelHeight(10),15,C.text,w-24)
end
-- Instrument style: the Android Nerd Widgets 5x7 dot-matrix numerals (NerdStyle.kt DotMatrixGlyphs).
local function g(...) return table.concat({...}) end
local dotFull={['0']='01110100011001110101110011000101110',['1']='00100011000010000100001000010001110',
    ['2']='01110100010000100010001000100011111',['3']='11111000100010000010000011000101110',
    ['4']='00010001100101010010111110001000010',['5']='11111100001111000001000011000101110',
    ['6']='00110010001000011110100011000101110',['7']='11111000010001000100010000100001000',
    ['8']='01110100011000101110100011000101110',['9']='01110100011000101111000010001001100',
    ['.']=g('00000','00000','00000','00000','00000','01100','01100'),
    [':']=g('00000','01100','01100','00000','01100','01100','00000'),
    ['-']=g('00000','00000','00000','11111','00000','00000','00000'),
    ['+']=g('00000','00100','00100','11111','00100','00100','00000')}
-- Units sit smaller on the same baseline, as the phone widgets draw their "%".
local dotSmall={['%']='11000110010001000100010001001100011',
    ['h']=g('10000','10000','10110','11001','10001','10001','10001'),
    ['m']=g('00000','00000','11010','10101','10101','10101','10101'),
    ['d']=g('00001','00001','01101','10011','10001','10011','01101'),
    ['s']=g('00000','00000','01111','10000','01110','00001','11110'),
    ['C']=g('01110','10001','10000','10000','10000','10001','01110'),
    ['F']=g('11111','10000','10000','11110','10000','10000','10000'),
    -- The degree sign, stored under a one-byte key (UTF-8 '\194\176' is mapped to '\1').
    ['\1']=g('01100','10010','10010','01100','00000','00000','00000')}
local function dotSupported(value)
    for ch in tostring(value):gsub('\194\176','\1'):gmatch('.') do
        if ch~=' ' and not dotFull[ch] and not dotSmall[ch] then return false end
    end
    return true
end
-- Draws value in dots inside the same box text() would use; returns the drawn width.
local function dotText(value,x,y,size,color,width,align)
    value=tostring(value):gsub('\194\176','\1')
    -- Digits are 0.8 of the text size tall, as on the phone.
    local h=size*N*.8
    local pitch=h/7
    local natural=0
    for ch in value:gmatch('.') do
        if ch==' ' then natural=natural+3*pitch
        elseif dotFull[ch] then natural=natural+6*pitch
        elseif dotSmall[ch] then natural=natural+6*pitch*.56 end
    end
    natural=math.max(1,natural-pitch)
    local k=math.min(1,(width-4)/natural)
    pitch=pitch*k;h=h*k
    local w=natural*k
    local x0=align=='Right' and x-w or align=='Center' and x-w/2 or x+2
    local y0=y+(size*N*1.4+4-h)/2
    for ch in value:gmatch('.') do
        if ch==' ' then x0=x0+3*pitch else
            local pat,small=dotFull[ch],false
            if not pat then pat,small=dotSmall[ch],true end
            if pat then
                local p=small and pitch*.56 or pitch
                local top=y0+(small and h-7*p or 0)
                for i=1,35 do
                    if pat:sub(i,i)=='1' then
                        circle(x0+((i-1)%5+.5)*p,top+(math.floor((i-1)/5)+.5)*p,p*.46,color)
                    end
                end
                x0=x0+6*p
            end
        end
    end
    return w
end
-- Large readings: dot-matrix in Instrument, the number font elsewhere. Returns the drawn width.
local function hero(value,x,y,size,color,width,act,align,font)
    value=tostring(value)
    if look=='Instrument' and dotSupported(value) then
        local w=dotText(value,x,y,size,color,width,align)
        if act then
            -- An almost transparent box keeps the reading clickable.
            text(' ',x,y,size,color,width,act,align,nil,'number')
            texts[#texts].SolidColor='0,0,0,1';texts[#texts].ToolTipText=''
        end
        return w
    end
    text(value,x,y,size,color,width,act,align,font,'number')
    return #value*.6*fontSize(value,size,width,'number',font)
end
-- Progress bar: a smooth pill, or the phone widgets' row of segments in Instrument.
-- Thin list bars (under 4 px) stay smooth lines there too, as in the phone's app lists.
local function bar(x,y,w,h,fraction,color)
    fraction=M.clamp(fraction or 0,0,1)
    if look=='Instrument' and h>=4 then
        h=math.max(h,6)
        local gap=2
        local n=math.max(4,math.floor((w+gap)/(math.max(8,h*1.4)+gap)))
        local seg=(w-gap*(n-1))/n
        local filled=math.floor(fraction*n+.5)
        if fraction>0 and filled==0 then filled=1 end
        for i=0,n-1 do rect(x+i*(seg+gap),y,seg,h,math.min(2,seg/2),i<filled and color or C.track) end
        return
    end
    rect(x,y,w,h,h/2,C.border)
    if fraction>0 then rect(x,y,w*fraction,h,h/2,color) end
end
-- Graph background: a soft panel, or an outlined, gridded chart in Instrument.
local function graphPanel(x,y,w,h,r)
    if look~='Instrument' then rect(x,y,w,h,r,C.panel) return end
    rect(x,y,w,h,math.min(r,8),C.panel,C.border)
    local cols=math.max(4,math.floor(w/28))
    for i=1,cols-1 do line(x+w*i/cols,y+1,x+w*i/cols,y+h-1,C.grid,1) end
    local rows=h>60 and 4 or 2
    for i=1,rows-1 do line(x+1,y+h*i/rows,x+w-1,y+h*i/rows,C.grid,1) end
end
local function ring(cx,cy,r,p,color)
    local points={}
    for i=0,64 do local a=-math.pi/2+i/64*2*math.pi;points[#points+1]={cx+math.cos(a)*r,cy+math.sin(a)*r} end
    path(points,C.border,7)
    if p>0 then
        points={}
        local steps=math.max(2,math.ceil(64*p/100))
        for i=0,steps do local a=-math.pi/2+i/steps*2*math.pi*M.clamp(p,0,100)/100;points[#points+1]={cx+math.cos(a)*r,cy+math.sin(a)*r} end
        path(points,color,7)
    end
end
local function persist()
    local file=io.open(historyFile..'.tmp','w')
    if not file then return end
    -- Columns: time, level, power (0 on battery, 1 charging, 2 on AC not charging).
    for _,p in ipairs(history) do file:write(p.t,'\t',p.v,'\t',p.c or 0,'\n') end
    file:close()
    -- Same skin owns the history file; variants in one config cannot run together.
    os.remove(historyFile)
    os.rename(historyFile..'.tmp',historyFile)
end
function SetBatteryRange(minutes)
    minutes=M.batteryRange(minutes)
    SKIN:Bang('!SetVariable','BatteryRange',tostring(minutes))
    SKIN:Bang('!WriteKeyValue','Variables','BatteryRange',tostring(minutes),var('@')..'Settings.inc')
    SKIN:Bang('!UpdateMeasure','MeasureRenderer')
    SKIN:Bang('!UpdateMeterGroup','NerdWidgetsDrawing')
    SKIN:Bang('!Redraw')
end
-- Clicking the graph switches the level axis between 0-100% and the visible range.
function ToggleBatteryScale()
    local v=num('BatteryAutoScale',0)==1 and '0' or '1'
    SKIN:Bang('!SetVariable','BatteryAutoScale',v)
    SKIN:Bang('!WriteKeyValue','Variables','BatteryAutoScale',v,var('@')..'Settings.inc')
    SKIN:Bang('!UpdateMeasure','MeasureRenderer')
    SKIN:Bang('!UpdateMeterGroup','NerdWidgetsDrawing')
    SKIN:Bang('!Redraw')
end
local rangeLabels={[30]='30M',[60]='1H',[180]='3H',[360]='6H',[720]='12H',[1080]='18H',[1440]='24H'}
-- A mains plug, prongs up, centred on cx,cy and size tall.
local function plug(cx,cy,size,color)
    local u=size/14
    line(cx-2.5*u,cy-7*u,cx-2.5*u,cy-3*u,color,1.8*u)
    line(cx+2.5*u,cy-7*u,cx+2.5*u,cy-3*u,color,1.8*u)
    rect(cx-5*u,cy-3.5*u,10*u,6*u,2*u,color)
    line(cx,cy+2.5*u,cx,cy+7*u,color,1.8*u)
end
local function battery(now)
    local b=M.battery(measure('BatteryFlags'),measure('BatteryPercent'),measure('BatteryAC'),measure('BatteryLife'))
    -- A full day is always kept, so any range can be shown at once.
    history=M.trim(history,now,24)
    if b.valid and M.append(history,now,b.percent,60) then
        history[#history].c=b.charging and 1 or b.ac==1 and 2 or 0
        persist()
    end
    if not b.valid then sessionStart=nil;sessionLevel=nil;sessionAC=nil
    elseif sessionAC~=b.ac then sessionAC=b.ac;sessionStart=now;sessionLevel=b.percent end
    -- Time on battery since the last unplug, kept across refreshes by the history file.
    local unplugged
    if b.valid and b.ac==0 then
        local since,exact=M.onBatterySince(history)
        if since then unplugged=M.duration(now-since)..(exact and '' or '+')
        elseif history[#history] and history[#history].c then unplugged='Just now'
        elseif sessionStart then unplugged=M.duration(now-sessionStart)..'+' end
    end
    local compact=variant=='Compact'
    local reading=b.valid and string.format('%.0f%%',b.percent) or '--'
    local numberFont=var('NumberFont','JetBrains Mono')
    if compact then
        local top=44
        local chipX=W-137
        local numberWidth=chipX-34
        local effective=fontSize(reading,58,numberWidth,'number',numberFont)
        local statusY=math.max(top+effective*1.4+6,57+chipHeight()+10)
        H=statusY+labelHeight(12)+22
        header('BATTERY')
        hero(reading,22,top,58,C.accent,numberWidth,'["ms-settings:batterysaver"]',nil,numberFont)
        if unplugged then chip('ON BATTERY',unplugged,chipX,57,113)
        else chip('SOURCE',b.ac==1 and 'Plugged in' or b.ac==0 and 'Battery' or 'Unknown',chipX,57,113) end
        circle(29,statusY+10*T,3,b.valid and C.accent or C.muted)
        text(b.status,39,statusY,12,C.muted,W-64)
        return
    end
    -- Full card: the status sits in the header, so the reading, chips and graph stack tightly.
    local range=M.batteryRange(num('BatteryRange',num('HistoryHours',6)*60))
    local span=range*60
    local top=44
    -- Below 440 px (the standard 340 card) the two chips stack in a column right of the reading.
    local narrow=W<440
    local chipX=narrow and W-24-math.min(140,math.floor((W-48)*.45)) or math.max(218,W-258)
    local numberWidth=chipX-34
    local effective=fontSize(reading,56,numberWidth,'number',numberFont)
    header('BATTERY',string.upper(b.status))
    hero(reading,22,top,56,C.accent,numberWidth,'["ms-settings:batterysaver"]',nil,numberFont)
    local cw=narrow and W-24-chipX or (W-chipX-32)/2
    local source=b.charging and 'Charging' or b.ac==1 and 'AC power' or b.ac==0 and 'Battery' or 'Unknown'
    local below
    -- Windows gives no estimate on AC, so the time-left chip only appears when there is one.
    local life=b.life and M.duration(b.life)
    if narrow then
        -- One chip at most; the power source is a plain line under it, or beside the reading alone.
        local lineY=top+effective*1.4/2-labelHeight(11)/2
        if life then
            chip('EST. LEFT',life,chipX,50,cw)
            lineY=50+chipHeight()+6
        end
        if b.ac==1 then
            -- On AC the header already names the state; a plug icon says the rest.
            local size=life and 16 or 24
            local cy=life and lineY+labelHeight(11)/2 or top+effective*1.4/2
            plug(chipX+size/2,cy,size,C.accent)
            text(' ',chipX,cy-size/2,10,C.muted,size+4)
            texts[#texts].H=f(size);texts[#texts].SolidColor='0,0,0,1'
            texts[#texts].ToolTipText=source
            below=math.max(lineY+labelHeight(11),cy+size/2)
        else
            circle(chipX+5,lineY+labelHeight(11)/2,3,C.muted)
            text(unplugged and 'On battery '..unplugged or source,chipX+14,lineY,11,C.muted,cw-14)
            below=lineY+labelHeight(11)
        end
    else
        if unplugged then chip('ON BATTERY',unplugged,chipX,50,cw)
        else chip('POWER',source,chipX,50,cw) end
        if life then chip('EST. LEFT',life,chipX+cw+8,50,cw) end
        below=50+chipHeight()
    end
    local gx,gy,gw,gh=24,math.max(top+effective*1.4,below)+10,W-48,74
    graphPanel(gx,gy,gw,gh,12)
    local px,py,pw,ph=gx+10,gy+10,gw-20,gh-20
    local t0=now-span
    local function X(t) return px+pw*M.clamp((t-t0)/span,0,1) end
    local visible={}
    for _,p in ipairs(history) do if p.t>=t0-60 then visible[#visible+1]=p end end
    -- Charging sessions: shaded bands behind the lines.
    local bandStart
    for i,p in ipairs(visible) do
        local charging=p.c==1
        if charging and not bandStart then bandStart=p.t end
        local nextP=visible[i+1]
        local ends=bandStart and (not nextP or nextP.c~=1 or nextP.t-p.t>150)
        if ends then
            local x1,x2=X(bandStart),X(math.min(now,p.t+60))
            if x2-x1>=1 then rect(x1,py,x2-x1,ph,2,C.accent..',45') end
            bandStart=nil
        end
    end
    local auto=num('BatteryAutoScale',0)==1
    local lo,hi=0,100
    if auto then lo,hi=M.levelScale(visible) end
    local function LY(v) return py+ph*(1-M.clamp((v-lo)/(hi-lo),0,1)) end
    for _,v in ipairs({lo,(lo+hi)/2,hi}) do line(px,LY(v),px+pw,LY(v),C.border..',90',1) end
    if auto then
        -- Axis bounds in the left corners, so the zoomed scale is never mistaken for 0-100%.
        text(string.format('%d%%',hi),gx+4,gy+1,8,C.accent,40)
        text(string.format('%d%%',lo),gx+4,gy+gh-labelHeight(8)-1,8,C.accent,40)
    end
    -- Long ranges hold up to 1,440 samples; draw about one point per two pixels.
    local step=math.max(1,math.ceil(#visible/math.max(1,pw/2)))
    local function plot(list,Y,color,width)
        local segment,last={},nil
        for i,p in ipairs(list) do
            if last and p.t-last>150 then path(segment,color,width);segment={} end
            if i%step==0 or i==#list or (list[i+1] and list[i+1].t-p.t>150) or (last and p.t-last>150) then
                segment[#segment+1]={X(p.t),Y(p.v)}
            end
            last=p.t
        end
        path(segment,color,width)
    end
    -- Charge rate (%/h) on its own symmetric scale around a mid zero line.
    local rates=M.chargeRates(visible)
    local scale=20
    for _,r in ipairs(rates) do scale=math.max(scale,math.ceil(math.abs(r.v)/10)*10) end
    if #rates>1 then
        line(px,py+ph/2,px+pw,py+ph/2,C.secondary..',70',1)
        plot(rates,function(v) return py+ph*(.5-M.clamp(v/scale,-1,1)/2) end,C.secondary,1.6)
        text(string.format('±%d%%/H',scale),px+pw,gy+2,8,C.secondary,70,nil,'Right')
    end
    plot(visible,LY,C.accent,2.2)
    if #visible>0 then
        local p=visible[#visible]
        circle(X(p.t),LY(p.v),3,C.accent)
    end
    if #visible<2 then
        text(b.valid and 'Collecting history · one sample / minute' or 'History starts when a battery is available',
            gx+12,gy+gh/2-labelHeight(11)/2,11,C.muted,gw-24)
    end
    -- The whole graph is the scale toggle: an almost transparent box above it.
    text(' ',gx,gy,10,C.muted,gw,action('ToggleBatteryScale()'))
    texts[#texts].H=f(gh);texts[#texts].SolidColor='0,0,0,1'
    texts[#texts].ToolTipText=auto and 'Click for a 0-100% scale' or 'Click to zoom the scale to the data'
    -- Range buttons.
    local rangeY=gy+gh+8
    local colW=(W-48)/#M.batteryRanges
    local pillH=labelHeight(10)+4
    for i,r in ipairs(M.batteryRanges) do
        local x=24+(i-1)*colW
        if r==range then rect(x+2,rangeY,colW-4,pillH,pillH/2,C.chip) end
        text(rangeLabels[r],x+colW/2,rangeY+2,10,r==range and C.accent or C.muted,colW-6,action('SetBatteryRange('..r..')'),'Center')
    end
    local footerY=rangeY+pillH+8
    -- Legend, right-aligned: a colored swatch before each muted label, evenly spaced.
    local midY=footerY+labelHeight(10)/2
    local x=W-24
    for i=3,1,-1 do
        local label=({'LEVEL','%/H','CHARGING'})[i]
        local lw=#label*.6*10*T+2
        text(label,x,footerY,10,C.muted,lw+2,nil,'Right')
        x=x-lw-14
        if i==3 then rect(x,midY-4,9,9,2,C.accent..',90')
        else line(x,midY,x+10,midY,i==1 and C.accent or C.secondary,i==1 and 2.2 or 1.6) end
        x=x-12
    end
    -- Session change since the power source last changed, in what is left on the left.
    local delta=b.valid and sessionLevel and string.format('%+.0f%%',b.percent-sessionLevel) or '--'
    text(sessionStart and delta..' in '..M.duration(now-sessionStart) or 'No readings yet',24,footerY,10,C.muted,math.max(40,x-24))
    H=footerY+labelHeight(10)+12
end
local function series(values,value,now)
    if values[#values] and values[#values].t==now then return end
    values[#values+1]={t=now,v=value}
    while #values>0 and values[1].t<now-60 do table.remove(values,1) end
end
local function spark(values,x,y,w,h,color,maxValue,now)
    local points={}
    for _,p in ipairs(values) do
        if #points>0 and p.t-points[#points].t>3 then
            path(points,color,2);points={}
        end
        local point={x+w*(p.t-(now-60))/60,y+h*(1-M.clamp(p.v/maxValue,0,1))};point.t=p.t
        points[#points+1]=point
    end
    path(points,color,2)
end
-- Two live byte rates with a shared-scale 60-second graph (Network, Disk I/O).
-- Returns the y just below its footer line.
local function ratePair(title,labelA,labelB,a,b,listA,listB,now,footer)
    series(listA,a,now);series(listB,b,now)
    local half=(W-56)/2
    local av,au=M.rate(a);local bv,bu=M.rate(b)
    local nf=var('NumberFont','JetBrains Mono')
    -- Reserve a stable number row even as the number of digits changes.
    local numberY=54+labelHeight(10)+4
    local unitsY=numberY+44*N*1.4+6
    local graphY=unitsY+labelHeight(11)+10
    local footerY=graphY+54
    header(title)
    text(labelA,24,54,10,C.muted,half)
    text(labelB,W/2+8,54,10,C.muted,half)
    hero(av,22,numberY,44,C.accent,half,nil,nil,nf)
    hero(bv,W/2+6,numberY,44,C.secondary,half,nil,nil,nf)
    text(au,24,unitsY,11,C.muted,half);text(bu,W/2+8,unitsY,11,C.muted,half)
    graphPanel(24,graphY,W-48,42,11)
    local peak=1024
    for _,list in ipairs({listA,listB}) do for _,p in ipairs(list) do peak=math.max(peak,p.v) end end
    spark(listA,32,graphY+7,W-64,28,C.accent,peak,now)
    spark(listB,32,graphY+7,W-64,28,C.secondary,peak,now)
    text(footer,24,footerY,10,C.muted,W-164)
    text('AUTO SCALE',W-24,footerY,10,C.muted,110,nil,'Right')
    return footerY+labelHeight(10)
end
-- Today's traffic, counted while the Network card runs and kept in Data\network-today.tsv
-- (saved every minute and on close, so a refresh or restart keeps the day's total).
local traffic,trafficLast,trafficSaved={},nil,0
local function trafficPath() return var('@')..'Data\\network-today.tsv' end
function SaveTraffic()
    if not traffic.date then return end
    local path=trafficPath()
    local file=io.open(path..'.tmp','w')
    if not file then return end
    file:write(M.formatTraffic(traffic));file:close()
    os.remove(path);os.rename(path..'.tmp',path)
end
local function countTraffic(now,a,b)
    local date=os.date('%Y-%m-%d',now)
    local newDay=traffic.date~=nil and traffic.date~=date
    M.addTraffic(traffic,date,a,b,trafficLast and now-trafficLast)
    trafficLast=now
    if newDay or now-trafficSaved>=60 then trafficSaved=now;SaveTraffic() end
end
-- Compact strip: both rates on one row over a short shared graph.
local function networkCompact(now)
    local a,b=measure('Download'),measure('Upload')
    series(down,a,now);series(up,b,now)
    countTraffic(now,a,b)
    local nf=var('NumberFont','JetBrains Mono')
    local half=(W-56)/2
    header('NETWORK','TODAY '..M.bytes(traffic.down+traffic.up))
    local y=46
    for i,v in ipairs({{'↓',a,C.accent,24},{'↑',b,C.secondary,W/2+4}}) do
        local value,unit=M.rate(v[2])
        text(v[1],v[4],y+(28*N*1.4-labelHeight(14))/2,14,v[3],20,nil,nil,nil,'fixed')
        local numberW=half-24-64
        local drawn=hero(value,v[4]+20,y,28,C.text,numberW,nil,nil,nf)
        local effective=fontSize(value,28,numberW,'number',nf)
        text(unit,math.min(v[4]+22+drawn+6,v[4]+half-62),y+effective*1.4-labelHeight(10)-3,10,C.muted,62)
    end
    local graphY=y+28*N*1.4+8
    graphPanel(24,graphY,W-48,28,9)
    local peak=1024
    for _,list in ipairs({down,up}) do for _,p in ipairs(list) do peak=math.max(peak,p.v) end end
    spark(down,30,graphY+5,W-60,18,C.accent,peak,now)
    spark(up,30,graphY+5,W-60,18,C.secondary,peak,now)
    H=graphY+28+14
end
local function network(now)
    if variant=='Compact' then networkCompact(now) return end
    local a,b=measure('Download'),measure('Upload')
    countTraffic(now,a,b)
    local y=ratePair('NETWORK PULSE','↓ DOWNLOAD','↑ UPLOAD',a,b,down,up,now,'LAST 60 SECONDS')
    -- Today: the total on the left, then download and upload, on one soft row.
    local rowY=y+8
    local rowH=labelHeight(13)+10
    rect(24,rowY,W-48,rowH,12,C.chip)
    local function middle(size) return rowY+(rowH-labelHeight(size))/2 end
    local inner=W-72
    text('TODAY',36,middle(10),10,C.muted,52)
    text(M.bytes(traffic.down+traffic.up),90,middle(13),13,C.text,inner*.5-56)
    text('↓ '..M.bytes(traffic.down),36+inner*.5,middle(11),11,C.accent,inner*.25)
    text('↑ '..M.bytes(traffic.up),W-36,middle(11),11,C.secondary,inner*.25,nil,'Right')
    H=rowY+rowH+14
end
local function diskio(now)
    local drivesOnly=variant=='DiskIODrives'
    local y
    if drivesOnly then
        -- Disk I/O Drives: every fixed drive's space, no throughput graph.
        header('DRIVES')
        y=50
    else
        y=ratePair('DISK I/O','READ','WRITE',math.max(0,measure('DiskRead')),math.max(0,measure('DiskWrite')),
            reads,writes,now,'ALL DISKS · 60 SECONDS')+14
    end
    local shown=0
    for letter in ('CDEFGHIJ'):gmatch('.') do
        local total=measure('Total'..letter);local free=measure('Free'..letter)
        if total>0 and shown<(drivesOnly and 8 or 4) then
            shown=shown+1
            local used=M.clamp(1-free/total,0,1)
            text(letter..':'..(drivesOnly and string.format(' %.0f%%',used*100) or ''),24,y,11,C.text,drivesOnly and 90 or 40)
            text(string.format('%s free of %s',M.bytes(free),M.bytes(total)),W-24,y,11,C.muted,W-(drivesOnly and 140 or 96),nil,'Right')
            y=y+labelHeight(11)+2
            -- Nearly full drives switch to the secondary color as a gentle warning.
            bar(24,y,W-48,4,used,used>.9 and C.secondary or C.accent)
            y=y+14
        end
    end
    if shown==0 then text('No fixed drives detected',24,y,11,C.muted,W-48);y=y+labelHeight(11)+8 end
    H=(y+6)
end
local function ellipsize(value,size,width)
    -- Monospace: trim long names instead of shrinking them to unreadable sizes.
    local maxChars=math.max(4,math.floor((width-2)/(size*T*.6)))
    value=tostring(value)
    return #value>maxChars and value:sub(1,maxChars-1)..'…' or value
end
-- Treemap variant: one tile per top-five process, sized by its share of the five.
local function processMap()
    local cpuTotal=M.clamp(measure('CPU'),0,100)
    local ramTotal=measure('RAMTotal');local ramUsed=measure('RAM')
    header('PROCESS MAP','TOP 5')
    local tones={C.accent,C.secondary,C.accent..',170',C.secondary..',170',C.accent..',105'}
    local inks={C.surface,C.surface,C.surface,C.surface,C.text}
    local y=48
    local mapH=96
    local sections={{'CPU','ProcCPU',string.format('%.0f%% IN USE',cpuTotal),cpuTotal},
        {'MEMORY','ProcRAM',ramTotal>0 and M.bytes(ramUsed)..' IN USE' or '--',ramUsed}}
    for s,sec in ipairs(sections) do
        text(sec[1],24,y,10,C.muted,W/2-24)
        text(sec[3],W-24,y,10,C.muted,W/2-24,nil,'Right')
        y=y+labelHeight(10)+2
        -- The rest of the system is left out: it would dwarf the processes in the map.
        local names,values,labels={},{},{}
        for i=1,5 do
            local v=math.max(0,measure(sec[2]..i))
            names[i]=measureString(sec[2]..i,'')
            if names[i]=='' then v=0 end
            values[i]=v
            labels[i]=s==1 and string.format('%.1f%%',v) or M.bytes(v)
        end
        rect(24,y,W-48,mapH,11,C.panel)
        local tiles=M.treemap(values,24,y,W-48,mapH)
        if #tiles==0 then text('Idle',W/2,y+mapH/2-labelHeight(11)/2,11,C.muted,W-48,nil,'Center') end
        for _,t in ipairs(tiles) do
            local tx,ty,tw,th=t.x+2,t.y+2,math.max(0,t.w-4),math.max(0,t.h-4)
            rect(tx,ty,tw,th,math.min(9,tw/2,th/2),tones[t.i])
            local ink=inks[t.i]
            local nameH,valueH=labelHeight(11),labelHeight(10)
            -- Label what fits: name and value, the name alone, or nothing for slivers.
            if tw>=40 and th>=nameH+4 then
                text(ellipsize(names[t.i],11,tw-12),tx+6,ty+3,11,ink,tw-10)
                if th>=nameH+valueH+6 then text(labels[t.i],tx+6,ty+3+nameH,10,ink,tw-10) end
            end
        end
        y=y+mapH+12
    end
    text('ROLLED UP BY NAME',24,y,10,C.muted,W-144)
    text('Details ↗',W-24,y,11,C.muted,100,'["taskmgr.exe"]','Right')
    H=y+labelHeight(10)+12
end
local function processes()
    if variant=='ProcessesMap' then processMap() return end
    header('TOP PROCESSES')
    local total=measure('RAMTotal')
    local y=50
    local rowH=labelHeight(11)+8
    local sections={{'CPU','ProcCPU',C.accent},{'MEMORY','ProcRAM',C.secondary}}
    for s,sec in ipairs(sections) do
        text(sec[1],24,y,10,C.muted,W-48)
        y=y+labelHeight(10)+2
        for i=1,5 do
            local name=measureString(sec[2]..i,'')
            local v=math.max(0,measure(sec[2]..i))
            local value,fraction
            if s==1 then value=string.format('%.1f%%',v);fraction=v/100
            else value=M.bytes(v);fraction=total>0 and v/total or 0 end
            text(name~='' and ellipsize(name,11,W-140) or '—',24,y,11,name~='' and C.text or C.muted,W-140)
            text(value,W-24,y,11,C.text,88,nil,'Right')
            bar(24,y+labelHeight(11),W-48,3,fraction,sec[3])
            y=y+rowH
        end
        y=y+8
    end
    text('ROLLED UP BY NAME',24,y,10,C.muted,W-144)
    text('Details ↗',W-24,y,11,C.muted,100,'["taskmgr.exe"]','Right')
    H=(y+labelHeight(10)+12)
end
local function gpuCard(now)
    local load=M.clamp(measure('GPULoad'),0,100)
    series(gpuList,load,now)
    local nf=var('NumberFont','JetBrains Mono')
    if variant=='Compact' then
        -- GPU Mini: the load reading beside its 60-second graph.
        local name=measureString('GPUName','')
        name=(name=='' or name=='0') and 'GPU' or M.cpuName(name)
        header('GPU',string.upper(name))
        local top=46
        local rowH=36*N*1.4
        local numberW=96
        hero(string.format('%.0f%%',load),22,top,36,C.accent,numberW,nil,nil,nf)
        local gx=24+numberW+8
        graphPanel(gx,top+2,W-24-gx,rowH-4,9)
        spark(gpuList,gx+6,top+7,W-24-gx-12,rowH-14,C.accent,100,now)
        H=top+rowH+14
        return
    end
    header('GPU MONITOR')
    local top=50
    local numberWidth=110
    local chipX=24+numberWidth+10
    local chipW=W-chipX-24
    hero(string.format('%.0f%%',load),22,top,44,C.accent,numberWidth,nil,nil,nf)
    local name=measureString('GPUName','')
    name=(name=='' or name=='0') and 'Graphics adapter' or M.cpuName(name)
    -- Short names shrink to fit; only very long ones are trimmed.
    chip('ADAPTER',ellipsize(name,10,chipW-24),chipX,top+4,chipW)
    local graphY=math.max(top+44*N*1.4,top+4+chipHeight())+14
    graphPanel(24,graphY,W-48,48,11)
    spark(gpuList,32,graphY+7,W-64,34,C.accent,100,now)
    local y=graphY+58
    text('LOAD · ALL ENGINES · 60 SECONDS',24,y,10,C.muted,W-48)
    y=y+labelHeight(10)+8
    local half=(W-56)/2
    local dedicated=measure('GPUDedicated')
    -- Integrated GPUs have no dedicated memory; they borrow shared system RAM.
    chip('DEDICATED',dedicated>0 and M.bytes(dedicated) or 'None',24,y,half)
    chip('SHARED',M.bytes(measure('GPUShared')),W/2+4,y,half)
    y=y+chipHeight()+12
    text('TOP GPU PROCESSES',24,y,10,C.muted,W-48)
    y=y+labelHeight(10)+2
    for i=1,3 do
        local n=measureString('GPUProc'..i,'')
        local v=math.max(0,measure('GPUProc'..i))
        text(n~='' and ellipsize(n,11,W-140) or '—',24,y,11,n~='' and C.text or C.muted,W-140)
        text(string.format('%.1f%%',v),W-24,y,11,C.text,88,nil,'Right')
        bar(24,y+labelHeight(11),W-48,3,v/100,C.secondary)
        y=y+labelHeight(11)+8
    end
    y=y+4
    text('ROLLED UP BY NAME',24,y,10,C.muted,W-144)
    text('Details ↗',W-24,y,11,C.muted,100,'["taskmgr.exe"]','Right')
    H=(y+labelHeight(10)+12)
end
-- Focus Timer state survives refreshes (palette changes refresh the suite) via Data\focus.tsv.
local focus
local focusNames={work='FOCUS',['break']='SHORT BREAK',long='LONG BREAK'}
local function focusDurations()
    return {work=M.clamp(num('FocusWork',25),1,180)*60,['break']=M.clamp(num('FocusBreak',5),1,60)*60,
        long=M.clamp(num('FocusLongBreak',15),1,120)*60}
end
local function focusSave()
    local file=io.open(var('@')..'Data\\focus.tsv','w')
    if not file then return end
    for _,k in ipairs({'mode','running','ends','left','sessions','day'}) do file:write(k,'\t',tostring(focus[k]),'\n') end
    file:close()
end
local function focusLoad()
    focus={mode='work',running=false,ends=0,sessions=0,day=os.date('%Y-%m-%d')}
    local file=io.open(var('@')..'Data\\focus.tsv','r')
    if file then
        for l in file:lines() do local k,v=l:match('^(%w+)\t(.*)$');if k then focus[k]=v end end
        file:close()
    end
    focus.running=focus.running==true or focus.running=='true'
    focus.ends=tonumber(focus.ends) or 0
    focus.left=tonumber(focus.left)
    focus.sessions=tonumber(focus.sessions) or 0
    if not focusNames[focus.mode] then focus.mode='work' end
end
local function focusRedraw()
    SKIN:Bang('!UpdateMeasure','MeasureRenderer')
    SKIN:Bang('!UpdateMeterGroup','NerdWidgetsDrawing')
    SKIN:Bang('!Redraw')
end
-- completed: the period ran out (counts a work session); otherwise a manual skip.
local function focusAdvance(completed)
    if completed then focus.mode,focus.sessions=M.focusNext(focus.mode,focus.sessions)
    else focus.mode=focus.mode=='work' and 'break' or 'work' end
    focus.running=false;focus.left=nil
    focusSave()
end
function FocusToggle()
    local now=os.time()
    if focus.running then focus.left=math.max(0,focus.ends-now);focus.running=false
    else focus.ends=now+(focus.left or focusDurations()[focus.mode]);focus.left=nil;focus.running=true end
    focusSave();focusRedraw()
end
function FocusReset() focus.running=false;focus.left=nil;focusSave();focusRedraw() end
function FocusSkip() focusAdvance(false);focusRedraw() end
local function focusCard(now)
    if not focus then focusLoad() end
    local today=os.date('%Y-%m-%d')
    if focus.day~=today then focus.day=today;focus.sessions=0;focusSave() end
    if focus.running and now>=focus.ends then
        focusAdvance(true)
        if num('FocusSound',1)==1 then
            local sound=(os.getenv('WINDIR') or 'C:\\Windows')..'\\Media\\Alarm01.wav'
            local probe=io.open(sound,'rb')
            if probe then probe:close();SKIN:Bang('[Play "'..sound..'"]') end
        end
    end
    local d=focusDurations()
    local total=d[focus.mode]
    local left=M.clamp(focus.running and focus.ends-now or focus.left or total,0,total)
    local color=focus.mode=='work' and C.accent or C.secondary
    if variant=='Compact' then
        -- Focus Mini: time left, one Start/Pause button, and a thin progress bar.
        header('FOCUS',focusNames[focus.mode])
        local top=46
        local rowH=36*N*1.4
        local bw=104
        hero(M.mmss(left),22,top,36,color,W-48-bw-8,nil,nil,var('NumberFont','JetBrains Mono'))
        button(focus.running and 'Pause' or left<total and 'Resume' or 'Start',W-24-bw,top+(rowH-34)/2,bw,focus.running,'FocusToggle()')
        local barY=top+math.max(rowH,34)+6
        bar(24,barY,W-48,4,1-left/total,color)
        H=barY+(look=='Instrument' and 6 or 4)+14
        return
    end
    header('FOCUS TIMER',focus.running and 'RUNNING' or left<total and 'PAUSED' or 'READY')
    local r=56
    local cx,cy=32+r,58+r
    ring(cx,cy,r,(1-left/total)*100,color)
    hero(M.mmss(left),cx,cy-28*N*.7-2,28,C.text,r*1.6,nil,'Center',var('NumberFont','JetBrains Mono'))
    local rx=cx+r+24
    local rw=W-24-rx
    text('NOW',rx,56,10,C.muted,rw)
    text(focusNames[focus.mode],rx,56+labelHeight(10),18,color,rw)
    local chipY=56+labelHeight(10)+labelHeight(18)+6
    chip('SESSIONS TODAY',tostring(focus.sessions),rx,chipY,rw)
    local nextMode=focus.mode=='work' and ((focus.sessions+1)%4==0 and 'long' or 'break') or 'work'
    local nextY=chipY+chipHeight()+8
    text('NEXT · '..focusNames[nextMode]..' '..math.floor(d[nextMode]/60)..'M',rx,nextY,10,C.muted,rw)
    local btnY=math.max(cy+r+16,nextY+labelHeight(10)+10)
    local bw=(W-56)/3
    button(focus.running and 'Pause' or left<total and 'Resume' or 'Start',24,btnY,bw,focus.running,'FocusToggle()')
    button('Reset',24+bw+4,btnY,bw,false,'FocusReset()')
    button('Skip',24+(bw+4)*2,btnY,bw,false,'FocusSkip()')
    local footY=btnY+44
    text(string.format('%d / %d / %d MIN · LONG BREAK EVERY 4',d.work/60,d['break']/60,d.long/60),24,footY,10,C.muted,W-48)
    H=(footY+labelHeight(10)+12)
end
-- Countdown: title and target date are edited in place with the InputText measure.
local countdownError
function EditCountdown(which)
    SKIN:Bang('!CommandMeasure','CountdownInput','ExecuteBatch '..(which=='title' and '1' or '2'))
end
function SetCountdown(field,value)
    value=(tostring(value or ''):gsub('^%s+',''):gsub('%s+$',''))
    local file=var('@')..'Settings.inc'
    countdownError=nil
    if field=='title' and value~='' then
        SKIN:Bang('!WriteKeyValue','Variables','CountdownTitle',value,file)
        SKIN:Bang('!SetVariable','CountdownTitle',value)
    elseif field=='date' and M.parseDate(value) then
        -- A new target restarts the progress bar from now.
        local from=os.date('%Y-%m-%d %H:%M')
        SKIN:Bang('!WriteKeyValue','Variables','CountdownDate',value,file)
        SKIN:Bang('!WriteKeyValue','Variables','CountdownFrom',from,file)
        SKIN:Bang('!SetVariable','CountdownDate',value)
        SKIN:Bang('!SetVariable','CountdownFrom',from)
    elseif field=='date' then
        countdownError='Use YYYY-MM-DD or YYYY-MM-DD HH:MM'
    end
    focusRedraw()
end
local function countdown(now)
    -- The input box takes the card's colors.
    set('CountdownInput','SolidColor',C.chip..',255')
    set('CountdownInput','FontColor',C.text)
    local nf=var('NumberFont','JetBrains Mono')
    local title=var('CountdownTitle','New Year')
    local target=M.parseDate(var('CountdownDate',''))
    if variant=='Compact' then
        -- Countdown Mini: the title and days left on one line over a thin bar.
        header('COUNTDOWN')
        local top=46
        local rowH=32*N*1.4
        local dayW=120
        local left=target and target-now
        local days=target and tostring(math.floor(math.abs(left)/86400))..'d' or '--'
        hero(days,W-24,top,32,target and left>0 and C.accent or C.muted,dayW,nil,'Right',nf)
        local tw=W-48-dayW-8
        text(title~='' and title or 'Untitled',24,top+(rowH-labelHeight(13)-labelHeight(10))/2,13,C.text,tw,action("EditCountdown('title')"))
        local sub=countdownError or (target and (left>0 and os.date('%d %b %Y',target) or 'Done') or 'Set a date')
        text(sub,24,top+(rowH-labelHeight(13)-labelHeight(10))/2+labelHeight(13),10,countdownError and C.secondary or C.muted,tw,action("EditCountdown('date')"))
        local barY=top+rowH+6
        local from=M.parseDate(var('CountdownFrom',''))
        bar(24,barY,W-48,4,target and from and target>from and (now-from)/(target-from) or 0,C.accent)
        H=barY+(look=='Instrument' and 6 or 4)+14
        return
    end
    header('COUNTDOWN')
    text(title~='' and title or 'Untitled',24,46,15,C.text,W-48,action("EditCountdown('title')"))
    local y=46+labelHeight(15)+6
    if not target then
        text('No valid date set',24,y,13,C.muted,W-48)
        y=y+labelHeight(13)+8
    else
        local left=target-now
        local done=left<=0
        local d,h,m,s=M.split(math.abs(left))
        hero(tostring(d)..'d',22,y,58,done and C.muted or C.accent,W-44,nil,nil,nf)
        y=y+58*N*1.4+8
        text(done and string.format('%dh %02dm ago · done',h,m) or string.format('%02dh %02dm %02ds',h,m,s),24,y,13,C.text,W-48)
        y=y+labelHeight(13)+10
        local from=M.parseDate(var('CountdownFrom',''))
        if from and target>from then
            local fraction=M.clamp((now-from)/(target-from),0,1)
            bar(24,y,W-48,8,fraction,C.accent)
            y=y+18
            text(string.format('%.0f%% OF THE WAY',fraction*100),24,y,10,C.muted,W-48)
            y=y+labelHeight(10)+6
        end
    end
    local when=target and os.date('%a %d %b %Y · %H:%M',target) or var('CountdownDate','')
    text(countdownError or when,24,y,11,countdownError and C.secondary or C.muted,W-130,action("EditCountdown('date')"))
    text('Change date',W-24,y,11,C.accent,100,action("EditCountdown('date')"),'Right')
    H=y+labelHeight(11)+14
end
-- Weather icons are drawn from shapes, so they follow the palette and need no icon font.
local function weatherIcon(kind,cx,cy,s,day)
    local cloud=C.text
    local function puff(dx,dy,color)
        color=color or cloud
        circle(cx+dx-s*.17,cy+dy+s*.04,s*.18,color)
        circle(cx+dx+s*.04,cy+dy-s*.08,s*.24,color)
        circle(cx+dx+s*.24,cy+dy+s*.07,s*.15,color)
        rect(cx+dx-s*.35,cy+dy+s*.04,s*.74,s*.18,s*.09,color)
    end
    local function sun(dx,dy,r)
        if day then
            for i=0,7 do
                local a=i*math.pi/4
                line(cx+dx+math.cos(a)*r*1.35,cy+dy+math.sin(a)*r*1.35,cx+dx+math.cos(a)*r*1.75,cy+dy+math.sin(a)*r*1.75,C.secondary,math.max(1.2,s*.04))
            end
            circle(cx+dx,cy+dy,r,C.secondary)
        else
            circle(cx+dx,cy+dy,r,C.secondary)
            circle(cx+dx+r*.45,cy+dy-r*.3,r*.85,C.surface)
        end
    end
    if kind=='clear' then sun(0,0,s*.24) return end
    if kind=='partly' then sun(-s*.14,-s*.14,s*.17);puff(s*.06,s*.06) return end
    if kind=='fog' then
        for i=-1,1 do line(cx-s*.36,cy+i*s*.16,cx+s*.36,cy+i*s*.16,cloud,math.max(1.5,s*.06)) end
        return
    end
    puff(0,kind=='cloud' and 0 or -s*.12)
    if kind=='rain' then
        for i=-1,1 do line(cx+i*s*.18,cy+s*.2,cx+i*s*.18-s*.06,cy+s*.38,C.accent,math.max(1.2,s*.05)) end
    elseif kind=='snow' then
        for i=-1,1 do circle(cx+i*s*.18,cy+s*.3,math.max(1.2,s*.045),C.accent) end
    elseif kind=='storm' then
        line(cx+s*.04,cy+s*.14,cx-s*.06,cy+s*.3,C.secondary,math.max(1.4,s*.06))
        line(cx-s*.06,cy+s*.3,cx+s*.06,cy+s*.3,C.secondary,math.max(1.4,s*.06))
        line(cx+s*.06,cy+s*.3,cx-s*.04,cy+s*.46,C.secondary,math.max(1.4,s*.06))
    end
end
-- Location search (Weather, Sun & Moon): Open-Meteo geocoding, free and keyless.
-- Only runs when the user submits a search; picking a place writes Settings.inc.
local geo={state='idle',items={}}
function EditLocation()
    SKIN:Bang('!CommandMeasure','LocationInput','ExecuteBatch 1')
end
function SearchLocation(q)
    q=(tostring(q or ''):gsub('^%s+',''):gsub('%s+$',''))
    if q=='' then return end
    geo={state='searching',query=q,items={}}
    SKIN:Bang('!SetOption','GeoSearch','URL','https://geocoding-api.open-meteo.com/v1/search?count=4&language=en&format=json&name='..M.urlEncode(q))
    SKIN:Bang('!EnableMeasure','GeoSearch')
    SKIN:Bang('!UpdateMeasure','GeoSearch')
    SKIN:Bang('!CommandMeasure','GeoSearch','Update')
    focusRedraw()
end
function GeoDone()
    if geo.state~='searching' then return end
    geo.items=M.geoParse(measureString('GeoSearch',''))
    geo.state=#geo.items>0 and 'results' or 'empty'
    SKIN:Bang('!DisableMeasure','GeoSearch')
    focusRedraw()
end
function GeoFailed()
    if geo.state~='searching' then return end
    geo.state='error'
    SKIN:Bang('!DisableMeasure','GeoSearch')
    focusRedraw()
end
function GeoCancel() geo={state='idle',items={}};focusRedraw() end
local function writeSetting(key,value) SKIN:Bang('!WriteKeyValue','Variables',key,value,var('@')..'Settings.inc') end
function PickLocation(i)
    local place=geo.items[tonumber(i)]
    if not place then return end
    writeSetting('WeatherLatitude',string.format('%.4f',place.lat))
    writeSetting('WeatherLongitude',string.format('%.4f',place.lon))
    writeSetting('WeatherCity',place.name)
    -- Choosing a place on the Weather card is consent for its forecast requests.
    if kind=='Weather' then writeSetting('WeatherEnabled','1') end
    geo={state='idle',items={}}
    SKIN:Bang('!RefreshGroup','NerdWidgets')
end
function EnableWeather()
    writeSetting('WeatherEnabled','1')
    SKIN:Bang('!RefreshGroup','NerdWidgets')
end
-- Draws the search state in place of the card; false when no search is under way.
local function locationPanel(title)
    set('LocationInput','SolidColor',C.chip..',255')
    set('LocationInput','FontColor',C.text)
    if geo.state=='idle' then return false end
    header(title,'LOCATION')
    local y=48
    text('SEARCH',24,y,10,C.muted,W-48)
    y=y+labelHeight(10)
    text(geo.query or '',24,y,15,C.text,W-48,action('EditLocation()'))
    y=y+labelHeight(15)+8
    local message=({searching='Searching…',error='Could not reach Open-Meteo. Try again.',empty='No places found. Try another spelling.'})[geo.state]
    if message then
        text(message,24,y,12,geo.state=='error' and C.secondary or C.muted,W-48)
        y=y+labelHeight(12)+12
    else
        text('CHOOSE A PLACE',24,y,10,C.muted,W-48)
        y=y+labelHeight(10)+4
        local rowH=12+labelHeight(13)+labelHeight(10)
        for i,place in ipairs(geo.items) do
            local pick=action('PickLocation('..i..')')
            local where={}
            if place.admin1 and place.admin1~=place.name then where[#where+1]=place.admin1 end
            if place.country then where[#where+1]=place.country end
            rect(24,y,W-48,rowH,13,C.chip)
            text(place.name,36,y+6,13,C.text,W-72,pick)
            text(string.format('%s%.2f°, %.2f°',#where>0 and table.concat(where,', ')..' · ' or '',place.lat,place.lon),36,y+6+labelHeight(13),10,C.muted,W-72,pick)
            y=y+rowH+6
        end
        y=y+6
    end
    text('New search',24,y,11,C.accent,W/2-24,action('EditLocation()'))
    text('Cancel',W-24,y,11,C.muted,100,action('GeoCancel()'),'Right')
    H=y+labelHeight(11)+12
    return true
end
local weatherJson,weatherUpdated
local function weatherCard(now)
    if locationPanel('WEATHER') then return end
    local city=var('WeatherCity','')
    header('WEATHER',city~='' and string.upper(city) or nil)
    local enabled=num('WeatherEnabled',0)==1
    local raw=enabled and measureString('WeatherData','') or ''
    if raw~='' and raw~=weatherJson then weatherJson=raw;weatherUpdated=now end
    local w=M.weatherParse(weatherJson)
    local footer=function(y)
        text('Change location',24,y,11,C.accent,W-150,action('EditLocation()'))
        if enabled then
            text((weatherUpdated and os.date('%H:%M ',weatherUpdated) or '')..'↻',W-24,y,11,C.muted,110,'[!CommandMeasure WeatherData "Update"]','Right')
        end
        H=y+labelHeight(11)+12
    end
    if not w then
        local lat,lon=tonumber(var('WeatherLatitude','')),tonumber(var('WeatherLongitude',''))
        local located=lat and lon and not (lat==0 and lon==0)
        local y=56
        if enabled then
            text('Waiting for weather data…',24,y,15,C.text,W-48)
            text('Updates every 15 minutes.',24,y+labelHeight(15)+4,11,C.muted,W-48)
        elseif located then
            text('Weather is off',24,y,15,C.text,W-48)
            text('Turn on for '..(city~='' and city or string.format('%.2f°, %.2f°',lat,lon)),24,y+labelHeight(15)+4,12,C.accent,W-48,action('EnableWeather()'))
            text('Sends this location to Open-Meteo every 15 min.',24,y+labelHeight(15)+labelHeight(12)+6,10,C.muted,W-48)
        else
            text('Location not set',24,y,15,C.text,W-48)
            text('Search for your city',24,y+labelHeight(15)+4,12,C.accent,W-48,action('EditLocation()'))
            text('Forecasts from Open-Meteo · free, no account.',24,y+labelHeight(15)+labelHeight(12)+6,10,C.muted,W-48)
        end
        footer(y+labelHeight(15)+labelHeight(12)+labelHeight(11)+18)
        return
    end
    local unit=var('WeatherTempUnit','celsius')=='fahrenheit' and 'F' or 'C'
    local label,kind=M.weatherInfo(w.code)
    local top=46
    if variant=='Compact' then
        -- Weather Mini: icon, temperature, condition and today's range on one row.
        local rowH=40*N*1.4
        local icon=math.min(44,rowH)
        weatherIcon(kind,24+icon/2,top+rowH/2,icon,w.day)
        local tx=24+icon+10
        local numberW=(W-24-tx)*.5
        hero(string.format('%.0f°',w.temp),tx,top,40,C.accent,numberW,nil,nil,var('NumberFont','JetBrains Mono'))
        local today=w.days[1] or {}
        local rx=tx+numberW+6
        local stack=labelHeight(12)+labelHeight(10)
        local sy=top+math.max(0,(rowH-stack)/2)
        text(label,W-24,sy,12,C.text,W-24-rx,nil,'Right')
        text(string.format('H %s° · L %s°',today.high and string.format('%.0f',today.high) or '--',today.low and string.format('%.0f',today.low) or '--'),W-24,sy+labelHeight(12),10,C.muted,W-24-rx,nil,'Right')
        H=top+math.max(rowH,stack)+14
        return
    end
    local iconSize=math.min(78,58*N*1.4)
    hero(string.format('%.0f°%s',w.temp,unit),22,top,58,C.accent,W-60-iconSize,nil,nil,var('NumberFont','JetBrains Mono'))
    weatherIcon(kind,W-24-iconSize/2,top+iconSize/2+4,iconSize,w.day)
    local y=top+math.max(58*N*1.4,iconSize)+8
    text(label,24,y,13,C.text,W-48)
    y=y+labelHeight(13)+8
    local cw=(W-64)/3
    local wind=var('WeatherWindUnit','kmh')=='mph' and 'mph' or 'km/h'
    chip('FEELS LIKE',w.feels and string.format('%.0f°',w.feels) or '--',24,y,cw)
    chip('HUMIDITY',w.humidity and string.format('%.0f%%',w.humidity) or '--',24+cw+8,y,cw)
    chip('WIND',w.wind and string.format('%.0f %s',w.wind,wind) or '--',24+2*(cw+8),y,cw)
    y=y+chipHeight()+12
    -- The next three days (index 1 is today).
    local colW=(W-48)/3
    local icon=26
    for i=2,4 do
        local day=w.days[i]
        if day then
            local cx=24+(i-1.5)*colW
            local yy,mo,dd=tostring(day.date):match('(%d+)%-(%d+)%-(%d+)')
            local name=yy and string.upper(os.date('%a',os.time({year=tonumber(yy),month=tonumber(mo),day=tonumber(dd),hour=12}))) or '--'
            text(name,cx,y,10,C.muted,colW,nil,'Center')
            local _,k=M.weatherInfo(day.code)
            weatherIcon(k,cx,y+labelHeight(10)+icon/2+2,icon,true)
            local ty=y+labelHeight(10)+icon+8
            text(string.format('%s° / %s°',day.high and string.format('%.0f',day.high) or '--',day.low and string.format('%.0f',day.low) or '--'),cx,ty,11,C.text,colW-4,nil,'Center')
            text(day.rain and string.format('RAIN %d%%',day.rain) or '',cx,ty+labelHeight(11),9,C.muted,colW-4,nil,'Center')
        end
    end
    footer(y+labelHeight(10)+icon+8+labelHeight(11)+labelHeight(9)+10)
end
local calOffset=0
function CalendarShift(delta)
    calOffset=(delta==0) and 0 or calOffset+delta
    SKIN:Bang('!UpdateMeasure','MeasureRenderer')
    SKIN:Bang('!UpdateMeterGroup','NerdWidgetsDrawing')
    SKIN:Bang('!Redraw')
end
-- WeekStart is shared by Calendar, Day Progress and Clock; clicking the weekday row flips it.
function ToggleWeekStart()
    SKIN:Bang('!WriteKeyValue','Variables','WeekStart',M.weekStart(var('WeekStart','Mon'))==1 and 'Sun' or 'Mon',var('@')..'Settings.inc')
    SKIN:Bang('!RefreshGroup','NerdWidgets')
end
local dayLetters={'S','M','T','W','T','F','S'}
-- One weekday letter per column, weekends in the secondary color; the row toggles the week start.
local function weekdayRow(y,colW)
    local start=M.weekStart(var('WeekStart','Mon'))
    for col=0,6 do
        local dow=(start+col)%7
        text(dayLetters[dow+1],24+(col+.5)*colW,y,10,(dow==0 or dow==6) and C.secondary or C.muted,colW,action('ToggleWeekStart()'),'Center')
        texts[#texts].ToolTipText=start==1 and 'Start weeks on Sunday' or 'Start weeks on Monday'
    end
    return start
end
-- Calendar Week: this week's seven days in one strip; ‹ › move a week at a time.
local function calendarWeek()
    local now=os.time()
    local start=M.weekStart(var('WeekStart','Mon'))
    local t=os.date('*t',now)
    local first=os.time({year=t.year,month=t.month,day=t.day-M.weekColumn(t.wday,start)+7*calOffset,hour=12})
    local last=os.time({year=t.year,month=t.month,day=t.day-M.weekColumn(t.wday,start)+7*calOffset+6,hour=12})
    header('THIS WEEK')
    local ft=os.date('*t',first)
    local title=os.date('%b',first)==os.date('%b',last) and os.date('%B %Y',first) or os.date('%b',first)..' – '..os.date('%b %Y',last)
    text(string.upper(title),24,46,13,C.text,W-120,calOffset~=0 and action('CalendarShift(0)') or nil)
    text('‹',W-82,38,22,C.accent,30,action('CalendarShift(-1)'),'Center',nil,'fixed')
    text('›',W-44,38,22,C.accent,30,action('CalendarShift(1)'),'Center',nil,'fixed')
    local colW=(W-48)/7
    local labelY=46+labelHeight(13)+8
    weekdayRow(labelY,colW)
    local dayY=labelY+labelHeight(10)+4
    local th=labelHeight(15)
    local instrument=look=='Instrument'
    for col=0,6 do
        local d=os.date('*t',os.time({year=ft.year,month=ft.month,day=ft.day+col,hour=12}))
        local cx=24+(col+.5)*colW
        local weekend=d.wday==1 or d.wday==7
        local color=weekend and C.secondary or C.text
        if d.year==t.year and d.yday==t.yday then
            if instrument then rect(cx-colW/2+3,dayY-3,colW-6,th+2,6,C.text)
            else circle(cx,dayY+th/2-2,math.min(16,colW/2-2),C.accent) end
            color=C.surface
        end
        text(instrument and string.format('%02d',d.day) or tostring(d.day),cx,dayY,15,color,colW,nil,'Center')
    end
    local footerY=dayY+th+12
    text(string.format('ISO WEEK %02d',M.isoWeek(os.date('*t',first+86400*((start==0) and 1 or 0)))),24,footerY,10,C.muted,W-144)
    if calOffset~=0 then text('Today ↺',W-24,footerY,11,C.accent,100,action('CalendarShift(0)'),'Right')
    else text('Date ↗',W-24,footerY,11,C.muted,100,'["ms-settings:dateandtime"]','Right') end
    H=footerY+labelHeight(10)+12
end
local function calendar()
    if variant=='CalendarWeek' then calendarWeek() return end
    local today=os.date('*t')
    local y,mo=today.year,today.month+calOffset
    while mo<1 do mo=mo+12;y=y-1 end
    while mo>12 do mo=mo-12;y=y+1 end
    local first=os.time({year=y,month=mo,day=1,hour=12})
    -- Day 0 of the next month normalizes to this month's last day.
    local days=tonumber(os.date('%d',os.time({year=y,month=mo+1,day=0,hour=12})))
    local start=M.weekStart(var('WeekStart','Mon'))
    local lead=M.weekColumn(tonumber(os.date('%w',first))+1,start)
    header('CALENDAR')
    text(string.upper(os.date('%B %Y',first)),24,46,15,C.text,W-120,calOffset~=0 and action('CalendarShift(0)') or nil)
    text('‹',W-82,40,22,C.accent,30,action('CalendarShift(-1)'),'Center',nil,'fixed')
    text('›',W-44,40,22,C.accent,30,action('CalendarShift(1)'),'Center',nil,'fixed')
    local colW=(W-48)/7
    local labelY=46+labelHeight(15)+8
    weekdayRow(labelY,colW)
    local gridY=labelY+labelHeight(10)+4
    local rowH=math.max(28,labelHeight(12)+8)
    local isToday=calOffset==0
    local instrument=look=='Instrument'
    local th=labelHeight(12)
    for d=1,days do
        local cell=lead+d-1
        local cx=24+(cell%7+.5)*colW
        local cy=gridY+math.floor(cell/7)*rowH
        local dow=(start+cell%7)%7
        local color=(dow==0 or dow==6) and C.secondary or C.text
        if isToday and d==today.day then
            -- Instrument marks today with a light box, as the phone calendar does.
            if instrument then rect(cx-colW/2+3,cy-3,colW-6,th+2,6,C.text)
            else circle(cx,cy+th/2-2,math.min(13,colW/2-2),C.accent) end
            color=C.surface
        end
        text(instrument and string.format('%02d',d) or tostring(d),cx,cy,12,color,colW,nil,'Center')
    end
    local rows=math.ceil((lead+days)/7)
    if instrument then
        -- A fixed six-row grid; neighbouring months' days fill the gaps, dimmed.
        rows=6
        local prevDays=tonumber(os.date('%d',os.time({year=y,month=mo,day=0,hour=12})))
        for cell=0,41 do
            local d=cell<lead and prevDays-lead+cell+1 or cell>=lead+days and cell-lead-days+1 or nil
            if d then
                text(string.format('%02d',d),24+(cell%7+.5)*colW,gridY+math.floor(cell/7)*rowH,12,C.border,colW,nil,'Center')
            end
        end
    end
    local footerY=gridY+rows*rowH+6
    text(string.format('WEEK %02d · DAY %03d',M.isoWeek(today),today.yday),24,footerY,10,C.muted,W-144)
    if calOffset~=0 then text('Today ↺',W-24,footerY,11,C.accent,100,action('CalendarShift(0)'),'Right')
    else text('Date ↗',W-24,footerY,11,C.muted,100,'["ms-settings:dateandtime"]','Right') end
    H=(footerY+labelHeight(10)+12)
end
local function binary(now)
    local t=os.date('*t',now)
    header('BINARY CLOCK','BCD')
    local digits={math.floor(t.hour/10),t.hour%10,math.floor(t.min/10),t.min%10,math.floor(t.sec/10),t.sec%10}
    local bits={2,4,3,4,3,4}
    local gridX,pairGap=50,14
    local colW=(W-24-gridX-2*pairGap)/6
    local rowH=math.max(24,labelHeight(9)+6)
    local y0=56
    local r=math.min(9,colW/2-4,rowH/2-2)
    for row,weight in ipairs({8,4,2,1}) do
        local cy=y0+(row-.5)*rowH
        text(tostring(weight),30,cy-labelHeight(9)/2+2,9,C.muted,20,nil,'Center')
        for i=1,6 do
            if weight<2^bits[i] then
                local cx=gridX+(i-.5)*colW+math.floor((i-1)/2)*pairGap
                local on=M.bcd(digits[i],weight)
                -- Seconds use the secondary color so the ticking pair stands apart.
                circle(cx,cy,r,on and (i>4 and C.secondary or C.accent) or C.border)
            end
        end
    end
    local digitY=y0+4*rowH+4
    for i=1,6 do
        local cx=gridX+(i-.5)*colW+math.floor((i-1)/2)*pairGap
        text(tostring(digits[i]),cx,digitY,13,C.text,colW,nil,'Center',var('NumberFont','JetBrains Mono'))
    end
    for i,l in ipairs({'HH','MM','SS'}) do
        local cx=gridX+(2*i-1)*colW+(i-1)*pairGap
        text(l,cx,digitY+labelHeight(13),9,C.muted,2*colW,nil,'Center')
    end
    if variant=='Compact' then
        -- Dots-only variant: no reading cards below the grid.
        H=(digitY+labelHeight(13)+labelHeight(9)+14)
        return
    end
    local chipW=(W-56)/2
    local chipH=chipHeight()
    local y1=digitY+labelHeight(13)+labelHeight(9)+10
    local y2=y1+chipH+8
    chip('UNIX EPOCH',tostring(now),24,y1,chipW)
    chip('HEX EPOCH',string.format('0x%X',now),W/2+4,y1,chipW)
    chip('UTC',os.date('!%H:%M:%S',now),24,y2,chipW)
    chip('ISO WEEK · DAY',string.format('W%02d · D%03d',M.isoWeek(t),t.yday),W/2+4,y2,chipW)
    H=(y2+chipH+18)
end
local function hm(seconds)
    seconds=math.max(0,seconds)
    return string.format('%dh %02dm',math.floor(seconds/3600),math.floor(seconds%3600/60))
end
local function progressCard(now)
    local p=M.progress(now,M.weekStart(var('WeekStart','Mon')))
    local t=os.date('*t',now)
    local nf=var('NumberFont','JetBrains Mono')
    header('DAY PROGRESS',string.upper(os.date('%a %d %b',now)))
    local top=46
    local chipW=128
    hero(string.format('%.0f%%',p.day.fraction*100),22,top,58,C.accent,W-48-chipW-10,nil,nil,nf)
    chip('LEFT TODAY',hm(p.day.left),W-24-chipW,top+6,chipW)
    local y=math.max(top+58*N*1.4,top+6+chipHeight())+12
    local rows={{'WEEK · DAY '..p.weekday..' OF 7',p.week,C.secondary},
        {string.upper(os.date('%B',now))..' · DAY '..t.day..' OF '..p.monthDays,p.month,C.accent},
        {t.year..' · DAY '..t.yday..' OF '..p.yearDays,p.year,C.secondary}}
    for _,r in ipairs(rows) do
        text(r[1],24,y,10,C.muted,W-48-78)
        text(string.format('%.1f%%',r[2].fraction*100),W-24,y-1,11,C.text,74,nil,'Right')
        y=y+labelHeight(11)
        bar(24,y,W-48,6,r[2].fraction,r[3])
        y=y+(look=='Instrument' and 8 or 6)+10
    end
    y=y+2
    text(string.format('ISO WEEK %02d · %s TO MIDNIGHT',M.isoWeek(t),hm(p.day.left)),24,y,10,C.muted,W-144)
    text('Date ↗',W-24,y,11,C.muted,100,'["ms-settings:dateandtime"]','Right')
    H=y+labelHeight(10)+12
end
-- Sun times are computed locally from the Weather card's coordinates; the moon needs no location.
local function sunMoon(now)
    if locationPanel('SUN & MOON') then return end
    local lat,lon=tonumber(var('WeatherLatitude','')),tonumber(var('WeatherLongitude',''))
    local located=lat and lon and not (lat==0 and lon==0) and math.abs(lat)<=90 and math.abs(lon)<=180
    local city=var('WeatherCity','')
    header('SUN & MOON',located and city~='' and string.upper(city) or nil)
    local y=48
    if located then
        local t=os.date('*t',now)
        local u=os.date('!*t',now);u.isdst=t.isdst
        local tz=os.difftime(now,os.time(u))/3600
        local rise,sunset,polar=M.sunTimes(lat,lon,t.yday,tz)
        local midnight=os.time({year=t.year,month=t.month,day=t.day,hour=0,min=0,sec=0})
        local gx,gy,gw,gh=24,y,W-48,78
        graphPanel(gx,gy,gw,gh,12)
        local x0,x1,base,amp=gx+18,gx+gw-18,gy+gh-14,gh-30
        line(gx+8,base,gx+gw-8,base,C.muted..',140',1)
        local arc={}
        for i=0,40 do local s=i/40;arc[#arc+1]={x0+(x1-x0)*s,base-amp*math.sin(math.pi*s)} end
        path(arc,C.muted..',110',1.6)
        local status
        local values={'--','--',polar=='day' and '24h 00m' or '0h 00m'}
        if rise then
            local r,s=midnight+rise*3600,midnight+sunset*3600
            if s<r then s=s+86400 end
            values={os.date('%H:%M',r),os.date('%H:%M',s),hm(s-r)}
            local frac=(now-r)/(s-r)
            if frac>=0 and frac<=1 then
                local done={}
                for i=0,40 do if i/40<frac then done[#done+1]=arc[i+1] end end
                local sx,sy=x0+(x1-x0)*frac,base-amp*math.sin(math.pi*frac)
                done[#done+1]={sx,sy}
                path(done,C.secondary,2.4)
                circle(sx,sy,7,C.secondary)
                status='Daylight left  '..hm(s-now)
            elseif now<r then status='Sunrise in '..hm(r-now)
            else
                local nextRise=M.sunTimes(lat,lon,t.yday+1,tz)
                status=nextRise and 'Sunrise in '..hm(midnight+86400+nextRise*3600-now) or 'Night'
            end
        else
            status=polar=='day' and 'Midnight sun · up all day' or 'Polar night · down all day'
        end
        y=gy+gh+8
        text(status,24,y,12,C.text,W-48)
        y=y+labelHeight(12)+8
        local cw=(W-64)/3
        for i,l in ipairs({'SUNRISE','SUNSET','DAYLIGHT'}) do chip(l,values[i],24+(i-1)*(cw+8),y,cw) end
        y=y+chipHeight()+14
    else
        text('Location not set',24,y,15,C.text,W-48)
        y=y+labelHeight(15)+2
        text('Search for your city',24,y,12,C.accent,W-48,action('EditLocation()'))
        y=y+labelHeight(12)
        text('Sunrise and sunset are worked out on this PC.',24,y,10,C.muted,W-48)
        y=y+labelHeight(10)+14
    end
    local m=M.moon(now)
    local r=26
    local mx,my=24+r,y+r
    circle(mx,my,r,C.chip)
    if m.illumination>.01 then
        -- Lit limb plus the terminator, an ellipse whose width follows the phase.
        local k=math.cos(2*math.pi*m.phase)
        local side=m.phase<.5 and 1 or -1
        if lat and lat<0 then side=-side end
        local pts={}
        for i=0,24 do local a=-math.pi/2+math.pi*i/24;pts[#pts+1]={mx+side*r*math.cos(a),my+r*math.sin(a)} end
        for i=24,0,-1 do local a=-math.pi/2+math.pi*i/24;pts[#pts+1]={mx+side*r*math.cos(a)*k,my+r*math.sin(a)} end
        poly(pts,C.secondary)
    end
    local tx=mx+r+16
    local tw=W-24-tx
    text(m.name,tx,y,13,C.text,tw)
    text(string.format('%.0f%% LIT · DAY %.1f',m.illumination*100,m.age),tx,y+labelHeight(13),10,C.muted,tw)
    text(string.upper('Full '..os.date('%d %b',m.nextFull)..' · New '..os.date('%d %b',m.nextNew)),tx,y+labelHeight(13)+labelHeight(10),10,C.muted,tw)
    y=y+math.max(2*r,labelHeight(13)+2*labelHeight(10))+12
    text(located and string.format('%.2f°, %.2f°',lat,lon) or 'MEAN SYNODIC MONTH',24,y,10,C.muted,W-160)
    if located then text('Change location',W-24,y,11,C.accent,130,action('EditLocation()'),'Right') end
    H=y+labelHeight(11)+12
end
local function analog(now)
    local t=os.date('*t',now)
    header('ANALOG CLOCK',string.upper(os.date('%a %d %b',now)))
    local seconds=num('AnalogSeconds',1)==1
    local r=math.min(80,(W-48)/2-4)
    local cx,cy=W/2,52+r
    -- The outer ring sweeps once a minute (seconds on) or once an hour.
    ring(cx,cy,r,seconds and t.sec/60*100 or (t.min+t.sec/60)/60*100,C.accent)
    circle(cx,cy,r-10,C.panel)
    local instrument=look=='Instrument'
    for i=0,59 do
        local a=i/60*2*math.pi-math.pi/2
        local ca,sa=math.cos(a),math.sin(a)
        if i%5==0 then
            if instrument then circle(cx+ca*(r-20),cy+sa*(r-20),2.6,C.text)
            else line(cx+ca*(r-27),cy+sa*(r-27),cx+ca*(r-17),cy+sa*(r-17),i%15==0 and C.accent or C.text,i%15==0 and 3 or 2) end
        else circle(cx+ca*(r-20),cy+sa*(r-20),.9,C.muted) end
    end
    local function hand(fraction,length,tail,color,width)
        local a=fraction*2*math.pi-math.pi/2
        path({{cx-math.cos(a)*tail,cy-math.sin(a)*tail},{cx+math.cos(a)*length,cy+math.sin(a)*length}},color,width)
    end
    hand(((t.hour%12)+t.min/60)/12,r*.46,6,C.text,5)
    hand((t.min+t.sec/60)/60,r*.68,8,C.accent,3.4)
    if seconds then hand(t.sec/60,r-24,14,C.secondary,1.6) end
    circle(cx,cy,5,C.accent);circle(cx,cy,2,C.surface)
    local y=cy+r+12
    text(os.date(seconds and '%H:%M:%S' or '%H:%M',now),cx,y,13,C.text,W-48,nil,'Center')
    H=y+labelHeight(13)+12
end
-- One thin row for a screen edge; segments that do not fit are dropped by priority.
local function statusBar(now)
    local b=M.battery(measure('BatteryFlags'),measure('BatteryPercent'),measure('BatteryAC'),measure('BatteryLife'))
    local c=M.clamp(measure('CPU'),0,100)
    local total=measure('RAMTotal')
    local rp=total>0 and M.clamp(measure('RAM')/total*100,0,100) or nil
    local dv,du=M.rate(measure('Download'));local uv,uu=M.rate(measure('Upload'))
    local pv,pu=M.ping(measure('Ping'))
    -- label, value, design width, value color, bar fraction, priority (1 is kept first)
    local segs={{'',os.date('%H:%M',now),56,C.accent,nil,1},
        {'',string.upper(os.date('%a %d %b',now)),100,C.text,nil,6},
        {'CPU',string.format('%.0f%%',c),76,C.text,c/100,2},
        {'RAM',rp and string.format('%.0f%%',rp) or '--',76,C.text,(rp or 0)/100,3},
        {'↓',dv..' '..du,112,C.text,nil,4},
        {'↑',uv..' '..uu,112,C.text,nil,7}}
    if b.valid then segs[#segs+1]={'BAT',string.format('%.0f%%',b.percent)..(b.charging and '+' or ''),82,C.text,b.percent/100,5} end
    segs[#segs+1]={'PING',pv=='--' and '--' or pv..' '..pu,88,C.text,nil,8}
    local avail=W-24-48
    local order={}
    for i,s in ipairs(segs) do s.w=s[3]*T;order[#order+1]=i end
    table.sort(order,function(a,b2) return segs[a][6]<segs[b2][6] end)
    local used,keep=0,{}
    for _,i in ipairs(order) do
        if used+segs[i].w+(used>0 and 12 or 0)<=avail then keep[i]=true;used=used+segs[i].w+(used>0 and 12 or 0) end
    end
    local shown={}
    for i,s in ipairs(segs) do if keep[i] then shown[#shown+1]=s end end
    -- Spread the kept segments across the bar.
    local gap=#shown>1 and math.min(48,(avail-used)/(#shown-1)+12) or 0
    local rowY=10
    local barY=rowY+labelHeight(13)+1
    local x=24
    for _,s in ipairs(shown) do
        local lw=s[1]~='' and (s[1]=='↓' or s[1]=='↑') and 16*T or s[1]~='' and (#s[1]*.6*10*T+6) or 0
        if lw>0 then text(s[1],x,rowY+(labelHeight(13)-labelHeight(10))/2,10,C.muted,lw+4) end
        text(s[2],x+lw,rowY,13,s[4],s.w-lw)
        if s[5] then bar(x+lw,barY,s.w-lw-8,3,s[5],C.accent) end
        x=x+s.w+gap
    end
    text('•••',W-42,rowY+(labelHeight(13)-18*1.4-4)/2,18,C.muted,30,settingsAction,nil,nil,'fixed')
    H=barY+3+8
end
local function vitals(now)
    local c=M.clamp(measure('CPU'),0,100)
    local total=measure('RAMTotal');local ram=measure('RAM')
    local rp=total>0 and M.clamp(ram/total*100,0,100) or 0
    local dt=measure('DiskTotal');local df=measure('DiskFree')
    series(cpu,c,now)
    if variant=='Compact' then
        -- Compact strip: CPU, memory and disk side by side, each a reading over a bar.
        header('SYSTEM VITALS')
        local nf=var('NumberFont','JetBrains Mono')
        local colW=(W-64)/3
        local dp=dt>0 and M.clamp((1-df/dt)*100,0,100) or nil
        local y=46
        local barY=y+labelHeight(10)+28*N*1.4+4
        for i,col in ipairs({{'CPU',c,C.accent},{'MEMORY',total>0 and rp or nil,C.secondary},{var('Disk','C:')..' USED',dp,C.accent}}) do
            local x=24+(i-1)*(colW+8)
            text(col[1],x,y,10,C.muted,colW)
            hero(col[2] and string.format('%.0f%%',col[2]) or '--',x-2,y+labelHeight(10),28,C.text,colW,nil,nil,nf)
            bar(x,barY,colW,4,(col[2] or 0)/100,col[3])
        end
        H=barY+(look=='Instrument' and 6 or 4)+16
        return
    end
    local cx1,cx2=W*.28,W*.72
    local r=math.max(38,38*N)
    local cy=62+r
    local labelY=cy+r+10
    local diskY=labelY+labelHeight(10)+10
    local diskH=math.max(52,labelHeight(13)+28)
    local footerY=diskY+diskH+12
    H=(footerY+labelHeight(11)+10)
    header('SYSTEM VITALS')
    ring(cx1,cy,r,c,C.accent);ring(cx2,cy,r,rp,C.secondary)
    local nf=var('NumberFont','JetBrains Mono')
    local function reading(value,cx)
        if look=='Instrument' or value=='--' then
            hero(value..(value=='--' and '' or '%'),cx,cy-28*N*.7-2,28,C.text,r*1.85,nil,'Center',nf)
            return
        end
        -- Digits with a half-size % on their baseline, centred together in the ring.
        local s=fontSize(value..'%',28,r*1.7,'number',nf)
        local p=s*.5
        local dw,pw=#value*.6*s,.6*p
        local left=cx-(dw+pw)/2
        local y=cy-(s*1.4+4)/2
        text(value,left,y,s,C.text,dw+4,nil,'Left',nf,'fixed')
        text('%',left+dw,y+1.08*(s-p),p,C.muted,pw+4,nil,'Left',nf,'fixed')
    end
    reading(string.format('%.0f',c),cx1)
    reading(total>0 and string.format('%.0f',rp) or '--',cx2)
    text('CPU',cx1,labelY,10,C.muted,100,nil,'Center')
    text('MEMORY',cx2,labelY,10,C.muted,100,nil,'Center')
    rect(24,diskY,W-48,diskH,13,C.chip)
    text(var('Disk','C:')..' DRIVE',36,diskY+7,10,C.muted,100)
    text(dt>0 and string.format('%.0f GB free',df/1073741824) or 'Unavailable',W-36,diskY+5,13,C.text,W-184,nil,'Right')
    bar(36,diskY+diskH-(look=='Instrument' and 15 or 13),W-72,4,dt>0 and 1-df/dt or 0,C.accent)
    text('UPTIME  '..M.duration(measure('Uptime')),24,footerY,10,C.muted,W-144)
    text('Details ↗',W-24,footerY,11,C.muted,100,'["taskmgr.exe"]','Right')
end
local function clock()
    local nf=var('NumberFont','JetBrains Mono')
    local time=os.date('%H:%M')
    if variant=='Compact' then
        -- Compact strip: the time on the left, weekday and date stacked on the right.
        header('LOCAL TIME')
        local numberW=(W-48)*.55
        hero(time,22,44,44,C.accent,numberW,nil,nil,nf)
        local rowH=44*N*1.4
        local stack=labelHeight(13)+labelHeight(11)
        local sy=44+math.max(0,(rowH-stack)/2)
        local rw=W-48-numberW-8
        text(string.upper(os.date('%A')),W-24,sy,13,C.text,rw,nil,'Right')
        text(os.date('%d %b %Y'),W-24,sy+labelHeight(13),11,C.muted,rw,nil,'Right')
        H=44+math.max(rowH,stack)+14
        return
    end
    local number=fontSize(time,74,W-44,'number',nf)
    local dayY=45+number*1.4+6
    local dateY=dayY+labelHeight(13)+4
    local dotsY=dateY+labelHeight(12)+18
    H=(dotsY+22)
    header('LOCAL TIME')
    hero(time,22,45,74,C.accent,W-44,nil,nil,nf)
    text(string.upper(os.date('%A')),26,dayY,13,C.text,W-52)
    text(os.date('%d %B %Y'),26,dateY,12,C.muted,W-52)
    local start=M.weekStart(var('WeekStart','Mon'))
    local day=M.weekColumn(tonumber(os.date('%w'))+1,start)+1
    for i=1,7 do
        local x=29+(i-1)*(W-58)/6
        if i==day then circle(x,dotsY,10,C.accent) end
        text(dayLetters[(start+i-1)%7+1],x,dotsY-9,10,i==day and C.surface or C.muted,22,nil,'Center',nil,'fixed')
    end
end
local function shortcuts()
    H=(106+labelHeight(10)+12)
    header('QUICK SHORTCUTS')
    local items={{'Wi-Fi','\238\156\129','ms-settings:network-wifi'},
        {'Bluetooth','\238\156\130','ms-settings:bluetooth'},{'Sound','\238\157\167','ms-settings:sound'},
        {'Display','[\\xE7F4]','ms-settings:display'},{'Files','\238\162\183','explorer.exe'},
        {'Settings','\238\156\147','ms-settings:'}}
    local cell=(W-40)/6
    for i,item in ipairs(items) do
        local x=20+(i-1)*cell+cell/2
        circle(x,76,24,i%2==1 and C.chip or C.panel)
        text(item[2],x,61,25,C.accent,48,'["'..item[3]..'"]','Center','Segoe MDL2 Assets','fixed')
        text(item[1],x,106,10,C.muted,cell-4,'["'..item[3]..'"]','Center')
    end
end
function button(label,x,y,w,selected,code,h)
    h=h or 34
    rect(x,y,w,h,h/2,selected and C.accent or C.chip)
    text(label,x+w/2,y+(h-labelHeight(12))/2+1,12,selected and C.surface or C.text,w-12,action(code),'Center')
end
function ToggleAudioMute()
    SKIN:Bang('!CommandMeasure', 'MeasureAudioVol', 'ToggleMute')
end
function AudioChange(val)
    SKIN:Bang('!CommandMeasure', 'MeasureAudioVol', 'ChangeVolume ' .. tostring(val))
end
local function audio()
    local vol = measure('MeasureAudioVol')
    local dev = measureString('MeasureAudioVol', 'Default Audio Device')
    local isMuted = vol < 0
    local val = isMuted and 0 or M.clamp(vol, 0, 100)
    local nf = var('NumberFont', 'JetBrains Mono')
    local displayNum = isMuted and 'MUTED' or string.format('%.0f%%', val)
    local numSize = isMuted and 38 or 48
    header('AUDIO CONTROLS')
    local top = 50
    local numberWidth = 130
    local chipX = 24 + numberWidth + 10
    local chipW = W - chipX - 24
    hero(displayNum, 22, top, numSize, isMuted and C.muted or C.accent, numberWidth, nil, nil, nf)
    chip('OUTPUT DEVICE', dev, chipX, top + 4, chipW)
    -- Below whichever is taller: the number or the chip beside it.
    local barY = math.max(top + 48 * N * 1.4, top + 4 + chipHeight()) + 10
    local barW = W - 48
    bar(24, barY, barW, 8, val / 100, isMuted and C.muted or C.accent)
    local btnY = barY + 18
    local btnW = (W - 56) / 3
    button(isMuted and 'Unmute' or 'Mute', 24, btnY, btnW, false, 'ToggleAudioMute()')
    button('-5%', 24 + btnW + 4, btnY, btnW, false, 'AudioChange(-5)')
    button('+5%', 24 + (btnW + 4) * 2, btnY, btnW, false, 'AudioChange(5)')
    local footerY = btnY + 44
    H = (footerY + labelHeight(10) + 10)
    text('MASTER VOLUME', 24, footerY, 10, C.muted, W - 144)
    text('Sound ↗', W - 24, footerY, 11, C.muted, 100, '["ms-settings:sound"]', 'Right')
end
local function spectrum()
    local barCount = 16
    local totalW = W - 48
    local gap = 3
    local barW = math.max(3, (totalW - (barCount - 1) * gap) / barCount)
    local graphH = 80
    local graphY = 56
    local footerY = graphY + graphH + 26
    H = (footerY + labelHeight(10) + 12)
    header('AUDIO SPECTRUM', variant == 'SpectrumLine' and 'FFT CURVE' or variant == 'SpectrumLED' and 'LED METER' or '16-BAND FFT')
    local peakL = M.clamp(measure('PeakL'), 0, 1)
    local peakR = M.clamp(measure('PeakR'), 0, 1)
    local led = look == 'Instrument'
    if led then graphPanel(24, graphY, totalW, graphH, 12) else rect(24, graphY, totalW, graphH, 12, C.panel) end
    -- Peak hold for the variants: each band's peak falls slowly after a hit.
    local values = {}
    spectrumLoud = peakL > .002 or peakR > .002
    for i = 0, barCount - 1 do
        local v = M.clamp(measure('Band' .. i), 0, 1)
        values[i] = v
        spectrumPeaks[i] = math.max(v, (spectrumPeaks[i] or 0) - .015)
        if v > .002 or spectrumPeaks[i] > .002 then spectrumLoud = true end
    end
    if variant == 'SpectrumLine' then
        -- A smooth curve through the bands (Catmull-Rom), filled down to the baseline.
        local x0, x1 = 24 + 10, 24 + totalW - 10
        local base, top = graphY + graphH - 8, graphY + 8
        local function P(i) i = M.clamp(i, 0, barCount - 1); return values[i] end
        for k = 1, 3 do
            local gy = base - (base - top) * k / 4
            line(x0, gy, x1, gy, C.grid, 1)
        end
        local pts = {}
        local step = (x1 - x0) / (barCount - 1)
        for i = 0, barCount - 2 do
            local p0, p1, p2, p3 = P(i - 1), P(i), P(i + 1), P(i + 2)
            for s = 0, 3 do
                local t = s / 4
                local v = .5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
                pts[#pts + 1] = {x0 + (i + t) * step, base - (base - top) * M.clamp(v, 0, 1)}
            end
        end
        pts[#pts + 1] = {x1, base - (base - top) * values[barCount - 1]}
        local area = {{x0, base}}
        for _, p in ipairs(pts) do area[#area + 1] = p end
        area[#area + 1] = {x1, base}
        poly(area, C.accent .. ',55')
        path(pts, C.accent, 2)
        for i = 0, barCount - 1 do
            circle(x0 + i * step, base - (base - top) * spectrumPeaks[i], 2, i < 11 and C.text or C.secondary)
        end
    elseif variant == 'SpectrumLED' then
        -- Discrete LED blocks: lit from the bottom, the top two in the secondary color, and a peak-hold block.
        local segs = 12
        local pitch = (graphH - 14) / segs
        for i = 0, barCount - 1 do
            local bx = 24 + i * (barW + gap)
            local lit = math.floor(values[i] * segs + .5)
            local peak = math.ceil(spectrumPeaks[i] * segs - .01)
            for s = 1, segs do
                local by = graphY + graphH - 7 - s * pitch + 1
                local color = led and C.track or C.chip
                if s <= lit then color = s > segs - 2 and C.secondary or C.accent
                elseif s == peak then color = C.text end
                rect(bx, by, barW, pitch - 2, 1.5, color)
            end
        end
    end
    for i = 0, (variant == 'Spectrum' and barCount - 1 or -1) do
        local val = values[i]
        local bx = 24 + i * (barW + gap)
        local bh = math.max(3, val * (graphH - 14))
        local by = graphY + graphH - 7 - bh
        local radius = led and 1 or barW / 2
        rect(bx, graphY + 7, barW, graphH - 14, radius, led and C.track or C.chip .. ',140')
        -- Bass/mid in the accent, treble in the secondary color.
        rect(bx, by, barW, bh, radius, i < 11 and C.accent or C.secondary)
    end
    if led and variant == 'Spectrum' then
        -- Panel-colored gaps across the bars turn them into LED segments.
        for yy = graphY + graphH - 7 - 5, graphY + 9, -5 do line(24 + 4, yy, 24 + totalW - 4, yy, C.panel, 1.6) end
    end
    local labelY = graphY + graphH + 6
    text('BASS', 24, labelY, 9, C.muted, totalW / 3)
    text('MID', W / 2, labelY, 9, C.muted, totalW / 3, nil, 'Center')
    text('TREBLE', W - 24, labelY, 9, C.muted, totalW / 3, nil, 'Right')
    text(string.format('PEAK L:%.0f%%  R:%.0f%%', peakL * 100, peakR * 100), 24, footerY, 10, C.muted, W - 144)
    text('Sound ↗', W - 24, footerY, 11, C.muted, 100, '["ms-settings:sound"]', 'Right')
end
-- Now Playing: NowPlaying.ps1 (started by the skin through RunCommand) mirrors Windows' media
-- session into Data\nowplaying.txt and runs commands left in Data\nowplaying.cmd.
function MediaCommand(cmd)
    local file=io.open(var('@')..'Data\\nowplaying.cmd','w')
    if file then file:write(cmd);file:close() end
    -- Flip play/pause at once; the helper's next report confirms it.
    if cmd=='toggle' and media then media.playing=not media.playing;media.flipped=os.time() end
end
function SetAudioVolume(v)
    SKIN:Bang('!CommandMeasure','MeasureAudioVol','SetVolume '..tostring(v))
end
local function glyph(code,cx,cy,size,color,act)
    -- Segoe MDL2 Assets icon centred on cx,cy.
    local h=size*1.4+4
    text(code,cx,cy-h/2+size*.1,size,color,size*1.6,act,'Center','Segoe MDL2 Assets','fixed')
end
local function nowPlaying(now)
    local file=io.open(var('@')..'Data\\nowplaying.txt','rb')
    local m={}
    if file then m=M.parseMedia(file:read('*a') or '');file:close() end
    -- A flipped play state holds until the helper reports or 3 s pass.
    if media and media.flipped and now-media.flipped<3 and m.title==media.title then m.playing=media.playing;m.flipped=media.flipped end
    media=m
    -- The helper rewrites its heartbeat every few seconds; an old file means it is not running.
    local alive=m.heartbeat and math.abs(now-m.heartbeat)<20
    local active=alive and m.active
    header('NOW PLAYING',active and string.upper(M.mediaSource(m.app)) or nil)
    local art=76
    local ax,ay=24,48
    -- Cover art: an Image meter clipped by a rounded mask (both in the NowPlaying skin).
    rect(ax,ay,art,art,14,C.chip)
    local cover=active and m.cover and m.cover~='' and m.cover
    if cover then
        set('CoverMask','Shape','Rectangle 0,0,'..f(art)..','..f(art)..','..f(14)..' | Fill Color 255,255,255 | StrokeWidth 0')
        set('CoverMask','X',f(ax));set('CoverMask','Y',f(ay));set('CoverMask','Hidden',0)
        set('Cover','ImageName',var('@')..'Data\\'..cover)
        set('Cover','W',f(art));set('Cover','H',f(art));set('Cover','Hidden',0)
    else
        set('CoverMask','Hidden',1);set('Cover','Hidden',1)
        glyph('[\\xE8D6]',ax+art/2,ay+art/2,28,C.accent)
    end
    local tx=ax+art+14
    local tw=W-tx-24
    local function trim(value,size) return M.utf8Trim(value,math.max(4,math.floor((tw-2)/(size*T*.6)))) end
    if active then
        text(trim(m.title,14),tx,ay+4,14,C.text,tw)
        local by=ay+4+labelHeight(14)+2
        if (m.artist or '')~='' then text(trim(m.artist,11),tx,by,11,C.muted,tw);by=by+labelHeight(11) end
        if (m.album or '')~='' and m.album~=m.title then text(trim(m.album,10),tx,by,10,C.muted,tw) end
    else
        text(alive and 'Nothing playing' or 'Starting media helper',tx,ay+4,14,C.text,tw)
        text(alive and 'Play music in any app' or 'Reads Windows media controls',tx,ay+4+labelHeight(14)+2,11,C.muted,tw)
    end
    -- Progress, when the player reports a timeline.
    local y=ay+art+12
    local pos=active and M.mediaPosition(m,now)
    if pos then
        bar(24,y,W-48,4,pos/m.duration,C.accent)
        text(M.trackTime(pos),24,y+10,9,C.muted,80)
        text(M.trackTime(m.duration),W-24,y+10,9,C.muted,80,nil,'Right')
    else
        bar(24,y,W-48,4,0,C.accent)
    end
    -- Transport: previous, play/pause, next.
    local cy=y+10+labelHeight(9)+22
    local cx=W/2
    local live=active and C.text or C.muted
    -- Icons are drawn as shapes so they sit exactly in their circles (font glyphs ride their line box);
    -- a transparent box over each circle takes the click.
    local function hit(x,r,code,tip)
        text(' ',x-r,cy-r,10,C.muted,2*r,action(code))
        texts[#texts].H=f(2*r);texts[#texts].SolidColor='0,0,0,1';texts[#texts].ToolTipText=tip
    end
    local function skip(x,dir,color)
        -- A bar and a triangle, together centred on x: dir -1 points left (previous), 1 right (next).
        local s=5.5
        poly({{x-dir*s*.75,cy-s},{x-dir*s*.75,cy+s},{x+dir*s*.75,cy}},color)
        rect(dir<0 and x-s*.75-2.2 or x+s*.75,cy-s,2.2,2*s,1,color)
    end
    circle(cx-62,cy,17,C.chip)
    skip(cx-62+1.1,-1,(active and m.canPrev~='0') and live or C.muted)
    hit(cx-62,17,"MediaCommand('prev')",'Previous')
    circle(cx,cy,23,active and C.accent or C.chip)
    local playColor=active and C.surface or C.muted
    if m.playing and active then
        rect(cx-6,cy-7.5,4,15,1,playColor);rect(cx+2,cy-7.5,4,15,1,playColor)
    else
        -- A triangle's visual centre is a third of its width from the flat side, so shift it right.
        poly({{cx-4.5,cy-8.5},{cx-4.5,cy+8.5},{cx+8.5,cy}},playColor)
    end
    hit(cx,23,"MediaCommand('toggle')",m.playing and active and 'Pause' or 'Play')
    circle(cx+62,cy,17,C.chip)
    skip(cx+62-1.1,1,(active and m.canNext~='0') and live or C.muted)
    hit(cx+62,17,"MediaCommand('next')",'Next')
    -- Volume: mute toggle, a bar that sets the level where clicked, and the reading.
    local vol=measure('MeasureAudioVol')
    local muted=vol<0
    local level=muted and 0 or M.clamp(vol,0,100)
    local vy=cy+23+16
    local rowH=labelHeight(11)
    glyph(muted and '[\\xE74F]' or '[\\xE767]',34,vy+rowH/2,14,muted and C.muted or C.accent,action('ToggleAudioMute()'))
    local bx,bw=54,W-54-24-44
    bar(bx,vy+rowH/2-3,bw,6,level/100,muted and C.muted or C.accent)
    for i=1,10 do
        text(' ',bx+(i-1)*bw/10,vy,10,C.muted,bw/10,action('SetAudioVolume('..(i*10)..')'))
        texts[#texts].H=f(rowH);texts[#texts].SolidColor='0,0,0,1'
        texts[#texts].ToolTipText='Volume '..(i*10)..'%'
    end
    text(muted and 'MUTE' or string.format('%.0f%%',level),W-24,vy,11,C.muted,40,nil,'Right')
    H=vy+rowH+14
end
local function cores()
    local totalCpu = M.clamp(measure('CPU0'), 0, 100)
    local nf = var('NumberFont', 'JetBrains Mono')
    local coreCount = M.coreCount(var('CoreCount', '8'))
    local top = 50
    local numberWidth = 110
    local chipX = 24 + numberWidth + 10
    local chipW = W - chipX - 24
    if variant=='CoresRings' then
        -- Cores Rings: one small ring per logical processor, its load inside.
        header('CPU CORES',string.format('%.0f%% TOTAL',totalCpu))
        local cols=coreCount<=4 and coreCount or coreCount<=8 and 4 or 8
        local cellW=(W-48)/cols
        local r=math.min(24,cellW/2-6)
        local stroke=math.max(2.5,r*.2)
        local cellH=2*r+stroke+8
        local y0=50
        for i=1,coreCount do
            local val=M.clamp(measure('CPU'..i),0,100)
            local cx=24+(((i-1)%cols)+.5)*cellW
            local cy=y0+math.floor((i-1)/cols)*cellH+r+stroke/2
            local pts={}
            for k=0,32 do local a=-math.pi/2+k/32*2*math.pi;pts[#pts+1]={cx+math.cos(a)*r,cy+math.sin(a)*r} end
            path(pts,C.border,stroke)
            if val>0 then
                local steps=math.max(2,math.ceil(32*val/100))
                local arc={}
                for k=0,steps do local a=-math.pi/2+k/steps*2*math.pi*val/100;arc[#arc+1]={cx+math.cos(a)*r,cy+math.sin(a)*r} end
                path(arc,i%2==1 and C.accent or C.secondary,stroke)
            end
            if r>=13 then text(string.format('%.0f',val),cx,cy-labelHeight(9)/2+1,9,C.text,2*r-stroke,nil,'Center') end
        end
        local footerY=y0+math.ceil(coreCount/cols)*cellH+6
        H=footerY+labelHeight(10)+12
        text(string.format('%d THREADS · LOAD %%',coreCount),24,footerY,10,C.muted,W-144)
        text('Details ↗',W-24,footerY,11,C.muted,100,'["taskmgr.exe"]','Right')
        return
    end
    header('CPU CORE HEATMAP')
    hero(string.format('%.0f%%', totalCpu), 22, top, 44, C.accent, numberWidth, nil, nil, nf)
    chip('LOGICAL CORES', string.format('%d THREADS', coreCount), chipX, top + 4, chipW)
    local startY = math.max(top + 44 * N * 1.4, top + 4 + chipHeight()) + 14
    if coreCount > 16 then
        -- Dense heatmap: one tile per thread, shaded by load, so 17-32 threads
        -- fit the text pool (one label per tile) and a reasonable card height.
        local cols, gap = 8, 4
        local tileW = (W - 48 - (cols - 1) * gap) / cols
        local tileH = math.max(26, labelHeight(9) + 6)
        local rows = math.ceil(coreCount / cols)
        for i = 1, coreCount do
            local tx = 24 + ((i - 1) % cols) * (tileW + gap)
            local ty = startY + math.floor((i - 1) / cols) * (tileH + gap)
            local val = M.clamp(measure('CPU' .. i), 0, 100)
            rect(tx, ty, tileW, tileH, 6, C.chip)
            if val > 0 then rect(tx, ty, tileW, tileH, 6, C.accent .. ',' .. math.floor(40 + val * 2.15)) end
            text(string.format('%.0f', val), tx + tileW / 2, ty + (tileH - labelHeight(9)) / 2 + 2, 9,
                val > 55 and C.surface or C.text, tileW - 4, nil, 'Center')
        end
        local footerY = startY + rows * (tileH + gap) + 6
        H = (footerY + labelHeight(10) + 12)
        text('PER-THREAD LOAD %', 24, footerY, 10, C.muted, W - 144)
        text('Details ↗', W - 24, footerY, 11, C.muted, 100, '["taskmgr.exe"]', 'Right')
        return
    end
    local cols = 2
    local rows = math.ceil(coreCount / cols)
    local colW = (W - 56) / cols
    local rowH = 20
    for i = 1, coreCount do
        local cIdx = (i - 1) % cols
        local rIdx = math.floor((i - 1) / cols)
        local cx = 24 + cIdx * (colW + 8)
        local cy = startY + rIdx * rowH
        local val = M.clamp(measure('CPU' .. i), 0, 100)
        local labelW = 24
        local valW = 32
        local barW = colW - labelW - valW - 8
        text(string.format('C%02d', i), cx, cy, 9, C.muted, labelW)
        bar(cx + labelW, cy + 4, barW, 6, val / 100, (i % 2 == 1) and C.accent or C.secondary)
        text(string.format('%.0f%%', val), cx + labelW + barW + 4, cy, 9, C.text, valW, nil, 'Right')
    end
    local footerY = startY + rows * rowH + 10
    H = (footerY + labelHeight(10) + 12)
    text('PER-CORE UTILIZATION', 24, footerY, 10, C.muted, W - 144)
    text('Details ↗', W - 24, footerY, 11, C.muted, 100, '["taskmgr.exe"]', 'Right')
end
local function sysinfo()
    header('SYSTEM SPECIFICATIONS')
    local rawCpu = measureString('CPUName', 'Windows PC')
    local cleanCpu = M.cpuName(rawCpu)
    local prod = measureString('OSProd', 'Windows 11')
    local bits = measureString('OSBits', '64')
    local disp = measureString('OSDisplay', '24H2')
    local build = measureString('OSBuild', 'Build')
    local host = measureString('HostName', 'DESKTOP')
    local swText, swPct = M.swap(measure('SwapUsed'), measure('SwapTotal'))
    local chipW = (W - 56) / 2
    local chipH = chipHeight()
    local chipX2 = W / 2 + 4
    local cpuY = 50
    rect(24, cpuY, W - 48, 38, 12, C.chip)
    text('PROCESSOR', 36, cpuY + 5, 9, C.muted, W - 72)
    text(cleanCpu, 36, cpuY + 18, 11, C.text, W - 72)
    local y1 = cpuY + 46
    local y2 = y1 + chipH + 8
    chip('OS · ' .. bits .. '-BIT', prod, 24, y1, chipW)
    chip('RELEASE & BUILD', disp .. ' · ' .. build, chipX2, y1, chipW)
    chip('HOSTNAME', host, 24, y2, chipW)
    chip('COMMIT CHARGE', swText, chipX2, y2, chipW)
    local footerY = y2 + chipH + 14
    H = (footerY + labelHeight(10) + 12)
    text('UPTIME  ' .. M.duration(measure('Uptime')), 24, footerY, 10, C.muted, W - 144)
    text('About ↗', W - 24, footerY, 11, C.muted, 100, '["ms-settings:about"]', 'Right')
end
local function diagnostics(now)
    local p = measure('Ping')
    series(pingList, (p >= 0 and p < 30000) and p or 0, now)
    local pv, pu = M.ping(p)
    local nf = var('NumberFont', 'JetBrains Mono')
    local isOnline = measure('Internet') == 1
    if variant == 'Compact' then
        -- Ping Mini: latency and its 60-second graph.
        header('PING', var('PingHost', '1.1.1.1'))
        local top = 46
        local numberW = W / 2 - 40
        local effective = fontSize(pv, 36, numberW, 'number', nf)
        local drawn = hero(pv, 22, top, 36, pv == '--' and C.muted or C.accent, numberW, nil, nil, nf)
        text(pu, math.min(22 + drawn + 6, numberW + 16), top + effective * 1.4 - labelHeight(11) - 3, 11, C.muted, 70)
        local stack = labelHeight(12)
        text(isOnline and 'Online' or 'Offline', W - 24, top + (36 * N * 1.4 - stack) / 2, 12,
            isOnline and C.text or C.secondary, W / 2 - 40, nil, 'Right')
        local graphY = top + 36 * N * 1.4 + 6
        graphPanel(24, graphY, W - 48, 30, 9)
        local peak = 50
        for _, pt in ipairs(pingList) do peak = math.max(peak, pt.v) end
        spark(pingList, 30, graphY + 5, W - 60, 20, C.accent, peak, now)
        H = graphY + 30 + 14
        return
    end
    local chipW = (W - 56) / 2
    local chipH = chipHeight()
    local chipX2 = W / 2 + 4
    local numberY = 54 + labelHeight(10) + 4
    local chipsY = math.max(numberY + 44 * N * 1.4, 54 + chipH) + 14
    local chipsY2 = chipsY + chipH + 8
    local graphY = chipsY2 + chipH + 12
    local footerY = graphY + 46
    H = (footerY + labelHeight(10) + 12)
    header('NETWORK DIAGNOSTICS')
    text('PING LATENCY', 24, 54, 10, C.muted, W - 48)
    local numberW = W / 2 - 80
    local effective = fontSize(pv, 44, numberW, 'number', nf)
    -- Unit sits just after the digits, on their baseline.
    local drawn = hero(pv, 22, numberY, 44, pv == '--' and C.muted or C.accent, numberW, nil, nil, nf)
    local unitX = math.min(22 + drawn + 8, W / 2 - 54)
    text(pu, unitX, numberY + effective * 1.4 - labelHeight(12) - 4, 12, C.muted, 62)
    chip('INTERNET', isOnline and 'Connected' or 'Offline', chipX2, 54, chipW)
    chip('LOCAL IP', measureString('IP', '127.0.0.1'), 24, chipsY, chipW)
    chip('GATEWAY', measureString('Gateway', '192.168.1.1'), chipX2, chipsY, chipW)
    chip('SUBNET', measureString('Mask', '255.255.255.0'), 24, chipsY2, chipW)
    local dns = measureString('DNS', '')
    chip('DNS SERVER', (dns ~= '' and dns ~= '0') and dns or 'Automatic', chipX2, chipsY2, chipW)
    graphPanel(24, graphY, W - 48, 38, 11)
    local peak = 50
    for _, pt in ipairs(pingList) do peak = math.max(peak, pt.v) end
    spark(pingList, 32, graphY + 6, W - 64, 26, C.accent, peak, now)
    text('TARGET  ' .. var('PingHost', '1.1.1.1'), 24, footerY, 10, C.muted, W - 144)
    text('Network ↗', W - 24, footerY, 11, C.muted, 100, '["ms-settings:network"]', 'Right')
end
-- presets: optional clickable values shown under the track instead of min/max labels.
local function slider(key,label,y,presets)
    local spec=M.sizes[key]
    local value=M.size(key,num(key,1)) or 1
    local x,w,cy=36,428,y+28
    local steps=math.floor((spec.max-spec.min)/spec.step+.5)
    local fraction=(value-spec.min)/(spec.max-spec.min)
    text(label,26,y,11,C.muted,350)
    text(string.format('%.0f%%',value*100),W-26,y-2,14,C.accent,90,nil,'Right')
    rect(x,cy-3,w,6,3,C.border)
    if fraction>0 then rect(x,cy-3,w*fraction,6,3,C.accent) end
    for i=0,steps do
        local px=x+w*i/steps
        circle(px,cy,1.5,i/steps<=fraction and C.surface or C.muted)
        local v=M.size(key,spec.min+i*spec.step)
        local left=i==0 and x-10 or x+w*(i-.5)/steps
        local right=i==steps and x+w+10 or x+w*(i+.5)/steps
        hits[#hits+1]={X=f(left),Y=f(cy-16),W=f(right-left),H=f(32),Hidden='0',
            LeftMouseDownAction=action("BeginDrag('"..key.."',"..v..")"),
            MouseOverAction=action("DragTo('"..key.."',"..v..")"),
            LeftMouseUpAction=action("FinishDrag('"..key.."',"..v..")"),
            MouseScrollUpAction=action("Nudge('"..key.."',1)"),
            MouseScrollDownAction=action("Nudge('"..key.."',-1)"),
            RightMouseUpAction=action("Configure('"..key.."','1')"),
            ToolTipText='Drag or click to set. Scroll for 5% steps. Right-click to reset.'}
    end
    circle(x+w*fraction,cy,10,C.surface)
    circle(x+w*fraction,cy,7,C.accent)
    if presets then
        for _,v in ipairs(presets) do
            local px=x+w*(v-spec.min)/(spec.max-spec.min)
            local on=math.abs(value-v)<.001
            text(string.format('%.0f',v*100),px,cy+14,9,on and C.accent or C.muted,34,
                action("Configure('"..key.."','"..v.."')"),'Center')
        end
    else
        text(string.format('%.0f',spec.min*100),x,cy+14,9,C.muted,40)
        text(string.format('%.0f',spec.max*100),x+w,cy+14,9,C.muted,40,nil,'Right')
    end
end
-- Compact settings: rows of 30 px buttons, paired sections, presets under the size slider.
local SettingsHeight=642
local function settings()
    H=SettingsHeight
    header('NERD WIDGETS / WINDOWS')
    local style=look
    local bh=30
    local function disabled(label,x,yy,w)
        rect(x,yy,w,bh,bh/2,C.panel)
        text(label,x+w/2,yy+(bh-labelHeight(12))/2+1,12,C.muted..',120',w-12,nil,'Center')
    end
    text('STYLE',26,48,10,C.muted)
    for i,v in ipairs({'Expressive','Blacks','Instrument'}) do button(v,24+(i-1)*152,64,144,style==v,"Configure('Style','"..v.."')",bh) end
    -- Theme and corners share one row.
    text(style=='Expressive' and 'THEME' or 'THEME · ALWAYS DARK',26,106,10,C.muted,210)
    for i,v in ipairs({'Dark','Light'}) do
        if style=='Expressive' then button(v,24+(i-1)*106,122,100,var('Theme')==v,"Configure('Theme','"..v.."')",bh)
        else disabled(v,24+(i-1)*106,122,100) end
    end
    text('CORNERS',254,106,10,C.muted)
    for i,v in ipairs({0,16,28}) do button(({ 'Square','Soft','Round' })[i],252+(i-1)*76,122,72,num('Radius',28)==v,"Configure('Radius','"..v.."')",bh) end
    text(style=='Blacks' and 'ACCENT PALETTE' or 'PALETTE',26,164,10,C.muted)
    -- Five per row: two rows hold up to ten palettes.
    for i,v in ipairs(paletteOrder) do
        local row=math.floor((i-1)/5);local col=(i-1)%5
        button(v,24+col*91.6,180+row*36,84,var('Palette','Sage')==v,"Configure('Palette','"..v.."')",bh)
    end
    slider('Scale','WIDGET SIZE',262,{.25,.5,.75,1,1.25,1.5})
    slider('TextScale','LABELS AND READINGS',320)
    slider('NumberScale','LARGE NUMBERS',378)
    text('ADD TO DESKTOP',26,440,10,C.muted,200)
    text('Load all widgets',W-26,438,11,C.accent,200,action('LoadAll()'),'Right')
    texts[#texts].ToolTipText='Loads the full version of every widget that is not open yet'
    local widgetList={'Battery','Network','Vitals','Clock','Shortcuts','Audio','Cores','SysInfo','Diagnostics','Spectrum',
        'Calendar','Processes','DiskIO','Binary','GPU','Focus','Countdown','Weather','Progress','SunMoon','Analog','StatusBar','NowPlaying',
        'BatteryCompact','BinaryCompact','VitalsCompact','NetworkCompact','ClockCompact','ProcessesMap',
        'WeatherCompact','CalendarWeek','GPUCompact','CoresRings','FocusCompact','CountdownCompact','DiskIODrives','DiagnosticsCompact','SpectrumLine','SpectrumLED'}
    local labels={DiskIO='Disk I/O',Focus='Focus Timer',Progress='Day Progress',SunMoon='Sun & Moon',StatusBar='Status Bar',
        BatteryCompact='Battery Mini',BinaryCompact='Binary Mini',VitalsCompact='Vitals Mini',NetworkCompact='Network Mini',ClockCompact='Clock Mini',ProcessesMap='Process Map',
        WeatherCompact='Weather Mini',CalendarWeek='Calendar Week',GPUCompact='GPU Mini',CoresRings='Cores Rings',FocusCompact='Focus Mini',
        CountdownCompact='Countdown Mini',DiskIODrives='Disk Drives',DiagnosticsCompact='Ping Mini',
        NowPlaying='Now Playing',SpectrumLine='Spectrum Line',SpectrumLED='Spectrum LED'}
    for i,v in ipairs(widgetList) do
        local row=math.floor((i-1)/4);local col=(i-1)%4
        button(labels[v] or v,24+col*115,456+row*36,107,false,"Load('"..v.."')",bh)
    end
    local footY=456+math.ceil(#widgetList/4)*36+8
    text('Advanced settings ↗',26,footY,11,C.accent,200,'["notepad.exe" "#@#Settings.inc"]')
    text('Scroll sliders · Right-click resets',W-26,footY+1,10,C.muted,250,nil,'Right')
    H=math.max(SettingsHeight,footY+labelHeight(11)+14)
end
local function publishSize(key,value)
    local v=M.size(key,value)
    if not v then return nil end
    if math.abs(num(key,1)-v)>.0001 then
        SKIN:Bang('!SetVariableGroup',key,tostring(v),'NerdWidgets')
        -- Update rendering only: do not resample traffic counters during a drag.
        SKIN:Bang('!UpdateMeasureGroup','NerdWidgetsRenderer','*')
        SKIN:Bang('!UpdateMeterGroup','NerdWidgetsDrawing','*')
        SKIN:Bang('!RedrawGroup','NerdWidgets')
    end
    return v
end
function BeginDrag(key,value)
    if kind~='Settings' or not M.size(key,value) then return end
    EndDrag()
    drag={key=key,start=num(key,1),value=num(key,1)}
    DragTo(key,value)
end
function DragTo(key,value)
    if not drag or drag.key~=key then return end
    local v=publishSize(key,value)
    if v then drag.value=v end
end
function FinishDrag(key,value)
    DragTo(key,value)
    EndDrag()
end
function EndDrag()
    local previous=drag
    drag=nil
    if previous and math.abs(previous.value-previous.start)>.0001 then
        SKIN:Bang('!WriteKeyValue','Variables',previous.key,tostring(previous.value),var('@')..'Settings.inc')
    end
end
function Nudge(key,direction)
    local spec=M.sizes[key]
    if kind=='Settings' and spec then Configure(key,num(key,1)+spec.step*(direction>0 and 1 or -1)) end
end
function Configure(key,value)
    EndDrag()
    local size=M.size(key,value)
    if size then
        publishSize(key,size)
        SKIN:Bang('!WriteKeyValue','Variables',key,tostring(size),var('@')..'Settings.inc')
        return
    end
    local allowed={Style={Expressive=true,Blacks=true,Instrument=true},Theme={Dark=true,Light=true},Palette={Sage=true,Lavender=true,Blue=true,Peach=true,Teal=true,Rose=true,Amber=true,Slate=true,Red=true},
        Radius={['0']=true,['16']=true,['28']=true}}
    if not allowed[key] or not allowed[key][value] then return end
    SKIN:Bang('!WriteKeyValue','Variables',key,value,var('@')..'Settings.inc')
    SKIN:Bang('!RefreshGroup','NerdWidgets')
end
-- Every widget's full version, with its design height for first-time placement.
local fullWidgets={{'Battery',250},{'Network',272},{'Vitals',270},{'Clock',220},{'Shortcuts',136},{'Audio',190},
    {'Cores',260},{'SysInfo',260},{'Diagnostics',280},{'Spectrum',220},{'Calendar',300},{'Processes',330},
    {'DiskIO',300},{'Binary',270},{'GPU',330},{'Focus',262},{'Countdown',250},{'Weather',330},
    {'Progress',270},{'SunMoon',330},{'Analog',260},{'StatusBar',46},{'NowPlaying',260}}
-- Loads every widget that is not open, leaving open ones (Mini or full) as they are.
-- Widgets Rainmeter has never placed are laid out in columns instead of stacking at 0,0.
function LoadAll()
    EndDrag()
    local state={}
    local file=io.open(var('SETTINGSPATH')..'Rainmeter.ini','rb')
    if file then state=M.configState(file:read('*a'));file:close() end
    local scale=M.size('Scale',num('Scale',1)) or 1
    local cards,names={},{}
    for _,wd in ipairs(fullWidgets) do
        local name=wd[1]
        local s=state[name] or {active=0,placed=false}
        if s.active==0 then
            SKIN:Bang('!ActivateConfig','NerdWidgets\\'..name,name..'.ini')
            if not s.placed then
                local width=num(name..'Width',name=='StatusBar' and 800 or 340)
                cards[#cards+1]={w=width*scale,h=wd[2]*scale,wide=name=='StatusBar'};names[#cards]=name
            end
        end
    end
    local areaW=num('WORKAREAWIDTH',num('SCREENAREAWIDTH',1920))
    local areaH=num('WORKAREAHEIGHT',num('SCREENAREAHEIGHT',1080))
    for i,pos in ipairs(M.flowLayout(cards,areaW,areaH,16)) do
        SKIN:Bang('!Move',tostring(math.floor(num('WORKAREAX',0)+pos.x)),tostring(math.floor(num('WORKAREAY',0)+pos.y)),'NerdWidgets\\'..names[i])
    end
end
function Load(name)
    EndDrag()
    local allowed={Battery=true,Network=true,Vitals=true,Clock=true,Shortcuts=true,
        Audio=true,Cores=true,SysInfo=true,Diagnostics=true,Spectrum=true,
        Calendar=true,Processes=true,DiskIO=true,Binary=true,GPU=true,Focus=true,Countdown=true,Weather=true,
        Progress=true,SunMoon=true,Analog=true,StatusBar=true,NowPlaying=true}
    -- Compact variants share their widget's config, so loading one swaps the other.
    local compact={BatteryCompact='Battery',BinaryCompact='Binary',VitalsCompact='Vitals',NetworkCompact='Network',ClockCompact='Clock',ProcessesMap='Processes',
        WeatherCompact='Weather',CalendarWeek='Calendar',GPUCompact='GPU',CoresRings='Cores',FocusCompact='Focus',
        CountdownCompact='Countdown',DiskIODrives='DiskIO',DiagnosticsCompact='Diagnostics',
        SpectrumLine='Spectrum',SpectrumLED='Spectrum'}
    -- Older variants are Compact.ini; newer ones are <Widget>Compact.ini so they sort after the full card.
    local file={BatteryCompact='Compact.ini',BinaryCompact='Compact.ini'}
    if compact[name] then SKIN:Bang('!ActivateConfig','NerdWidgets\\'..compact[name],file[name] or name..'.ini')
    elseif allowed[name] then SKIN:Bang('!ActivateConfig','NerdWidgets\\'..name,name..'.ini') end
end
function Initialize()
    M=dofile(var('@')..'Scripts\\Model.lua')
    cache={};history={};down={};up={};cpu={};pingList={};reads={};writes={};gpuList={};lastShape=0;lastText=0;lastHit=0;drag=nil
    kind=var('Kind');variant=var('Variant')
    S=M.size('Scale',num('Scale',1)) or 1
    T=M.size('TextScale',num('TextScale',1)) or 1
    N=M.size('NumberScale',num('NumberScale',1)) or 1
    W=M.clamp(num('Width',340),320,kind=='StatusBar' and 1920 or 800)
    baseH=num('Height',240);H=baseH
    if kind=='Settings' then W=500;S=1;T=1;N=1 end
    look=var('Style','Expressive')
    if look~='Blacks' and look~='Instrument' then look='Expressive' end
    local p=palettes[var('Palette','Sage')] or palettes.Sage
    local colors=var('Theme','Dark')=='Light' and look=='Expressive' and p.light or p.dark
    C={accent=colors[1],secondary=colors[2],chip=colors[3],surface=colors[4],panel=colors[5],text=colors[6],muted=colors[7],border=colors[8]}
    if look=='Blacks' then
        -- Blacks: neutral dark greys; only the palette's dark accents carry color.
        C.surface='16,16,17';C.panel='26,26,28';C.chip='36,36,39';C.border='58,58,62'
        C.text='236,236,238';C.muted='150,150,156'
    elseif look=='Instrument' then
        -- Instrument: the Android Nerd Widgets lab look, sampled from the Pixel home screen.
        local i=instrument[var('Palette','Sage')] or instrument.Blue
        C={accent=i[1],secondary=i[2],chip=i[3],surface=i[4],panel=i[5],text=i[6],muted=i[7],border=i[8],track=i[9]}
    end
    C.track=C.track or C.border
    C.grid=C.border..(look=='Instrument' and ',170' or ',90')
    if kind=='Network' then
        -- Today's count carries on from the saved file; another day's total starts over.
        local file=io.open(trafficPath(),'r')
        if file then
            local saved=M.parseTraffic(file:read('*a'));file:close()
            if saved.date==os.date('%Y-%m-%d') then traffic=saved end
        end
        trafficSaved=os.time()
    end
    historyFile=var('@')..'Data\\battery.tsv'
    if kind=='Battery' then
        local file=io.open(historyFile,'r')
        if file then
            for l in file:lines() do
                -- Older files have no charging column.
                local t,v,c=l:match('^(%d+)\t([%d%.]+)\t?(%d*)$')
                if t and v then history[#history+1]={t=tonumber(t),v=tonumber(v),c=tonumber(c)} end
            end
            file:close()
        end
    end
end
function Update()
    if kind=='Spectrum' and spectrumIdle then
        -- Idle: only listen for sound, and draw once a second (when the slowed meters update).
        spectrumSkip=(spectrumSkip+1)%25
        if spectrumSkip~=0 then
            local heard=measure('PeakL')>.002 or measure('PeakR')>.002
            for i=0,15 do if heard then break end;heard=measure('Band'..i)>.002 end
            if not heard then return 0 end
        end
    end
    shapes={};texts={};hits={};H=baseH;DebugChips={}
    if kind~='Settings' then
        S=M.size('Scale',num('Scale',1)) or 1
        T=M.size('TextScale',num('TextScale',1)) or 1
        N=M.size('NumberScale',num('NumberScale',1)) or 1
    end
    local now=os.time()
    if kind=='Battery' then battery(now)
    elseif kind=='Network' then network(now)
    elseif kind=='Vitals' then vitals(now)
    elseif kind=='Clock' then clock()
    elseif kind=='Shortcuts' then shortcuts()
    elseif kind=='Audio' then audio()
    elseif kind=='Spectrum' then spectrum()
    elseif kind=='NowPlaying' then nowPlaying(now)
    elseif kind=='Cores' then cores()
    elseif kind=='SysInfo' then sysinfo()
    elseif kind=='Diagnostics' then diagnostics(now)
    elseif kind=='Calendar' then calendar()
    elseif kind=='Processes' then processes()
    elseif kind=='DiskIO' then diskio(now)
    elseif kind=='Binary' then binary(now)
    elseif kind=='GPU' then gpuCard(now)
    elseif kind=='Focus' then focusCard(now)
    elseif kind=='Countdown' then countdown(now)
    elseif kind=='Weather' then weatherCard(now)
    elseif kind=='Progress' then progressCard(now)
    elseif kind=='SunMoon' then sunMoon(now)
    elseif kind=='Analog' then analog(now)
    elseif kind=='StatusBar' then statusBar(now)
    elseif kind=='Settings' then settings() end
    local radius=M.clamp(num('Radius',28),0,48)
    if kind=='StatusBar' then radius=math.min(radius,H/2) end
    rect(0,0,W,H,radius,C.surface..','..M.clamp(num('Opacity',255),30,255))
    table.insert(shapes,1,table.remove(shapes))
    for i,s in ipairs(shapes) do set('Canvas',i==1 and 'Shape' or 'Shape'..i,s) end
    for i=#shapes+1,lastShape do set('Canvas','Shape'..i,'Rectangle 0,0,0,0 | StrokeWidth 0') end
    for i,t in ipairs(texts) do for k,v in pairs(t) do set('Text'..i,k,v) end end
    for i=#texts+1,lastText do set('Text'..i,'Hidden',1) end
    for i,t in ipairs(hits) do for k,v in pairs(t) do set('SliderHit'..i,k,v) end end
    for i=#hits+1,lastHit do set('SliderHit'..i,'Hidden',1) end
    set('Canvas','W',f(W));set('Canvas','H',f(H))
    lastShape=#shapes;lastText=#texts;lastHit=#hits
    if kind=='Spectrum' then
        -- Silent for 2 s: the drawing meters update once a second instead of 25 times, so an idle
        -- card stops redrawing. The first sound restores the full rate and applies this frame at once.
        spectrumQuiet=spectrumLoud and 0 or spectrumQuiet+1
        if spectrumLoud and spectrumIdle then
            spectrumIdle=false
            SKIN:Bang('!SetOptionGroup','NerdWidgetsDrawing','UpdateDivider','1')
            SKIN:Bang('!UpdateMeterGroup','NerdWidgetsDrawing')
        elseif not spectrumIdle and spectrumQuiet>=50 then
            spectrumIdle=true
            SKIN:Bang('!SetOptionGroup','NerdWidgetsDrawing','UpdateDivider','25')
        end
    end
    return 0
end
