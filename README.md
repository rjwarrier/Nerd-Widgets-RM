# Nerd Widgets Â· Windows

A native Rainmeter adaptation of the **original BatteryWidget / Nerd Widgets** design: Material-inspired color roles, large numerals, rounded cards, compact reading chips, and shared appearance controls. Built from the current `BatteryWidget.kt`, `Style.kt`, and `widget.xml` design conventions, with Windows-specific data and actions.

## Install

1. Install [Rainmeter](https://www.rainmeter.net/) 4.5.20 or newer on Windows 10/11.
2. Double-click **dist/NerdWidgets-1.0.0.rmskin**, then choose Install. The suite's Settings card opens.
3. Click any widget under **Add to desktop** to load its card. Drag cards to arrange them.
4. Click **â€¢â€¢â€¢** on any card for appearance controls. Right-click a card for Rainmeter options, including position, transparency, and unloading.

The ZIP is an alternative: extract it, then copy its `NerdWidgets` folder into your Rainmeter **Skins** folder and choose **Refresh all** in Rainmeter. Load `NerdWidgets/Settings/Settings.ini`.

`Install.ps1` is an optional installer for the ZIP or source checkout. It detects the configured skin path, backs up an existing suite, and preserves settings and history. It supports `-WhatIf`, `-SkinPath`, and `-RainmeterExe`. No administrator access is needed for the usual per-user skins folder.

## Included widgets

| Widget | What it does |
| --- | --- |
| **Battery** | Battery percentage, charging / plugged-in state, Windows time-left estimate when available, six-hour level history, and change since this observation session began. Click the percentage to open Windows battery settings. |
| **Battery Â· Compact** | A smaller battery card without the graph. Load **Battery Mini** from Settings, or select `Compact.ini` instead of `Battery.ini` in Rainmeter Manage. These are variants of the same widget. |
| **Network Pulse** | Download and upload rates for the active adapter; a shared-scale 60-second graph. Includes LAN traffic, not just internet traffic. |
| **Network Pulse · Compact** | Both rates on one row over a short graph. Load **Network Mini** from Settings, or `NetworkCompact.ini` in Rainmeter Manage; it replaces the full card. |
| **System Vitals** | CPU and RAM rings, disk free space / used-space bar, system uptime, and a Task Manager shortcut. |
| **System Vitals · Compact** | CPU, memory, and disk use side by side, each over a bar. Load **Vitals Mini**, or `VitalsCompact.ini`. |
| **Clock** | Local Windows time, date, and weekday markers. |
| **Clock · Compact** | The time with the weekday and date beside it. Load **Clock Mini**, or `ClockCompact.ini`. |
| **Analog Clock** | A clock face with hour, minute, and second hands; the outer ring sweeps once a minute. Set `AnalogSeconds=0` for no second hand and a ring that sweeps once an hour. |
| **Quick Shortcuts** | Wi-Fi, Bluetooth, sound, display, File Explorer, and Windows Settings launchers. These open the corresponding screens; they do not pretend to be hardware toggles. |
| **Audio Controls** | Master volume percentage, active playback device name, mute toggle, volume adjustment buttons, and sound settings shortcut. |
| **Audio Spectrum** | Real-time 16-band FFT equalizer visualizer reacting to live system audio with left/right peak decibel meters. |
| **CPU Core Heatmap** | Total processor usage plus per-thread load for up to 32 logical threads: labelled mini-bars for 16 or fewer, a shaded 8-column tile grid above that. |
| **System Specifications** | Exact processor model, Windows edition, release & build number, machine hostname, and commit charge / pagefile ratio. |
| **Network Diagnostics** | Real-time ICMP ping latency with 60-second sparkline, internet status, local IP, gateway, subnet mask, and DNS server. |
| **Calendar** | Monday-first month grid with today highlighted, weekends in the secondary color, ISO week and day of year. Use â€¹ â€º to browse months; click the month or **Today** to return. |
| **Top Processes** | Top five processes by CPU (percent of all logical processors) and by private memory, rolled up by process name, with load bars. Uses Rainmeter's bundled UsageMonitor plugin. |
| **Disk I/O** | Read and write throughput across all physical disks with a shared-scale 60-second graph, plus free space for up to four fixed drives (C:â€“J:, detected automatically). |
| **Binary Clock** | Hours, minutes, and seconds as binary-coded decimal dots with decimal digits beneath, plus Unix epoch, hex epoch, UTC, and ISO week/day. |
| **Binary Clock Â· Compact** | The same dots and digits without the reading cards. Load **Binary Mini** from Settings, or `Compact.ini` in Rainmeter Manage; it replaces the full Binary Clock. |
| **GPU Monitor** | Total GPU load across all engines with a 60-second graph, adapter name, dedicated and shared video memory, and the top three GPU processes. Uses Rainmeter's bundled UsageMonitor plugin; integrated GPUs show no dedicated memory. |
| **Focus Timer** | A Pomodoro timer: 25-minute focus periods, 5-minute short breaks, and a 15-minute long break after every fourth session, with start/pause, reset, and skip. Progress ring, sessions completed today, and an optional chime. State is saved in `@Resources/Data/focus.tsv`, so refreshing the suite does not reset a running timer. Durations and the chime are set with `FocusWork`, `FocusBreak`, `FocusLongBreak`, and `FocusSound` in `Settings.inc`. |
| **Countdown** | Days, hours, minutes, and seconds to a date you choose, with a progress bar from when you set it. Click the title or the date on the card to edit it in place. |
| **Weather** | Current temperature, conditions with a drawn icon, feels-like, humidity, wind, and a three-day forecast from [Open-Meteo](https://open-meteo.com/) (free, no account). Your coordinates are sent to Open-Meteo about every 15 minutes while the card is loaded; it is off until you choose a location. Click **Search for your city** (or **Change location**), type a place name, press Enter, and pick the right match. The search uses Open-Meteo's geocoding service and fills in `WeatherLatitude`, `WeatherLongitude`, and `WeatherCity` for you. |
| **Day Progress** | How much of today has passed, time left until midnight, and progress bars for the week (Monday first), month, and year. |
| **Sun & Moon** | Sunrise, sunset, and day length, with the sun's position on a day arc, plus the moon phase, illumination, and next full and new moon. Sun times are calculated on your PC from `WeatherLatitude` and `WeatherLongitude` (Weather does not need to be on); set them with **Search for your city** on the card, which shares the Weather card's location. Only the place search itself goes online. The moon needs no location. |
| **Status Bar** | One thin, wide row for a screen edge: time, date, CPU, RAM, download, upload, battery, and ping. Set `StatusBarWidth` (320–1920); segments that do not fit are dropped, least important first. |
| **Settings** | A compact 500-pixel-wide card: Expressive, Blacks, or Instrument style; light/dark theme (Expressive); square, soft, or round corners; eight palettes (Sage, Lavender, Blue, Peach, Teal, Rose, Amber, Slate); widget, label, and large-number size sliders with clickable 25â€“150% presets under the size slider; and launch buttons for every widget. |

## Appearance

Settings are shared across the suite in `NerdWidgets/@Resources/Settings.inc`. The settings card saves each choice immediately and refreshes only this suite. Its own size stays fixed so that controls remain usable.

Two design styles are available. **Expressive** (the default) tints every surface with the chosen palette and has Dark and Light themes. **Blacks** uses neutral dark-grey surfaces, keeps the palette's colors only for accents (numbers, rings, graphs, selected buttons), and is always dark, so the Theme buttons are disabled while it is selected. **Instrument** brings the Android Nerd Widgets "lab" look to every card: navy surfaces, the phone's 5Ã—7 dot-matrix numerals for large readings, segmented progress bars, outlined gridded graphs, LED-segment spectrum bars, and a zero-padded calendar with today boxed and neighbouring months dimmed. With the Blue palette it uses the exact colors sampled from the phone widgets; the other palettes give the same structure in their own hue. Theme is disabled while it is selected. The setting is `Style=Expressive`, `Style=Blacks`, or `Style=Instrument`.

Three sliders control sizing independently, in 5% steps: **Widget size** (`Scale`, 25â€“150%) resizes whole cards; **Labels and readings** (`TextScale`, 70â€“150%) and **Large numbers** (`NumberScale`, 50â€“150%) resize text within them. Drag or click a slider, scroll over it to nudge by one step, or right-click to reset it to 100%. Slider changes preview live across all loaded cards and are saved when you release. The 25 Â· 50 Â· 75 Â· 100 Â· 125 Â· 150 labels under the size slider are clickable shortcuts for `Scale`.

Advanced settings include font, number font, background opacity (30â€“255), card widths, disk drive, network adapter, and battery history span (1â€“24 hours). Edit this file and choose **Refresh this suite** from a card's right-click menu. **JetBrains Mono** is the default for both text and numbers and is bundled in `@Resources/Fonts` with its SIL Open Font License; no system font installation is required. You may also use installed Windows font family names. Shortcut glyphs retain their icon font. Widths are bounded between 320 and 800 design pixels, or 440â€“800 for the full Battery card. Height is intentionally fixed for each variant; width changes redistribute content rather than stretching the whole card. `Scale` controls the overall size. The compact battery variant is 360Ã—168 before scaling.

The palettes use explicit Material-style colors. Automatic wallpaper-derived Android Material You palettes and the Android configuration activity are not part of this port.

## Readings and platform limits

- Uses Rainmeter's bundled [Power plugin](https://docs.rainmeter.net/manual/plugins/power/), CPU, memory, disk, uptime, and [network measures](https://docs.rainmeter.net/manual/measures/net/). No third-party plugins, credentials, or background PowerShell polling. The Weather card is the only one that contacts an online service (Open-Meteo), and only once you enable it.
- Battery information depends on Windows and the device firmware. **No battery**, **unavailable**, **plugged in**, **charging**, and **fully charged** are distinct. Plugged in does not necessarily mean charging.
- Time left is labeled an estimate and shown only when Windows supplies a valid discharge estimate. No fabricated charging ETA, health, temperature, watts, or cycle count is displayed.
- Battery history is sampled once per minute while a Battery variant is loaded and saved locally in `@Resources/Data/battery.tsv`. Only readings actually observed are graphed. Missing intervals remain gaps. At most 24 hours / 1,441 samples are kept. It is not a reconstruction of Windows battery history.
- The delta and observed duration restart when the card refreshes or the power source changes. Network graphs reset on refresh and cover the last 60 seconds. Rates use binary KiB/s and MiB/s.
- Health Connect, steps, Android app usage, Shizuku controls, Pixel charge limits, and phone-specific telemetry have no direct equivalent in this suite. CPU/GPU thermal monitoring would need a supported external sensor integration.
- All cards are separate, draggable Rainmeter skins. Windows 10/11 settings URIs open their corresponding OS pages; exact page availability varies by Windows release.

## Development and validation

Run `python tools/build.py` to regenerate the twenty-one INI entry points, shared meter definitions, ZIP, and valid RMSKIN package. The RMSKIN footer follows Rainmeter's own [package writer](https://github.com/rainmeter/rainmeter/blob/master/Library/DialogPackage.cpp) and [footer structure](https://github.com/rainmeter/rainmeter/blob/master/Library/DialogInstall.h). Packages exclude locally recorded history.

`tools/ModelTests.lua` runs in Rainmeter's real Lua 5.1 engine. It checks battery state/unknown values, unavailable estimates, measured zero, history cadence/pruning, Unicode encoding, and renderer bounds over multiple themes, scales, widths, and device states. `python tools/prepare_tests.py` creates a test skin under `.tools/TestSkins/ModelTests`; load it in an isolated Rainmeter instance configured for that skin path. Results are written to `.tools/test-result.txt` and Rainmeter's log.

The `.tools` directory is a local validation environment, not part of either distribution. It contains the portable Rainmeter runtime and test copies; the distributable source is `NerdWidgets`.
