# proj

Open any project from the terminal with one word.

```
C:\> mygame
```

That `cd`s into your project folder and starts [Claude Code](https://claude.com/claude-code) there (or any command you choose). `proj` is the tool that creates and manages those one-word shortcuts.

Works on Windows in **cmd**, **PowerShell 7**, and **Windows PowerShell 5.1**. No dependencies.

---

## Install

You need [Git](https://git-scm.com/download/win), or you can download the ZIP instead.

**Option A: with Git**

```powershell
git clone https://github.com/ocauapaz/proj.git "$HOME\proj"
powershell -ExecutionPolicy Bypass -File "$HOME\proj\install.ps1"
```

**Option B: without Git**

1. On this page, click **Code → Download ZIP**.
2. Extract it somewhere permanent, e.g. `C:\Users\<you>\proj`. Do not leave it in Downloads: the `proj` command runs the files from this folder.
3. Open PowerShell in that folder and run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

**Then close the terminal and open a new one.** The install adds a folder to your PATH, and terminals that were already open don't see it.

Check that it works:

```
proj
```

You should see the help text.

---

## Quick start

```
proj add mygame
```

This creates the folder `C:\Users\<you>\projects\mygame` (if it doesn't exist) and a new command called `mygame`. Now, from any terminal:

```
mygame          → opens Claude Code in C:\Users\<you>\projects\mygame
mygame -c       → same, continuing your last conversation (extra arguments go to claude)
mygame --kade   → opens the project in KADE instead of the terminal
```

`--kade` needs [KADE](https://github.com/ocauapaz/kade) installed. It looks for `%LOCALAPPDATA%\KADE\kade.exe`, then `kade.exe` on your PATH; set `KADE_EXE` to point anywhere else. If KADE is already open, the project opens in the same window. Your `proj` shortcuts also show up in KADE's project list on their own.

Shortcuts created before `--kade` existed can be upgraded with:

```
proj sync
```

---

## Creating shortcuts

```
proj add <name> [folder]
```

| Command | Shortcut opens |
|---|---|
| `proj add mygame` | `<default base>\mygame` |
| `proj add mygame "My Game"` | `<default base>\My Game` |
| `proj add mygame -w` | `<base w>\mygame` |
| `proj add mygame -w "My Game"` | `<base w>\My Game` |
| `proj add mygame "D:\Somewhere\Else"` | exactly that folder |
| `proj add mygame .` | the folder you're in right now |

- The **name** is what you'll type to open the project. Letters, digits, `-` and `_` only. It can't be the name of a command that already exists (like `git` or `node`).
- If the folder doesn't exist, it's created.
- The default base is `C:\Users\<you>\projects` until you change it (see below).

List and remove shortcuts:

```
proj list          show all shortcuts and their folders
proj rm mygame     delete the shortcut (your project folder is never touched)
```

---

## Bases: your own folder flags

A **base** is a folder where you keep projects, with a short name you choose. That name becomes a flag for `proj add`.

### Create a base

```
proj base add <name> <folder>
```

Example: you keep work projects in `D:\Work` and game projects in `E:\Games\Dev`.

```
proj base add work "D:\Work"
proj base add g "E:\Games\Dev"
```

Now `-work` means `D:\Work` and `-g` means `E:\Games\Dev`:

```
proj add api -work           → D:\Work\api
proj add shooter -g          → E:\Games\Dev\shooter
proj add shop -g "Shop V2"   → E:\Games\Dev\Shop V2
```

The name is up to you: `k`, `work`, `p1`, anything with letters and digits. The folder must already exist.

### Manage bases

```
proj base                    list your bases (the default is marked)
proj base add g "E:\Other"   running add again with the same name changes its folder
proj base rm g               delete a base (projects and shortcuts are not touched)
```

### Change the default base

The default base is used when `proj add` gets no flag and no full path.

```
proj base default g      proj add x  →  E:\Games\Dev\x
proj base default off    proj add x  →  C:\Users\<you>\projects\x
```

---

## Configuration

Everything `proj` stores is in `C:\Users\<you>\.proj`, separate from the code:

| File | What it holds |
|---|---|
| `config.json` | your bases, the default base, and the command shortcuts run |
| `bin\` | `proj.bat` and one `.bat` file per shortcut |

`config.json` looks like this and can be edited by hand:

```json
{
  "command": "claude",
  "default": "g",
  "bases": {
    "work": "D:\\Work",
    "g": "E:\\Games\\Dev"
  }
}
```

**`command`** is what every new shortcut runs. Change it to `code .` to open VS Code instead, or to anything else. Existing shortcuts keep the command they were created with. Recreate them (`proj rm x`, then `proj add x ...`) to pick up a new one.

To keep this data somewhere else, set the `PROJ_HOME` environment variable before installing.

---

## Troubleshooting

**`'proj' is not recognized`**
Open a *new* terminal after installing. If it still fails, check that `C:\Users\<you>\.proj\bin` is in your user PATH (Start → "Edit environment variables for your account" → Path).

**`'mygame' is already a command`**
Something on your PATH already uses that name. Pick another name.

**The shortcut opens but `claude` is not found**
Install [Claude Code](https://claude.com/claude-code), or change `command` in `config.json` to another program.

---

## Update

```powershell
cd "$HOME\proj"
git pull
```

Your bases and shortcuts are kept, since they live in `.proj`, not in the repo. If you used the ZIP, download it again and replace the folder.

## Uninstall

1. Delete `C:\Users\<you>\.proj` (this removes all shortcuts and bases).
2. Remove `C:\Users\<you>\.proj\bin` from your user PATH.
3. Delete the folder where you cloned or extracted `proj`.

## Tests

```powershell
pwsh -File test.ps1
```

## License

MIT
