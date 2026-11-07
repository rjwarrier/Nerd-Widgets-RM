# Validation · 6 November 2026

- Loaded Battery, Network, Vitals, Clock, Shortcuts, and Settings in an isolated portable **Rainmeter 4.5.28.3936, 64-bit** instance on Windows 11.
- Inspected native renders in Sage/dark and Peach/light, including the appearance controls. Corrected Lua-to-Rainmeter Unicode conversion and a missing display glyph found during visual inspection.
- Ran `tools/ModelTests.lua` in Rainmeter's embedded Lua 5.1 runtime: **29,969 assertions passed across 504 renderer combinations**, including Compact, dark/light, 75/100/150% scale, narrow/default/wide dimensions, and normal/charging/no-battery/unknown flags.
- Verified explicit unavailable estimates, a measured 0%, AC without charging, history cadence/pruning, encoded Unicode text, and vertical text bounds. Mock inputs were confined to tests and never written to the production history.
- Loaded real Power, CPU, memory, disk, uptime, and network measures with no skin errors in the log. Reopening an already loaded Settings card produces Rainmeter's benign “already active” notice/warning.
- Checked the ZIP/RMSKIN archive entries and CRCs, manifest, footer, required entry point, and exclusion of test/history files. RMSKIN packaging follows the official source format. A full installed-package round trip was not performed; native skins were loaded from the isolated test copy.
- Exercised the PowerShell installer in a workspace-only destination, including `-WhatIf`, fresh install, reinstall, backup creation, and preservation of existing settings and history.
- `previews/NerdWidgets-preview.png` contains isolated captures of the actual live skins. Desktop content outside each rounded widget has been clipped away. The numbers shown are observations from that preview session.

Hardware-dependent Windows battery estimates and charging/discharging transitions were covered with controlled model inputs; this session's physical laptop was fully charged on AC. Sensor support on other computers and Windows 10 were not directly tested.

## JetBrains Mono update

Bundled the original project's JetBrains Mono Regular font and OFL license; updated text and number defaults in the source, packages, and running preview while preserving its theme, palette, size, and corners. Small reading chips reduce their font size when needed to fit monospace values. The 504 renderer combinations passed again, and archive checks confirmed the font, license, and updated defaults. Live screenshot capture returned black images during this update, so `previews/` still shows the earlier typography.

## Nerd Widgets expansion · 5 new widgets

- Added 5 new developer and power-user widgets: **Audio Controls**, **Audio Spectrum (16-band FFT)**, **CPU Core Heatmap**, **System Specifications**, and **Network Diagnostics**.
- Expanded `tools/ModelTests.lua` to test all 12 skin entries and new data rules: **52,152 assertions passed across 864 renderer combinations**.
- Tested live in Rainmeter 4.5.28: all 5 new widgets initialized, rendered, and deactivated with zero errors or warnings in `Rainmeter.log`.
- Verified live launch controls from the expanded Settings card launcher matrix (`ADD TO DESKTOP`).
- Rebuilt `dist/NerdWidgets-1.0.0.zip` and binary `.rmskin` packages containing all 12 entry points.
