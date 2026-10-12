# claude-statusline-win

A [Claude Code](https://claude.com/claude-code) status line for Windows, written in plain PowerShell 5.1 — no bash, jq or extra installs. Built for subscription plans: it shows how much of your 5-hour and 7-day usage limits you've used, when they reset, and whether you're burning through them too fast.

[繁體中文說明](README.zh-TW.md)

![screenshot](docs/screenshot.png)

## Features

- **Gradient usage bars** for the context window and the 5h / 7d rate limits; percentages turn green < 70%, yellow 70–89%, red ≥ 90%
- **Reset countdowns** — `5h ... (2h13m)` and `7d ... (3d5h)`
- **Pace warnings** — the countdown turns yellow when your usage is 10+ points ahead of the elapsed time in the window, and red when it's 30+ points ahead, so you know you may run out before the reset
- **Auto wrap** — when the terminal is too narrow the line wraps at section boundaries instead of being cut off with `…`
- **Fast mode flag** (`⚡fast`) while `/fast` is on, since it spends quota faster
- **Auto effort tag** (`⟳ Auto`) — optional; only appears if a companion tool writes `%USERPROFILE%\.claude\rainy-console\live\<session_id>.json` with `"auto": true`. Without that file nothing changes
- **Auto model tag** (`⇄ Auto`) — optional, same file: with `"autoModel": true` the model name shows the model the tool picked for this turn (`"model"`) and a `⇄ Auto` tag follows it
- Model, effort level, session duration, current folder, git branch and uncommitted-changes marker (`*`)
- Truecolor in Windows Terminal, with 16-color, ASCII, Nerd Font and Powerline modes

```
◆ Opus 5.5 high │ █░░░░░░░░░ 12% / 1M │ 1.5h │ 5h ███░░░░░░░ 30% (4h15m) │ 7d ███░░░░░░░ 30% (1d1h) │ 📁 my-project │ ⎇ main*
```

## Requirements

- Windows 10 / 11 (Windows PowerShell 5.1 is built in)
- Claude Code
- Windows Terminal recommended for full color
- Rate limits are only reported for Claude subscription plans; on API billing the 5h / 7d sections are hidden

## Install

```powershell
git clone https://github.com/rainyfei/claude-statusline-win.git
cd claude-statusline-win
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

The installer copies `statusline.ps1` to `%USERPROFILE%\.claude\` and sets `statusLine` in `%USERPROFILE%\.claude\settings.json`. Any file it replaces is backed up as `*.bak-<timestamp>` first. The status line appears after your next message.

### Manual install

Copy `statusline.ps1` to `%USERPROFILE%\.claude\` and add this to `%USERPROFILE%\.claude\settings.json` (replace `<you>` with your Windows user name):

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/<you>/.claude/statusline.ps1\""
  }
}
```

## Options

Set these as Windows environment variables, then restart Claude Code.

| Variable | Effect |
|---|---|
| `CLAUDE_STATUSLINE_ASCII=1` | Plain ASCII, for fonts without block characters |
| `CLAUDE_STATUSLINE_NERDFONT=1` | Nerd Font icons (needs a Nerd Font in your terminal) |
| `CLAUDE_STATUSLINE_POWERLINE=1` | Powerline separators (on by default with Nerd Font) |
| `COLORTERM=truecolor` | Force 24-bit color outside Windows Terminal |

## How it works

Claude Code pipes session data as JSON to the script on every update. The script reads the context and rate-limit percentages, computes the reset countdowns from `resets_at`, reads the terminal width from `COLUMNS` to decide where to wrap, and checks git status (cached for 5 seconds in `%TEMP%`). If the optional auto-effort file above exists, it reads it too. It doesn't send anything over the network or write anything outside that git cache.

## Uninstall

Remove the `statusLine` entry from `%USERPROFILE%\.claude\settings.json` and delete `%USERPROFILE%\.claude\statusline.ps1`.

## License

[MIT](LICENSE)
