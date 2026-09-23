# proj

Terminal shortcuts for opening projects on Windows. `proj add mygame` creates the command `mygame`, which `cd`s into `%USERPROFILE%\projects\mygame` and runs `claude` there. Arguments pass through: `mygame -c` becomes `claude -c`.

Works in cmd, PowerShell 7, and Windows PowerShell 5.1.

## Install

```powershell
git clone <repo-url> proj
cd proj
powershell -ExecutionPolicy Bypass -File install.ps1
```

Open a new terminal and run `proj`.

## Shortcuts

```
proj add mygame              # %USERPROFILE%\projects\mygame
proj add mygame "My Game"    # %USERPROFILE%\projects\My Game
proj add x "D:\anywhere"     # a full path skips the base
proj add x .                 # current folder
proj list
proj rm mygame               # removes only the shortcut, never the project folder
```

Missing project folders are created.

## Bases

A base is a folder where projects live. Its key becomes a flag for `add`. Everyone sets up their own.

```
proj base add r "E:\Roblox Projects"
proj add mrm -r MRM          # E:\Roblox Projects\MRM
proj base                    # list
proj base default r          # use -r when add has no flag
proj base default off        # back to %USERPROFILE%\projects
proj base rm r
```

## Configuration

Everything lives in `%USERPROFILE%\.proj`, outside the repo:

- `config.json`: bases, the default base, and the command shortcuts run (`"command": "claude"`; change it to `code .`, for example).
- `bin\`: `proj.bat` and your shortcuts. `install.ps1` puts this folder at the front of the user PATH.

Set `PROJ_HOME` before installing to use a different location.

## Tests

```powershell
pwsh -File test.ps1
```

## Uninstall

Delete `%USERPROFILE%\.proj` and remove `%USERPROFILE%\.proj\bin` from the user PATH.
