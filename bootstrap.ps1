# Recreate the ~/.claude -> repo symlinks on a fresh machine.
# Requires Windows Developer Mode (or an elevated shell) so New-Item can make symlinks.
# Usage: pwsh -File bootstrap.ps1

$repo = $PSScriptRoot
$cl   = Join-Path $env:USERPROFILE ".claude"
$items = "CLAUDE.md", "settings.json", "statusline.js", "joey-writing-style.md", "skills"

if (-not (Test-Path $cl)) { New-Item -ItemType Directory -Force $cl | Out-Null }

foreach ($i in $items) {
    $link   = Join-Path $cl $i
    $target = Join-Path $repo $i

    if (Test-Path $link) {
        $existing = Get-Item -Force $link
        if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -eq $target) {
            Write-Host "ok     $i"
            continue
        }
        # A real file or dir is in the way. Move it aside rather than clobber it.
        Move-Item $link "$link.pre-bootstrap" -Force
        Write-Host "aside  $i -> $i.pre-bootstrap"
    }

    New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
    Write-Host "linked $i"
}

Write-Host ""
Write-Host "Done. If anything was moved aside as *.pre-bootstrap, reconcile it by hand."
