[Variables]
; Shared appearance. Use the Settings skin, or edit and refresh all skins.
; Style: Expressive (palette surfaces, Dark or Light), Blacks (dark greys, palette accents) or Instrument (phone lab look: navy, dot-matrix numbers, segmented bars).
Style=Expressive
Theme=Dark
Palette=Sage
Scale=1
; Independent font multipliers. Widget size: 0.25-1.50; text: 0.70-1.50; numbers: 0.50-1.50.
TextScale=1
NumberScale=1
Radius=28
Opacity=255
Font=JetBrains Mono
NumberFont=JetBrains Mono
BatteryWidth=340
NetworkWidth=340
VitalsWidth=340
ClockWidth=340
ShortcutsWidth=500
DiagnosticsWidth=340
SpectrumWidth=340
CoresWidth=340
SysInfoWidth=340
AudioWidth=340
CalendarWidth=340
ProcessesWidth=340
DiskIOWidth=340
BinaryWidth=340
GPUWidth=340
FocusWidth=340
CountdownWidth=340
WeatherWidth=340
ProgressWidth=340
SunMoonWidth=340
AnalogWidth=340
StatusBarWidth=800
PingHost=1.1.1.1
; Best follows the active adapter; you may use an adapter alias such as Wi-Fi.
NetworkInterface=Best
Disk=C:
; Focus Timer minutes: work, short break, long break (after every 4th session).
FocusWork=25
FocusBreak=5
FocusLongBreak=15
; Play a sound when a focus or break period ends (1 = on).
FocusSound=1
; Countdown: title and target (YYYY-MM-DD HH:MM). Click either on the card to edit it.
; CountdownFrom is set automatically when the date changes and drives the progress bar.
CountdownTitle=New Year
CountdownDate=2027-01-01 00:00
CountdownFrom=
; Weather from Open-Meteo (free, no account). Your coordinates are sent to api.open-meteo.com
; about every 15 minutes while the card is loaded. Set WeatherEnabled=1 once coordinates are set.
WeatherEnabled=0
WeatherCity=
WeatherLatitude=0
WeatherLongitude=0
; celsius + kmh, or fahrenheit + mph
WeatherTempUnit=celsius
WeatherWindUnit=kmh
; Sun & Moon reuses WeatherLatitude/WeatherLongitude; sun times are computed locally (no download).
; Analog Clock: 1 shows a second hand and a ring that sweeps each minute; 0 sweeps each hour.
AnalogSeconds=1
; First day of the week for Calendar, Day Progress and Clock: Mon or Sun.
; Clicking the weekday letters on the Calendar card switches it.
WeekStart=Mon
; Battery graph range in minutes: 30, 60, 180, 360, 720, 1080 or 1440. Click the range
; buttons under the graph to change it. A full day of history is kept, sampled
; once a minute while a Battery variant is loaded.
BatteryRange=360
; 1 zooms the battery level axis to the visible data; click the graph to switch.
BatteryAutoScale=0
