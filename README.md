# claudespeak

A mod for Claude Code. When Claude finishes a reply, it reads a 1-3 sentence summary out loud with [Fish Audio](https://fish.audio). Short plain replies are read as they are. It streams, so speech starts as the audio arrives.

Only one voice plays at a time, even with several sessions open: a new reply cuts off the one before it. It stays quiet in sub-agents, `claude -p`, scheduled desktop routines, and a `claude` started from inside another session.

## Requirements (this fork: Windows)

- **Windows 10/11** with Windows PowerShell 5.1 and `curl.exe` (both ship with Windows). No ffmpeg needed.
- **A Fish Audio account and API key.** Get a key at <https://fish.audio/app/api-keys/>.
- **Claude Code** with a build that loads hooks modules.

This fork replaces the macOS pieces (`/usr/bin/curl`, `pkill`, ffmpeg `audiotoolbox`) with `hooks/play.ps1` and `hooks/stop.ps1`.
Fish returns a WAV, which `System.Media.SoundPlayer` plays, so speech starts after the clip has downloaded rather than streaming.
The upstream tests in `tests/` still target the macOS version and have not been updated.

## Install

```
claude plugin marketplace add C:\Apps\claudespeak
claude plugin install claudespeak@claudespeak
```

Then restart Claude Code, or run `/reload-plugins` in an open session.

### Add your Fish Audio key

Open the .env at `~/.claude/claudespeak/.env`, paste your Fish Audio API key after `FISH_API_KEY=`, save.

The file does not exist until claudespeak makes it, so run `/speak key` to create it and open it. If you skip this, your first finished reply does the same thing and tells you the path. The file lives under your user profile (Windows does not get the macOS `chmod 600`), and it lives outside the plugin folder so updates don't wipe it. A `FISH_API_KEY` environment variable takes priority over the file.

## Commands

It is **on by default**. `/speak on` and `/speak off` apply to every session on the machine.

| Command | What it does |
| --- | --- |
| `/speak` | Says whether it is on, and whether this session can speak |
| `/speak on` | Reads replies aloud in every session |
| `/speak off` | Stops reading aloud in every session |
| `/speak stop` | Cuts off the current speech in any session, and leaves the setting alone |
| `/speak key` | Creates the .env if needed and opens it |

## Voice and speed

Both are constants at the top of `hooks/register.ts`:

- `DEFAULTS.voiceId`: the Fish voice, Sawyer by default. It is also an option in the plugin's settings.
- `SPEECH_SPEED`: 1.1 by default, Fish's `prosody.speed` (0.5 to 2.0).

## Cost

Every spoken reply uses Fish Audio credits, and because it is on by default that means every reply in every session a person is attached to. Long replies also use one Haiku call on your Claude account to write the summary. Use `/speak off` to stop both.

## Status

Tested on macOS with scripted Claude Code sessions. Not yet confirmed by hand in the desktop app's Code tab, and sessions the app starts in the background may behave differently there.
