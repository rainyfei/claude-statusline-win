# claude-statusline-win - a Claude Code status line for Windows (PowerShell 5.1+)
# https://github.com/rainyfei/claude-statusline-win
#
# Output (one line, wrapped onto more lines at section boundaries when the
# terminal is too narrow):
#   <> model effort [fast] | ctx bar pct / size | duration | 5h bar pct (2h13m) | 7d bar pct (3d5h) | dir | branch*
#
# Colors: context and 5h/7d usage are green < 70%, yellow 70-89%, red >= 90%.
# Reset countdowns are colored by pace (see Get-ResetIn).
#
# Environment variables:
#   CLAUDE_STATUSLINE_ASCII=1     plain ASCII fallback
#   CLAUDE_STATUSLINE_NERDFONT=1  Nerd Font icons
#   CLAUDE_STATUSLINE_POWERLINE=1 Powerline separators (defaults to NERDFONT)
#   Truecolor is on when COLORTERM=truecolor|24bit or inside Windows Terminal (WT_SESSION)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function U([int[]]$codes) { -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }

# --- environment -----------------------------------------------------------

$useAscii = $env:CLAUDE_STATUSLINE_ASCII -eq '1'
$useNerd = $env:CLAUDE_STATUSLINE_NERDFONT -eq '1'
$usePowerline = if ($env:CLAUDE_STATUSLINE_POWERLINE) { $env:CLAUDE_STATUSLINE_POWERLINE -eq '1' } else { $useNerd }
$useTrue = ($env:COLORTERM -eq 'truecolor') -or ($env:COLORTERM -eq '24bit') -or [bool]$env:WT_SESSION

# --- colors and symbols ----------------------------------------------------

$e = [char]27
$RST = "$e[0m"; $CYAN = "$e[36m"; $GRAY = "$e[90m"
$YELLOW = "$e[33m"; $GREEN = "$e[32m"; $RED = "$e[31m"; $MAGENTA = "$e[35m"; $WHITE = "$e[97m"
$PURPLE = if ($useTrue) { "$e[38;2;114;102;234m" } else { "$e[35m" }
# light sky blue for the directory; plain dark blue is hard to read on dark backgrounds
$SKY = if ($useTrue) { "$e[38;2;97;175;239m" } else { "$e[94m" }

if ($useAscii) {
    $S_BRAND = '<>'; $S_BRANCH = '>'; $S_WARN = '!'; $S_TIME = ''; $S_DIR = ''; $S_FAST = 'fast'; $S_AUTO = 'Auto'
    $SEP = ' | '; $FULL = '#'; $EMPTY = '-'
} else {
    $S_BRAND = U 0x25C6; $FULL = U 0x2588; $EMPTY = U 0x2591; $S_AUTO = (U 0x27F3) + ' Auto'
    if ($useNerd) {
        $S_BRANCH = (U 0xE0A0) + ' '; $S_WARN = ' ' + (U 0xF0026); $S_TIME = (U 0xF051F) + ' '
        $S_DIR = (U 0xF07B) + ' '; $S_FAST = (U 0xF0E7) + ' fast'
    } else {
        $S_BRANCH = U 0x2387; $S_WARN = ' ' + (U 0x26A0); $S_TIME = ''
        $S_DIR = (U 0x1F4C1) + ' '; $S_FAST = (U 0x26A1) + 'fast'
    }
    $SEP = if ($usePowerline) { ' ' + (U 0xE0B1) + ' ' } else { ' ' + (U 0x2502) + ' ' }
}

$DASH = U 0x2500

function Get-LevelColor([int]$p) {
    if ($p -ge 90) { $RED } elseif ($p -ge 70) { $YELLOW } else { $GREEN }
}

# green -> yellow -> orange -> red, one color per cell
$gradR = 46, 116, 186, 241, 239, 236, 233, 231, 211, 192
$gradG = 204, 195, 186, 196, 161, 126, 101, 76, 66, 57
$gradB = 113, 89, 64, 15, 24, 34, 44, 60, 50, 43

# 10-cell bar; truecolor gradient, else one ANSI color for the whole bar, else ASCII
function Get-Bar([int]$pct) {
    $filled = [math]::Min(10, [int][math]::Floor($pct / 10))
    $bar = ''
    if ($useAscii) {
        for ($i = 0; $i -lt 10; $i++) { $bar += if ($i -lt $filled) { $FULL } else { $EMPTY } }
    } elseif ($useTrue) {
        for ($i = 0; $i -lt 10; $i++) {
            if ($i -lt $filled) { $bar += "$e[38;2;$($gradR[$i]);$($gradG[$i]);$($gradB[$i])m$FULL" }
            else { $bar += "$e[38;2;60;60;60m$EMPTY" }
        }
        $bar += $RST
    } else {
        for ($i = 0; $i -lt 10; $i++) { $bar += if ($i -lt $filled) { $FULL } else { $EMPTY } }
        $bar = (Get-LevelColor $pct) + $bar + $RST
    }
    return $bar
}

function Get-Pct($value) {
    if ($null -eq $value) { return -1 }
    return [math]::Max(0, [math]::Min(100, [int][math]::Floor([double]$value)))
}

# --- read JSON -------------------------------------------------------------

try { $data = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { $data = $null }
if (-not $data) { Write-Output "$GRAY$DASH $([char]0x2502) parse error$RST"; exit 0 }

$model = if ($data.model.display_name) { $data.model.display_name } else { $DASH }
$effort = if ($data.effort.level) { $data.effort.level } elseif ($data.effort -is [string]) { $data.effort } else { '' }
# rainy-console (console panel) auto effort: when on, show the level it picked and an Auto tag
$autoOn = $false
if ($data.session_id -and $env:USERPROFILE) {
    $liveFile = Join-Path $env:USERPROFILE ".claude\rainy-console\live\$($data.session_id).json"
    if (Test-Path -LiteralPath $liveFile) {
        try {
            $live = Get-Content -LiteralPath $liveFile -Raw | ConvertFrom-Json
            if ($live.auto -eq $true) { $autoOn = $true; if ($live.effort) { $effort = [string]$live.effort } }
        } catch { }
    }
}
$ctxPct = [math]::Max(0, (Get-Pct $data.context_window.used_percentage))
$ctxSize = [long]$data.context_window.context_window_size
$durMs = [long]$data.cost.total_duration_ms
$rate5h = Get-Pct $data.rate_limits.five_hour.used_percentage
$rate7d = Get-Pct $data.rate_limits.seven_day.used_percentage
$cwd = $data.workspace.current_dir
$branch = $data.worktree.branch

# --- context ---------------------------------------------------------------

$ctxWarn = if ($ctxPct -ge 90) { "$RED$S_WARN$RST" } else { '' }

# only when the model display name doesn't already mention the context size
$ctxLabel = ''
if ($model -cnotmatch 'context|Context') {
    if ($ctxSize -ge 1000000) { $ctxLabel = " ${GRAY}/ 1M$RST" }
    elseif ($ctxSize -ge 200000) { $ctxLabel = " ${GRAY}/ 200k$RST" }
}

# --- elapsed time (hidden when zero) ---------------------------------------

# shown in hours with one decimal, e.g. 1.8h
$durSection = ''
$durFmt = ($durMs / 3600000).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
if ($durFmt -ne '0.0') { $durSection = "$GRAY$S_TIME${durFmt}h$RST" }

# --- rate limits (hidden when Claude Code doesn't report them) -------------

# reset countdown from resets_at (unix seconds): 5h as (2h13m), 7d as (3d5h).
# Colored by pace: used% minus elapsed% of the window; gray when on pace,
# yellow when 10+ points ahead, red when 30+ points ahead.
function Get-ResetIn($resetsAt, [int]$used, [long]$window, [bool]$days) {
    if (-not $resetsAt) { return '' }
    $secs = [long]$resetsAt - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($secs -le 0) { return '' }
    $elapsed = [math]::Max(0, 100 * (1 - $secs / $window))
    $ahead = $used - $elapsed
    $color = if ($ahead -ge 30) { $RED } elseif ($ahead -ge 10) { $YELLOW } else { $GRAY }
    $t = [TimeSpan]::FromSeconds($secs)
    if ($days) { return " $color($([int][math]::Floor($t.TotalDays))d$($t.Hours)h)$RST" }
    return " $color($([int][math]::Floor($t.TotalHours))h$($t.Minutes)m)$RST"
}

$rateSections = @()
foreach ($r in @(@('5h', $rate5h, $data.rate_limits.five_hour.resets_at, 18000, $false), @('7d', $rate7d, $data.rate_limits.seven_day.resets_at, 604800, $true))) {
    if ($r[1] -lt 0) { continue }
    $rateSections += "$WHITE$($r[0])$RST $(Get-Bar $r[1]) $(Get-LevelColor $r[1])$($r[1])%$RST$(Get-ResetIn $r[2] $r[1] $r[3] $r[4])"
}

# --- git branch and dirty flag (cached 5s, hidden outside a repo) ----------

$dirty = ''
# Claude Code started before git was installed won't have it on PATH yet
$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git -and (Test-Path "$env:ProgramFiles\Git\cmd\git.exe")) { $git = "$env:ProgramFiles\Git\cmd\git.exe" }
if ($git -and $cwd -and (Test-Path -LiteralPath $cwd -PathType Container)) {
    $cacheFile = Join-Path $env:TEMP 'claude-statusline-git-cache.txt'
    $stale = $true
    if (Test-Path $cacheFile) {
        $age = ((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalSeconds
        $stale = ($age -gt 5) -or ((Get-Content $cacheFile -TotalCount 1 -Encoding UTF8) -ne $cwd)
    }
    if ($stale) {
        $cBranch = ''; $cDirty = ''
        & $git -C $cwd rev-parse --git-dir *> $null
        if ($LASTEXITCODE -eq 0) {
            $cBranch = $branch
            if (-not $cBranch) { $cBranch = (& $git -C $cwd -c core.useBuiltinFSMonitor=false branch --show-current 2> $null) }
            if (-not $cBranch) { $cBranch = (& $git -C $cwd rev-parse --short HEAD 2> $null) }
            & $git -C $cwd -c core.useBuiltinFSMonitor=false diff --quiet *> $null; $d1 = $LASTEXITCODE
            & $git -C $cwd -c core.useBuiltinFSMonitor=false diff --cached --quiet *> $null; $d2 = $LASTEXITCODE
            if ($d1 -ne 0 -or $d2 -ne 0) { $cDirty = '*' }
        }
        Set-Content -Path $cacheFile -Value @($cwd, "$cBranch|$cDirty") -Encoding UTF8
    }
    $cached = (Get-Content $cacheFile -Encoding UTF8)[1]
    if ($cached) {
        $parts = $cached.Split('|')
        if (-not $branch) { $branch = $parts[0] }
        $dirty = $parts[1]
    }
}

# --- assemble ----------------------------------------------------------------

$head = "$PURPLE$S_BRAND$RST $CYAN$model$RST"
if ($effort) { $head += " $MAGENTA$effort$RST" }
if ($autoOn) { $head += " $MAGENTA$S_AUTO$RST" }
# fast mode spends quota faster, so flag it while it's on
if ($data.fast_mode -eq $true) { $head += " $YELLOW$S_FAST$RST" }
$sections = @($head, "$(Get-Bar $ctxPct) $(Get-LevelColor $ctxPct)$ctxPct%$RST$ctxLabel$ctxWarn")
if ($durSection) { $sections += $durSection }
$sections += $rateSections
# current directory, last path component only (a drive root like C:\ stays as is)
if ($cwd) {
    $dir = Split-Path -Leaf $cwd
    if (-not $dir) { $dir = $cwd }
    $sections += "$SKY$S_DIR$dir$RST"
}
if ($branch) { $sections += "$GRAY$S_BRANCH$branch$RST$RED$dirty$RST" }

# Terminal width: Claude Code passes COLUMNS; the inherited console is a fallback.
# The smaller valid value wins so a stale number can't cause truncation.
$cols = 0
foreach ($w in @($env:COLUMNS, $(try { $Host.UI.RawUI.WindowSize.Width } catch { 0 }))) {
    $n = 0
    if ([int]::TryParse("$w", [ref]$n) -and $n -gt 0 -and ($cols -eq 0 -or $n -lt $cols)) { $cols = $n }
}

# display width: ANSI codes are zero-width, CJK and emoji take two cells
function Get-DisplayWidth([string]$s) {
    $s = $s -replace "$e\[[0-9;]*m", ''
    $w = 0
    for ($i = 0; $i -lt $s.Length; $i++) {
        $c = [int]$s[$i]
        if ([char]::IsHighSurrogate($s[$i]) -and $i + 1 -lt $s.Length) {
            $c = [char]::ConvertToUtf32($s[$i], $s[$i + 1]); $i++
        }
        $wide = ($c -ge 0x1100 -and $c -le 0x115F) -or ($c -ge 0x2E80 -and $c -le 0xA4CF) -or
                ($c -ge 0xAC00 -and $c -le 0xD7A3) -or ($c -ge 0xF900 -and $c -le 0xFAFF) -or
                ($c -ge 0xFE30 -and $c -le 0xFE4F) -or ($c -ge 0xFF00 -and $c -le 0xFF60) -or
                ($c -ge 0xFFE0 -and $c -le 0xFFE6) -or ($c -ge 0x1F300 -and $c -le 0x1FAFF) -or
                $c -eq 0x26A1
        $w += if ($wide) { 2 } else { 1 }
    }
    return $w
}

# Pack sections into as many lines as needed instead of letting Claude Code
# truncate with an ellipsis; 4 cells are left for Claude Code's own padding.
$limit = if ($cols -gt 0) { $cols - 4 } else { [int]::MaxValue }
$sepW = Get-DisplayWidth $SEP
$lines = @(); $line = ''; $lineW = 0
foreach ($s in $sections) {
    $sw = Get-DisplayWidth $s
    if ($line -and $lineW + $sepW + $sw -gt $limit) { $lines += $line; $line = ''; $lineW = 0 }
    if ($line) { $line += $SEP; $lineW += $sepW }
    $line += $s; $lineW += $sw
}
if ($line) { $lines += $line }

$lines | ForEach-Object { Write-Output $_ }
