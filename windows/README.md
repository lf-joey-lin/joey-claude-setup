# Windows integrations

Machine-level Windows tweaks that aren't symlinked into `~/.claude`. Apply them by hand; they don't come from `bootstrap.ps1`.

## "Start claude here" context menu

Adds a right-click Explorer entry that opens Windows Terminal in the clicked folder and runs `claude`. It shows up two places:

- right-click on a folder
- right-click on the empty background inside an open folder

Per-user (`HKCU\Software\Classes`), so no admin prompt. On Windows 11 it lands in the "Show more options" menu (Shift+F10), not the top-level menu. The top-level menu needs a packaged `IExplorerCommand` shell extension, which isn't worth it for this.

The command it registers:

```
cmd /c start "" wt.exe -d "%V" claude
```

`%V` is the folder path. The `cmd /c start ""` wrapper resolves `wt.exe` through the shell (Windows Terminal is a WindowsApps execution alias, so a bare full path to it can fail) and leaves no console window behind.

### Install

Double-click `start-claude-here.reg`, or:

```powershell
reg import "C:\code2\joey-claude-setup\windows\start-claude-here.reg"
```

No sign-out or restart needed. The entry works on the next right-click.

### Uninstall

Double-click `uninstall-start-claude-here.reg`, or:

```powershell
reg import "C:\code2\joey-claude-setup\windows\uninstall-start-claude-here.reg"
```

### Notes

- Both `.reg` files hardcode `claude.exe` at `C:\Users\joey.lin\.local\bin\`. On a different machine or user, fix that path (it only supplies the menu icon; the actual launch calls `claude` off PATH).
- To open a plain PowerShell window instead of Windows Terminal, replace the `command` value with:
  `powershell.exe -NoExit -Command "Set-Location -LiteralPath '%V'; claude"`
