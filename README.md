<div align="center">

# Chat Alert — for Path of Exile 1 &amp; 2

**Never miss a whisper, a party invite or a guildmate asking for leech — get an on-screen alert the instant a word you care about hits the chat.**

![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v1.1%20·%2064--bit-6594B9?logo=autohotkey&logoColor=white&style=flat-square)
![Platform](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D6?logo=windows&logoColor=white&style=flat-square)
![Game access](https://img.shields.io/badge/Game%20access-read--only%20log-2EA44F?style=flat-square)
![Version](https://img.shields.io/badge/version-1.3-D9A441?style=flat-square)
![No dependencies](https://img.shields.io/badge/dependencies-none-6E7681?style=flat-square)

[Quick start](#quick-start) · [Features](#features) · [What's new](#whats-new-in-v13) · [Screenshots](#screenshots) · [Troubleshooting](#troubleshooting)

</div>

---

**Chat Alert** tails the in-game chat log of **Path of Exile 1 and Path of Exile 2** and pops a clean, always-on-top
banner the moment something you care about appears — a guildmate asking for leech, a party invite in Global, a whisper
you would have missed while fighting a boss.

Both games use the same log format, so one switch in **Settings → Game** is all it takes. Each game remembers its own
log file, and you can change game at any time without restarting.

It **never touches the game process**. It only reads a text file: no injection, no memory access, no FPS impact, works
in windowed, borderless and fullscreen.

<img src="screenshots/04-ingame-alert.png" alt="Chat Alert banner over Path of Exile 2" width="720">

---

## At a glance

| | |
|---|---|
| **Two games** | Path of Exile 1 **and** Path of Exile 2 — one switch, each game remembers its own log file |
| **Word alerts** | Any word or phrase, with case-sensitivity, whole-word matching and priority levels |
| **Five channels** | Global · Trade · Party · Whisper · Guild — each with its own colour, sound and on/off switch |
| **Phone push** | Discord webhook and/or ntfy — enable one or both, each with its own URL |
| **Profiles** | Separate word lists per character or league, switch instantly, export/import |
| **History** | Searchable table, full-message panel, one-click whisper, CSV export |
| **Overlay** | Compact always-on-top list of recent alerts for a second monitor |
| **Hotkeys** | Mute, start/stop, hide window — while the game has focus |

---

## Quick start

1. **Install AutoHotkey v1.1 (64-bit)** → [download](https://www.autohotkey.com/download/ahk-v1-1.zip). AutoHotkey **v2 is not supported**.
2. **Download** this repo (*Code → Download ZIP*) and extract it anywhere.
3. **Run** `PoE2-Chat-Alert.ahk`.
4. Pick your game in **Settings → Game** and point it at that game's log — press **Choose log...** or let the app find
   it automatically:
   ```
   Path of Exile 2:  <Steam or game folder>\Path of Exile 2\logs\Client.txt
   Path of Exile 1:  <Steam or game folder>\Path of Exile\logs\Client.txt
   ```
5. Type a word (e.g. `leech`), press **Add**, then **Start** — or just hit <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>S</kbd>.

The status bar shows `listening to chat (every 500 ms)` when it is working.

> **Tip:** click **Test sound** in Settings to make sure your alarm is audible, and **Test notify** to verify phone push.

---

## How it works

Both games write every chat message to the same kind of plain-text log, so the app reads them identically:

```
... [INFO Client 1234] $SomePlayer: WTS Perfect Strike 5 divine
```

Chat Alert reads **only the new lines** of that file every **500 ms** and matches them against the word list of your
active profile. On a match it shows a banner, plays a sound, appends a row to history, and — if enabled — pushes the
alert to your phone. Every match is also written to `PoE2-Chat-Alert-matches.txt`.

Because the game only **writes** the log and Chat Alert only **reads** it, there is no interaction with the client at
all, and the app keeps working whether or not the game is focused.

---

## Features

### Path of Exile 1 and Path of Exile 2

One app, both games. Open **Settings → Game** and pick what you are playing:

- The app switches to that game's log file (and remembers it, so switching back is instant).
- The window title and the header show `PoE1` or `PoE2` at a glance.
- If you choose a log file manually (**Choose log...**), the game is detected from the path automatically.
- Your **profiles, words, history, sounds and notifications are shared** between the two games — only the log file and
  the item database are per-game.

Default log locations, if you want to set the path by hand:

| Game | Steam | Standalone | Epic |
|---|---|---|---|
| Path of Exile 2 | `...\steamapps\common\Path of Exile 2\logs\Client.txt` | `...\Grinding Gear Games\Path of Exile 2\logs\Client.txt` | — |
| Path of Exile 1 | `...\steamapps\common\Path of Exile\logs\Client.txt` | `...\Grinding Gear Games\Path of Exile\logs\Client.txt` | `...\Epic Games\PathOfExile\logs\Client.txt` |

> The app watches **one game at a time**. To switch, change the dropdown — no restart needed.

### Word alerts

The core of the app. Add any word or phrase and get alerted whenever it appears.

- **Add / Delete** words in the active profile.
- Each profile keeps **a separate list per game** - the counter next to **WORDS** shows which one you are editing, and
  switching the game in **Settings -> Game** swaps the list automatically.
- **Regular expressions**: type the pattern between slashes, e.g. `//div(or|ine) \d+ (?!forge)/`. It matches `divine 5 div`
  but not `divine forge 5 div`. Invalid patterns are rejected with a message instead of never matching.
- **Per-word options** — *Options...* button, or the `Cs` / `WW` / `Prio` columns:

  | Option | Meaning |
  |:--:|---|
  | **Cs** | Case-sensitive: `Leech` will not match `leech` |
  | **WW** | Whole word: `leech` will not match `leeching` |
  | **Rx** | The word is a regular expression and is used exactly as typed |
  | **Prio** | `Normal` · `High` · `Urgent` — higher priority means a louder sound and a longer banner |

- **Cooldown** keeps the same alert from spamming you (default 10 s).
- Your own messages and system lines are ignored.

### Profiles

Different characters, different leagues, different goals — keep separate lists.

- Switch instantly from the **Profile** dropdown.
- **New** / **Delete** profiles.
- **Export** / **Import** a profile to or from an `.ini` file to back it up or share it. The export contains the words of
  **both** games, so one file can restore a profile in Path of Exile 1 and Path of Exile 2.

### Channels, categories and sounds

Every message is classified by the channel it came from.

| Channel | Log prefix | Notes |
|---|:--:|---|
| Global | `#` | |
| Trade | `$` | |
| Party | `%` | |
| Whisper | `@From` | Always at least *High* priority |
| Guild | `&` | |

Open **Categories** to enable/disable channels, pick the banner colour, choose a sound per category and preview it with
**Test sound**. If a category has no sound of its own, the global alarm sound is used.

### External notifications

Get alerts on your phone or another device while you are away from the keyboard.

- **Discord** — paste a channel webhook URL (`https://discord.com/api/webhooks/...`).
- **ntfy** — paste a topic URL (`https://ntfy.sh/<your-topic>`), then subscribe to the same topic in the ntfy app.
- **Each provider has its own checkbox and its own URL field** — enable Discord, ntfy, or **both at the same time**.
- Notifications include the channel, player, word and message.
- Discord alerts carry a **Raspunde** button that opens the trade search for the matched item, and the message ends with
  a ready-to-paste `/whisper <player>` command so you can answer from your phone. ntfy alerts get the same link as a
  click action.
- **Test notify** sends a real test and reports the result per provider (e.g. `discord: ok · ntfy: ok`), so a wrong
  URL is caught immediately instead of failing silently.

<details>
<summary><b>How do I get an ntfy topic?</b></summary>

1. Install the **ntfy** app (Android: Play Store / F-Droid, iOS: App Store) or use <https://ntfy.sh/app>.
2. Pick a topic name that is hard to guess, e.g. `poe2-iulian-7f3k9x2q` — anyone who knows it can read it.
3. In the app: **+ → Subscribe to topic** → enter the same name.
4. In Chat Alert: tick **ntfy**, paste `https://ntfy.sh/poe2-iulian-7f3k9x2q`, press **Test notify**.

</details>

### History and message panel

Every match lands in the table: **Time · Channel · Player · Word · Message**.

- **Search** plus channel and player filters.
- **Click a row** to read the full message in the panel below — no more truncated chat lines.
- **Double-click** to copy the line · **right-click** for *Copy line / Copy player / Whisper player*.
- **Quick reply** box builds `/whisper <player> <text>` for you.
- Every copy action is confirmed by a short on-screen toast.
- History is saved between sessions; **Export CSV** writes the whole table to a spreadsheet.

### Overlay panel

A compact, always-on-top list of recent alerts with a running counter (<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>O</kbd>).
Great on a second monitor, or over the game when you don't want the full window open.

### Statistics

**Stats** shows total matches, words with hits, the top word, your active profile and a per-word breakdown.

### Global hotkeys

These work while the game has focus (unless the combination is bound in-game):

| Hotkey | Action |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>M</kbd> | Toggle mute |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>S</kbd> | Start / stop watching |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>H</kbd> | Hide / show the main window |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>O</kbd> | Toggle the overlay panel |

---

## What's new in v1.3

### A word list for each game
- Every profile now keeps **its own words per game** — put `exalted` in Path of Exile 1 and `divine` in Path of Exile 2,
  and each game alerts only on its own words.
- Switching the game in **Settings → Game** swaps the word list automatically; the counter in the main window shows which
  game's list you are editing.
- Existing word lists are copied to both games on the first start, so nothing is lost.

### Regular expressions in the word list
- Type a word between slashes to add it as a regular expression: `//div(or|ine) \d+ (?!forge)/` matches `divine 5 div`
  but not `divine forge 5 div`.
- Regular expressions are case-insensitive unless you tick **Case-sensitive** in *Options...*; invalid patterns are
  rejected with a clear message instead of silently never matching.
- The `Rx` column marks the words that are regular expressions.

### A "Răspunde" button on Discord
- Discord alerts now carry a **Răspunde** button that opens the trade search for the item that matched.
- The message also ends with a ready-to-paste `/whisper <player>` command, so you can answer straight from your phone.
- ntfy alerts get the same link as a click action.

### Nothing gets lost any more
- The match history is now an **append-only log** written the moment a match happens, so a crash or a forced exit cannot
  lose it any more. The file is trimmed automatically.
- The price history is written to disk every few seconds instead of on every single match.
- Word lists, watched items, custom rules, prices and history moved out of the `.ini` into their own small files, written
  atomically — a half-written file can no longer corrupt your configuration. Everything is migrated automatically on the
  first start.

### The Path of Exile 1 item database is included
- `items-poe1.txt` (5 414 entries) ships with the app, so **Trade watch** works in Path of Exile 1 right away.
- The database of the game you are playing is **refreshed automatically** when it is missing or older than a week - the
  app checks in the background a moment after start and once per hour, and never blocks the UI while it downloads.
  *Update items (API)* still refreshes it on demand.
- **Trade watch** shows when the database was last updated, so you always know if it is current.

### Bug fixes
- Discord payloads are escaped correctly: a message containing `\` or `"` no longer breaks the JSON and silently drops
  the notification.
- The ntfy title and the message are encoded as UTF-8.
- The log file is detected correctly when the game is running.
- The Discord alert shows the message as the body and the application name as the title.

---

## What's new in v1.2

### Play Path of Exile 1 or Path of Exile 2
- New **Game** selector in Settings. Both games write the same chat format, so alerts, profiles and history work unchanged.
- The log file, item database and trade API are per game; each game remembers its own log path.
- The window title, header and tray tooltip follow the selected game.
- Choosing a log file manually switches the game automatically when the path is recognisable.

### Two games, one config
- Existing settings are migrated automatically: the old single `log_path` becomes the log path of the game you had
  selected, so there is nothing to redo after updating.
- The Settings window refreshes itself after a game change, so the log field always shows the correct path.
- PoE2 installations are still detected out of the box; PoE1 Steam, standalone and Epic folders are probed too.

---

## What's new in v1.1

### Notifications: Discord *and* ntfy, independently
- Two separate checkboxes instead of one provider dropdown — **both can be enabled simultaneously**.
- Each provider keeps **its own URL field**, so switching or editing one never wipes the other.
- Every alert is delivered to **all enabled providers**.

### Honest test feedback
- **Test notify** now reports the real result per provider — `discord: ok · ntfy: ok`, or the actual failure such as
  `HTTP 404` — instead of always claiming success.
- Clear hints on failure: wrong webhook URL vs. phone not subscribed to the ntfy topic.
- ntfy titles are sanitised to ASCII, so they no longer show `?` instead of a dash in the notification header.

### Safer configuration
- Personal settings (`PoE2-Chat-Alert.ini`) and runtime logs are **excluded from this repository**.
- Old configs are migrated automatically: `notify_mode=discord|ntfy|both` becomes the matching checkboxes, and the
  legacy single `notify_url` key is imported once, then removed.

### Feedback & polish
- Copy actions (whisper, quick reply, copy line/player) now show a **toast confirmation** at the bottom of the screen,
  in green for success and red for "select a row first" style errors.
- The Settings window was re-laid out so every provider has a dedicated row.

---

## Screenshots

<table>
<tr>
<td width="50%">

**Main window** — profiles, word list, history and full-message panel.

<img src="screenshots/01-main-window.png" alt="Main window">

</td>
<td width="50%">

**Settings** — log path, alarms, banner behaviour, notifications.

<img src="screenshots/02-settings.png" alt="Settings">

</td>
</tr>
<tr>
<td colspan="2">

**In-game alert** — channel tag, word, player and message, rendered over the game.

<img src="screenshots/04-ingame-alert.png" alt="In-game alert">

</td>
</tr>
</table>

---

## Settings

| Setting | Description |
|---|---|
| **Log file** | Path to `logs/Client.txt` of your installation (filled automatically per game) |
| **Game** | `Path of Exile 2` or `Path of Exile 1` — switches log file, item database and branding |
| **Alarm sound (.wav)** | Fallback sound used when a category has none |
| **Banner position** | `top`, `center` or `bottom` |
| **Banner width** | Banner width in pixels (default 380) |
| **Beeps** | Number of beeps played with the alert |
| **Cooldown (s)** | Minimum seconds between two alerts (default 10) |
| **Banner (s)** | How long the banner stays on screen (default 8) |
| **Start with Windows (login)** | Launch Chat Alert when you log in |
| **Start minimized in the tray** | Start hidden with a tray icon |
| **Notify** | Tick **Discord** and/or **ntfy**; each has its own URL field |

Settings are stored in `PoE2-Chat-Alert.ini` next to the script and saved automatically.

---

## Files

| File | Purpose | In git |
|---|---|:--:|
| `PoE2-Chat-Alert.ahk` | The application | yes |
| `items.txt` | Item database used by Trade watch for Path of Exile 2 | yes |
| `items-poe1.txt` | Item database used by Trade watch for Path of Exile 1 | yes |
| `README.md`, `screenshots/` | Documentation | yes |
| `PoE2-Chat-Alert.ini` | Your settings (both games) and categories (created on first run) | no |
| `PoE2-Chat-Alert-words.txt` | Your word lists, per profile and per game | no |
| `PoE2-Chat-Alert-watch.txt` | Watched items and custom rules | no |
| `PoE2-Chat-Alert-prices.txt` | Price history and per-item price alerts | no |
| `PoE2-Chat-Alert-history.log` | Every match, appended the moment it happens | no |
| `PoE2-Chat-Alert-matches.txt` | Local log of every match | no |
| `PoE2-Chat-Alert-<timestamp>.csv` | History exports | no |

Delete the `.ini` file and the `PoE2-Chat-Alert-*.txt` / `*.log` files to reset the app to defaults.

---

## Troubleshooting

<details>
<summary><b>The status bar says "Log not found"</b></summary>

Check that **Settings → Game** matches the game you are playing, then set the correct path in **Settings → Log file →
Browse**. It must point to `...\Path of Exile 2\logs\Client.txt` or `...\Path of Exile\logs\Client.txt`. Launch the game
once so the log exists — the app creates it only while the game is running.

</details>

<details>
<summary><b>I play both games — do I need two copies?</b></summary>

  No. Use **Settings → Game** to switch. Each game keeps its own log path, so going back and forth is two clicks. Words
  are kept per game (each profile has a separate list for Path of Exile 1 and Path of Exile 2); history and the settings
  are shared, only the log file, the item database and the word list change.

</details>

<details>
<summary><b>No alerts appear</b></summary>

Check, in order: the app is **Watching** (not *Stop*), the active profile contains your word, the channel is enabled in
**Categories**, and the message isn't inside the cooldown window. Only *new* lines are read — messages already in the
log before you press Start are not replayed.

</details>

<details>
<summary><b>Phone notifications do not arrive</b></summary>

Press **Test notify** and read the result. For Discord, check the webhook still exists in the channel settings. For
ntfy, make sure your phone is subscribed to the exact same topic (names are case-sensitive) and that notifications are
allowed for the ntfy app.

</details>

<details>
<summary><b>"This script requires AutoHotkey v1.1" or a v2 error</b></summary>

You have AutoHotkey v2 installed, or v2 is the default interpreter. Install **v1.1 64-bit** and make sure `.ahk` files
open with it, or run the script with the v1.1 `AutoHotkey.exe` explicitly.

</details>

<details>
<summary><b>Windows SmartScreen warns about the file</b></summary>

The script is plain AutoHotkey — open it in Notepad to inspect it. If you trust the source, choose *More info → Run
anyway*, or unblock the ZIP before extracting.

</details>

<details>
<summary><b>Hotkeys do not work</b></summary>

Another application may own the same combination. Close it, or use the on-screen buttons.

</details>

---

## FAQ

**Can I be banned for using this?**  
Chat Alert only reads a text file written by the game. It does not read memory, inject code, automate input or interact
with the client. Still, use it at your own risk — see below.

**Does it work with the standalone client?**  
Yes — for both games. Pick the game in Settings and point it at that installation's `logs/Client.txt`.

**Can I watch both games at the same time?**  
No - the app watches the log of the game selected in Settings. Switching takes a second and does not restart the app. Each
game has its own word list, so you can keep `exalted` for Path of Exile 1 and `divine` for Path of Exile 2.

**Does it work on a non-English client?**  
The UI is English. Channel detection relies on the `#`, `$`, `%`, `@`, `&` prefixes, so it is largely
language-independent, and word matching works with any text.

**Can I run two copies?**  
No - the script enforces a single instance. Use profiles instead.

**Where are my settings?**  
In `PoE2-Chat-Alert.ini` next to the script, together with the word lists, watched items, prices and history in the
`PoE2-Chat-Alert-*.txt` / `*.log` files. Back up the whole set to keep your profiles.

**Does it alert on my own messages?**  
No — your lines and system messages are ignored.

---

## Safety and disclaimer

- **Read-only** — reads `Client.txt`, never writes to it.
- No game files are modified, no memory is read, no input is sent to the game.
- All data stays on your machine. Outbound traffic only happens for the features you enable: external notifications to
  *your* Discord webhook or ntfy topic.
- Personal settings are git-ignored and never published.

This is a community tool, **not affiliated with, endorsed by, or supported by Grinding Gear Games**. Path of Exile and
Path of Exile 2 are trademarks of Grinding Gear Games. Use it at your own risk.

---

## Contributing

Issues and pull requests are welcome. When reporting a bug, include:

- what you expected and what happened,
- the relevant lines from `PoE2-Chat-Alert-matches.txt` (strip any personal data),
- your AutoHotkey and Windows versions.

Keep changes dependency-free and AutoHotkey v1.1 compatible, and update this README when you add a feature.
