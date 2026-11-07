# NerdWidgets (Rainmeter)

## Push to Rainmeter

When the user says **"push to Rainmeter"**, copy the current source into their live Rainmeter skin folder:

- Target: `C:\Users\Ranjith Jayadevan\Documents\Rainmeter\Skins\NerdWidgets`
- Command (from the project root):

  ```powershell
  .\Install.ps1 -SkinPath "C:\Users\Ranjith Jayadevan\Documents\Rainmeter\Skins"
  ```

`Install.ps1` backs up the existing install to `Documents\Rainmeter\NerdWidgets-Backups\<timestamp>`, keeps the user's `@Resources\Settings.inc` and `@Resources\Data\` (battery history), copies everything else, then refreshes the installed Rainmeter (`C:\Program Files\Rainmeter\Rainmeter.exe`).

Before pushing, run `python tools/build.py` if `tools/build.py` changed. If a new `Settings.inc` variable was added, tell the user: the installer keeps their existing `Settings.inc`, so the new key is not copied over.

## Workflow notes

- `tools/build.py` generates `Common.inc`, `Meters.inc`, `Sliders.inc`, every skin `.ini` (UTF-16) and `dist/`. Edit `build.py`, not those generated files. `Settings.inc` is edited by hand.
- Tests: copy `NerdWidgets` to `.tools/TestSkins/NerdWidgets` (leave out `*.tsv`/`*.tmp`), then start the portable `.tools/Rainmeter/Rainmeter.exe`, which loads `ModelTests`. The result goes to `.tools/test-result.txt`. Afterwards, stop only that portable process, not the installed Rainmeter.
- `ModelTests.lua` loads `Model.lua`/`Widget.lua` from the source `NerdWidgets` folder (the `Source` variable), not from the test copy. The test copy matters only for live captures.
- If you edit a Lua file from PowerShell, write UTF-8 without a BOM; Rainmeter's Lua fails on a BOM.
- To check the user's real desktop, mirror it: copy the live `Settings.inc` and the `[NerdWidgets\…]` positions from `%APPDATA%\Rainmeter\Rainmeter.ini` into the portable instance, then screen-capture. Their live skins are not topmost, so they can be hidden behind other windows.
