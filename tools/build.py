"""Generate Rainmeter entry points and ZIP/RMSKIN distributions."""
from pathlib import Path
import zipfile
import struct

ROOT = Path(__file__).resolve().parents[1]
SKIN = ROOT / 'NerdWidgets'
RES = SKIN / '@Resources'


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Rainmeter's native INI parser needs UTF-16 for reliable Unicode paths/text.
    path.write_text(text.strip() + '\n', encoding='utf-16')


def measure(name, kind, **options):
    return f'[{name}]\nMeasure={kind}\n' + ''.join(f'{k}={v}\n' for k, v in options.items()) + '\n'


def main():
    common = '''
[Rainmeter]
Update=1000
AccurateText=1
DynamicWindowSize=1
BackgroundMode=2
SolidColor=0,0,0,1
Group=NerdWidgets
ContextTitle=Widget settings
ContextAction=[!ActivateConfig "NerdWidgets\\Settings" "Settings.ini"]
ContextTitle2=Edit shared settings
ContextAction2=["notepad.exe" "#@#Settings.inc"]
ContextTitle3=Refresh this suite
ContextAction3=[!RefreshGroup NerdWidgets]

[Metadata]
Author=Ranjith
Version=1.0.0
Information=Windows adaptation of the original Nerd Widgets Battery family.
License=Personal project
'''
    write(RES / 'Common.inc', common)
    meters = '''[MeasureRenderer]
Measure=Script
ScriptFile=#@#Scripts\\Widget.lua
Group=NerdWidgetsRenderer

[Canvas]
Meter=Shape
Shape=Rectangle 0,0,1,1 | StrokeWidth 0 | Fill Color 0,0,0,0
DynamicVariables=1
Group=NerdWidgetsDrawing
'''
    # 100 pooled text meters; ModelTests checks no card exceeds the pool.
    for i in range(1, 101):
        meters += f'''\n[Text{i}]
Meter=String
FontFace=#Font#
FontSize=10
FontColor=255,255,255
AntiAlias=1
ClipString=1
DynamicVariables=1
Hidden=1
Group=NerdWidgetsDrawing
'''
    write(RES / 'Meters.inc', meters)
    sliders=''
    for i in range(1,65):
        sliders+=f'''\n[SliderHit{i}]
Meter=Image
SolidColor=0,0,0,1
Hidden=1
DynamicVariables=1
MouseActionCursor=1
Group=NerdWidgetsDrawing
'''
    write(RES / 'Sliders.inc',sliders)
    battery = ''.join(measure('Battery' + n, 'Plugin', Plugin='PowerPlugin', PowerState=s)
                      for n, s in [('Percent','Percent'),('Flags','Status2'),('AC','ACLine'),('Life','Lifetime')])
    network = measure('Download','NetIn',Interface='#NetworkInterface#',DynamicVariables=1)
    network += measure('Upload','NetOut',Interface='#NetworkInterface#',DynamicVariables=1)
    vitals = measure('CPU','CPU',Processor=0)
    vitals += measure('RAM','PhysicalMemory')
    vitals += measure('RAMTotal','PhysicalMemory',Total=1)
    vitals += measure('DiskFree','FreeDiskSpace',Drive='#Disk#',UpdateDivider=30)
    vitals += measure('DiskTotal','FreeDiskSpace',Drive='#Disk#',Total=1,UpdateDivider=30)
    vitals += measure('Uptime','Uptime')
    audio = measure('MeasureAudioVol','Plugin',Plugin='Win7AudioPlugin')
    spectrum = measure('MeasureAudio','Plugin',Plugin='AudioLevel',Port='Output',FFTSize=1024,FFTOverlap=512,FFTAttack=40,FFTDecay=200,Bands=16,Sensitivity=35)
    for b in range(16):
        spectrum += measure(f'Band{b}','Plugin',Plugin='AudioLevel',Parent='MeasureAudio',Type='Band',BandIdx=b)
    spectrum += measure('PeakL','Plugin',Plugin='AudioLevel',Parent='MeasureAudio',Type='Peak',Channel='L')
    spectrum += measure('PeakR','Plugin',Plugin='AudioLevel',Parent='MeasureAudio',Type='Peak',Channel='R')
    cores = measure('CPU0','CPU',Processor=0)
    # One measure per logical processor, matching Model.coreCount's upper bound.
    for c in range(1, 33):
        cores += measure(f'CPU{c}','CPU',Processor=c,Disabled=f'({c} > %NUMBER_OF_PROCESSORS% ? 1 : 0)',DynamicVariables=1)
    sysinfo = measure('CPUName','Registry',RegHKey='HKEY_LOCAL_MACHINE',RegKey=r'HARDWARE\DESCRIPTION\System\CentralProcessor\0',RegValue='ProcessorNameString',UpdateDivider=300)
    sysinfo += measure('OSBuild','Registry',RegHKey='HKEY_LOCAL_MACHINE',RegKey=r'SOFTWARE\Microsoft\Windows NT\CurrentVersion',RegValue='CurrentBuild',UpdateDivider=300)
    sysinfo += measure('OSUBR','Registry',RegHKey='HKEY_LOCAL_MACHINE',RegKey=r'SOFTWARE\Microsoft\Windows NT\CurrentVersion',RegValue='UBR',UpdateDivider=300)
    sysinfo += measure('OSDisplay','Registry',RegHKey='HKEY_LOCAL_MACHINE',RegKey=r'SOFTWARE\Microsoft\Windows NT\CurrentVersion',RegValue='DisplayVersion',UpdateDivider=300)
    sysinfo += measure('OSProd','SysInfo',SysInfoType='OS_PRODUCT_NAME',UpdateDivider=300)
    sysinfo += measure('OSBits','SysInfo',SysInfoType='OS_BITS',UpdateDivider=300)
    sysinfo += measure('HostName','SysInfo',SysInfoType='HOST_NAME',UpdateDivider=300)
    sysinfo += measure('SwapUsed','SwapMemory')
    sysinfo += measure('SwapTotal','SwapMemory',Total=1)
    sysinfo += measure('Uptime','Uptime')
    diagnostics = measure('Ping','Plugin',Plugin='PingPlugin',DestAddress='#PingHost#',UpdateRate=2)
    diagnostics += measure('IP','SysInfo',SysInfoType='IP_ADDRESS',SysInfoData='#NetworkInterface#')
    diagnostics += measure('Gateway','SysInfo',SysInfoType='GATEWAY_ADDRESS',SysInfoData='#NetworkInterface#')
    diagnostics += measure('DNS','SysInfo',SysInfoType='DNS_SERVER',SysInfoData='#NetworkInterface#')
    diagnostics += measure('Mask','SysInfo',SysInfoType='NET_MASK',SysInfoData='#NetworkInterface#')
    diagnostics += measure('Internet','SysInfo',SysInfoType='INTERNET_CONNECTIVITY')
    # UsageMonitor: Index 0 is the total, 1..N the top processes (rolled up by name).
    # CPU values are already a percentage of all logical processors.
    processes = ''
    for i in range(1, 6):
        processes += measure(f'ProcCPU{i}','Plugin',Plugin='UsageMonitor',Alias='CPU',Index=i)
    for i in range(1, 6):
        processes += measure(f'ProcRAM{i}','Plugin',Plugin='UsageMonitor',Alias='RAM',Index=i)
    processes += measure('RAMTotal','PhysicalMemory',Total=1)
    # Process Map: whole-system totals for its section headings.
    processes += measure('CPU','CPU',Processor=0) + measure('RAM','PhysicalMemory')
    diskio = measure('DiskRead','Plugin',Plugin='UsageMonitor',Category='PhysicalDisk',Counter='Disk Read Bytes/sec',Index=0)
    diskio += measure('DiskWrite','Plugin',Plugin='UsageMonitor',Category='PhysicalDisk',Counter='Disk Write Bytes/sec',Index=0)
    # Fixed drives C-J are detected by a non-zero total; missing letters read 0.
    for letter in 'CDEFGHIJ':
        diskio += measure(f'Free{letter}','FreeDiskSpace',Drive=f'{letter}:',UpdateDivider=30)
        diskio += measure(f'Total{letter}','FreeDiskSpace',Drive=f'{letter}:',Total=1,UpdateDivider=30)
    gpu = measure('GPULoad','Plugin',Plugin='UsageMonitor',Alias='GPU',Index=0)
    for i in range(1, 4):
        gpu += measure(f'GPUProc{i}','Plugin',Plugin='UsageMonitor',Alias='GPU',Index=i)
    gpu += measure('GPUShared','Plugin',Plugin='UsageMonitor',Category='GPU Adapter Memory',Counter='Shared Usage',Index=0)
    gpu += measure('GPUDedicated','Plugin',Plugin='UsageMonitor',Category='GPU Adapter Memory',Counter='Dedicated Usage',Index=0)
    gpu += measure('GPUName','Registry',RegHKey='HKEY_LOCAL_MACHINE',
        RegKey=r'SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000',
        RegValue='DriverDesc',UpdateDivider=300)
    # Open-Meteo (free, no key). WebParser keeps the whole JSON; Widget.lua parses it.
    weather = measure('WeatherData','WebParser',
        URL='https://api.open-meteo.com/v1/forecast?latitude=#WeatherLatitude#&longitude=#WeatherLongitude#'
            '&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day'
            '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
            '&timezone=auto&forecast_days=4&temperature_unit=#WeatherTempUnit#&wind_speed_unit=#WeatherWindUnit#',
        RegExp='(?siU)^(.*)$',StringIndex=1,UpdateRate=900,Codepage=65001,
        Disabled='(1-#WeatherEnabled#)')
    # Location search for Weather and Sun & Moon: a text box, then an Open-Meteo geocoding
    # request that stays disabled until the user submits a search (Widget.lua sets its URL).
    location = measure('LocationInput','Plugin',Plugin='InputText',
        X='(24*#Scale#)',Y='(44*#Scale#)',W='((#Width#-48)*#Scale#)',H='(30*#Scale#)',
        FontFace='#Font#',FontSize='(11*#Scale#)',SolidColor='40,40,40,255',FontColor='255,255,255',
        FocusDismiss=1,DynamicVariables=1,
        Command1='''[!CommandMeasure MeasureRenderer "SearchLocation([[$UserInput$]])"] DefaultValue="#WeatherCity#"''')
    location += measure('GeoSearch','WebParser',URL='https://geocoding-api.open-meteo.com/v1/search?name=',
        RegExp='(?siU)^(.*)$',StringIndex=1,UpdateRate=86400,Codepage=65001,Disabled=1,DynamicVariables=1,
        FinishAction='[!CommandMeasure MeasureRenderer "GeoDone()"]',
        OnConnectErrorAction='[!CommandMeasure MeasureRenderer "GeoFailed()"]',
        OnRegExpErrorAction='[!CommandMeasure MeasureRenderer "GeoDone()"]')
    weather += location
    # Countdown edits its title and date in place with the bundled InputText plugin.
    countdown = measure('CountdownInput','Plugin',Plugin='InputText',
        X='(24*#Scale#)',Y='(44*#Scale#)',W='((#Width#-48)*#Scale#)',H='(30*#Scale#)',
        FontFace='#Font#',FontSize='(11*#Scale#)',SolidColor='40,40,40,255',FontColor='255,255,255',
        FocusDismiss=1,DynamicVariables=1,
        Command1='''[!CommandMeasure MeasureRenderer "SetCountdown('title',[[$UserInput$]])"] DefaultValue="#CountdownTitle#"''',
        Command2='''[!CommandMeasure MeasureRenderer "SetCountdown('date',[[$UserInput$]])"] DefaultValue="#CountdownDate#"''')
    # Status Bar: the few readings it shows, from the same native measures as the full cards.
    statusbar = battery + network + measure('CPU','CPU',Processor=0)
    statusbar += measure('RAM','PhysicalMemory') + measure('RAMTotal','PhysicalMemory',Total=1)
    statusbar += measure('Ping','Plugin',Plugin='PingPlugin',DestAddress='#PingHost#',UpdateRate=5)
    # Defaults that a user's older Settings.inc may lack; the Settings.inc include overrides them.
    defaults = {'Weather': 'WeatherEnabled=0\nWeatherLatitude=0\nWeatherLongitude=0\nWeatherCity=\n'
                           'WeatherTempUnit=celsius\nWeatherWindUnit=kmh\nWeatherWidth=340\n',
                'Countdown': 'CountdownTitle=New Year\nCountdownDate=2027-01-01 00:00\nCountdownFrom=\nCountdownWidth=340\n',
                'Focus': 'FocusWidth=340\n','GPU': 'GPUWidth=340\n','Calendar': 'CalendarWidth=340\nWeekStart=Mon\n','Clock': 'WeekStart=Mon\n',
                'Processes': 'ProcessesWidth=340\n','DiskIO': 'DiskIOWidth=340\n','Binary': 'BinaryWidth=340\n','Battery': 'BatteryRange=360\n',
                'Progress': 'ProgressWidth=340\nWeekStart=Mon\n','Analog': 'AnalogWidth=340\nAnalogSeconds=1\n',
                'SunMoon': 'SunMoonWidth=340\nWeatherLatitude=0\nWeatherLongitude=0\nWeatherCity=\n',
                'StatusBar': 'StatusBarWidth=800\nPingHost=1.1.1.1\nNetworkInterface=Best\n'}
    variants = [('Battery','Battery',500,280,battery),('Battery','Compact',360,168,battery),
                ('Network','Network',340,230,network),('Network','NetworkCompact',340,150,network),
                ('Vitals','Vitals',340,270,vitals),('Vitals','VitalsCompact',340,140,vitals),
                ('Clock','Clock',340,220,''),('Clock','ClockCompact',340,120,''),('Shortcuts','Shortcuts',500,136,''),
                ('Audio','Audio',340,190,audio),('Spectrum','Spectrum',340,220,spectrum),
                ('Cores','Cores',340,260,cores),('Cores','CoresRings',340,260,cores),('SysInfo','SysInfo',340,260,sysinfo),
                ('Diagnostics','Diagnostics',340,280,diagnostics),('Diagnostics','DiagnosticsCompact',340,140,diagnostics),
                ('Calendar','Calendar',340,300,''),('Calendar','CalendarWeek',340,160,''),('Processes','Processes',340,330,processes),('Processes','ProcessesMap',340,330,processes),
                ('DiskIO','DiskIO',340,300,diskio),('DiskIO','DiskIODrives',340,200,diskio),('Binary','Binary',340,270,''),('Binary','Compact',340,210,''),('GPU','GPU',340,330,gpu),('GPU','GPUCompact',340,120,gpu),('Focus','Focus',340,262,''),('Focus','FocusCompact',340,140,''),
                ('Countdown','Countdown',340,250,countdown),('Countdown','CountdownCompact',340,130,countdown),
                ('Weather','Weather',340,330,weather),('Weather','WeatherCompact',340,130,weather),
                ('Progress','Progress',340,270,''),('SunMoon','SunMoon',340,330,location),
                ('Analog','Analog',340,260,''),('StatusBar','StatusBar',800,46,statusbar),
                ('Settings','Settings',500,642,'')]
    # Rainmeter.ini records the loaded skin by its index in the folder's sorted file list,
    # so a new variant's file must sort after the existing ones (Vitals.ini < VitalsCompact.ini).
    for kind, name, width, height, measures in variants:
        variant = 'Compact' if name.endswith('Compact') else name
        w = str(width) if kind == 'Settings' or (kind, name) == ('Battery', 'Compact') else f'#{kind}Width#'
        events='''LeftMouseUpAction=[!CommandMeasure MeasureRenderer "EndDrag()"]
MouseLeaveAction=[!CommandMeasure MeasureRenderer "EndDrag()"]
OnCloseAction=[!CommandMeasure MeasureRenderer "EndDrag()"]
''' if kind=='Settings' else ''
        slider_include='@IncludeSliders=#@#Sliders.inc' if kind=='Settings' else ''
        update_override = 'Update=40\n' if kind == 'Spectrum' else ''
        extra_vars = 'CoreCount=%NUMBER_OF_PROCESSORS%\n' if kind == 'Cores' else ''
        write(SKIN / kind / f'{name}.ini', f'''[Rainmeter]
@Include=#@#Common.inc
{update_override}{events}
[Variables]
{defaults.get(kind, '')}@Include=#@#Settings.inc
Kind={kind}
Variant={variant}
Width={w}
Height={height}
{extra_vars}
{measures}
@IncludeMeters=#@#Meters.inc
{slider_include}
''')
        # Include directives belong in a section. The last measure section is fine;
        # for skins with no native measures the directive is in Variables.
    (RES / 'Data').mkdir(parents=True, exist_ok=True)
    (RES / 'Data' / '.keep').touch()
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    with zipfile.ZipFile(dist / 'NerdWidgets-1.0.0.zip','w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(SKIN.rglob('*')):
            if p.is_file() and p.suffix not in ('.tsv','.tmp'):
                z.write(p,p.relative_to(ROOT).as_posix())
        for name in ['README.md','Install.ps1']:
            if (ROOT / name).exists():
                z.write(ROOT / name,name)
    # The 16-byte footer follows Rainmeter's DialogInstall::PackageFooter.
    # Reference: rainmeter/rainmeter Library/DialogPackage.cpp, DialogInstall.h.
    package=dist/'NerdWidgets-1.0.0.rmskin'
    manifest='''[rmskin]
Name=Nerd Widgets for Windows
Author=Ranjith
Version=1.0.0
LoadType=Skin
Load=NerdWidgets\\Settings\\Settings.ini
MinimumRainmeter=4.5.20
VariableFiles=NerdWidgets\\@Resources\\Settings.inc
'''
    with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('RMSKIN.ini',manifest.encode('utf-16'))
        for p in sorted(SKIN.rglob('*')):
            if p.is_file() and p.suffix not in ('.tsv','.tmp'):
                z.write(p,'Skins/'+p.relative_to(ROOT).as_posix())
    size=package.stat().st_size
    with package.open('ab') as f:
        f.write(struct.pack('<qB7s',size,0,b'RMSKIN\x00'))
    with zipfile.ZipFile(package) as z:
        assert z.testzip() is None
        assert 'Skins/NerdWidgets/Settings/Settings.ini' in z.namelist()
        assert not any(n.endswith(('.tsv','.tmp')) for n in z.namelist())
    print(f'Generated {len(variants)} skins; ZIP and RMSKIN packages in dist/')


if __name__ == '__main__':
    main()
