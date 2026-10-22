; ============================================================
;  CHAT ALERT — Path of Exile 1 & 2  (AutoHotkey v1.1)
; ------------------------------------------------------------
;  Watches the in-game chat and alerts you when a word you
;  care about shows up (default: leech, leach).
;  Works with Path of Exile 1 and Path of Exile 2 — pick the
;  game in Settings; each one remembers its own log file.
;
;  FEATURES
;  - modern dark UI (tab-free, everything in one window)
;  - profiles: separate word lists you can switch instantly
;  - channels: Global (#), Trade ($), Party (%), Whisper (@From),
;    Guild (&) — each with its own COLOR and SOUND; each channel
;    can be turned on/off in the Categories dialog
;  - history table (Time / Ch / Player / Word / Message):
;      double-click  = copy the full line
;      right-click   = copy line / copy player / whisper player
;      search box + channel filter; history is saved and reloaded
;      quick-reply box inserts  /whisper <player> <reply>
;  - per-word options: case-sensitive, whole word, priority
;      (Normal / High / Urgent -> louder + longer banner)
;  - overlay panel: compact always-on-top list of recent alerts
;  - mute + volume + GLOBAL HOTKEYS:
;      Ctrl+Alt+M  toggle mute
;      Ctrl+Alt+S  start/stop watching
;      Ctrl+Alt+W  open Trade Watch
;      Ctrl+Alt+H  hide/show the main window
;      Ctrl+Alt+O  toggle the overlay panel
;  - statistics dashboard per word + CSV export
;  - profiles: export / import a profile to a .ini file
;  - trade watch: local item database (items.txt for PoE2,
;    items-poe1.txt for PoE1) with search + a watchlist; alerts
;    when a WTS/chat line names a watched item;
;    optional price range + bulk-only filters;
;    "Update items (API)" refreshes the database from the trade API
;  - settings: sound, banner position, start with Windows...
;
;  HOW IT WORKS
;  - the game writes all chat to  logs\Client.txt
;  - every 500 ms the script reads only the NEW lines and
;    checks them against your words
;  - on a match: modern banner + category sound (+ logged)
;
;  All settings live in  PoE2-Chat-Alert.ini (saved for you).
; ============================================================
#NoEnv
#SingleInstance Force
#Persistent
#Requires AutoHotkey >=1.1.36 <2 64-bit
SendMode, Input
SetWorkingDir, %A_ScriptDir%
SetBatchLines, -1
SetTitleMatchMode, 2

; -------------------- paths --------------------
GameMode     := "poe2"
AppName      := "Chat Alert — PoE2"
IniFile      := A_ScriptDir "\PoE2-Chat-Alert.ini"
MatchLogFile := A_ScriptDir "\PoE2-Chat-Alert-matches.txt"
ItemsPoe1    := A_ScriptDir "\items-poe1.txt"
ItemsPoe2    := A_ScriptDir "\items.txt"
ItemsFile    := ItemsPoe2
LogPathPoe1  := ""
LogPathPoe2  := ""

; -------------------- data files (kept out of the INI) --------------------
WordsFile    := A_ScriptDir "\PoE2-Chat-Alert-words.txt"
WatchFile    := A_ScriptDir "\PoE2-Chat-Alert-watch.txt"
PricesFile   := A_ScriptDir "\PoE2-Chat-Alert-prices.txt"
HistoryFile  := A_ScriptDir "\PoE2-Chat-Alert-history.log"
HistoryKeep  := 500        ; history lines kept in the log file
HistoryMem   := 200        ; history rows kept in memory

; -------------------- theme --------------------
cBg     := "1E1E22"
cPanel  := "26262C"
cLine   := "34343D"
cText   := "E6E6E9"
cDim    := "9A9AA2"
cGold   := "C8A55B"
cGood   := "5E9E58"
cBad    := "C0483F"
cBtn    := "33333C"
cBtnOn  := "3E5A3E"
cYellow := "D9C24A"
cInput  := "1E1E22"

Palette      := {"Red":"C0483F","Orange":"D07A3A","Yellow":"D9C24A","Green":"5E9E58","Blue":"4E86C0","Purple":"8A6FC0","Cyan":"3FA0A8","Pink":"C05B8A","Gold":"C8A55B","Gray":"7A7A82"}
PaletteOrder := ["Red","Orange","Yellow","Green","Blue","Purple","Cyan","Pink","Gold","Gray"]

; -------------------- settings (loaded from .ini) --------------------
LogPath        := ""
Beeps          := 6
CooldownSec    := 10
AlertSec       := 8
Muted          := 0
Volume         := 80
AlertPos       := "top"
AlertWidth     := 380
StartMinimized := 0
ActiveProfile  := "Default"
CustomSound    := "C:\Windows\Media\Alarm01.wav"
ProfileList    := []
TradeOnly      := 1
ItemColor      := "E07B39"
ItemSound      := ""
PriceMin       := 0
PriceMax       := 0
BulkOnly       := 0
BulkMin        := 0
NotifyDiscordOn := 0        ; 1 = send alerts to Discord
NotifyNtfyOn    := 0        ; 1 = send alerts to ntfy
NotifyDiscord   := ""       ; Discord webhook URL
NotifyNtfy      := ""       ; ntfy topic URL (https://ntfy.sh/<topic>)
PriceAlerts    := {}        ; item display name -> threshold price (divine)
PriceHist      := {}        ; sanitized item key -> "ts_amt_cur;ts_amt_cur;..."
PricesDirty    := 0         ; price history changed and not yet written to disk
WordSets       := {}        ; "profile|game" -> array of word objects
HistoryLines   := 0         ; number of lines in the history log file

; -------------------- data --------------------
CatColor := {}
CatSound := {}
CatOrder := []
ChanEnabled := {}
Words    := []
Stats    := {}
History  := []          ; array of {time,chan,player,word,msg,line}
HistShowRow := 0        ; last history row shown in the full-message box
HistView    := []       ; ListView row -> History index (after filtering)
HistFilter  := ""       ; search text
HistChanFilter := "All" ; channel filter
Items      := []        ; item database: {name, cat, uniq}
ItemsLower := []        ; lowercase name of each item (parallel to Items)
WatchList  := []        ; watched item names (display case, ordered)
WatchOn    := {}        ; watched name -> 1/0 (enabled)
WatchNames := []        ; parallel to WatchParts (display case)
WatchParts := []        ; regex fragments for the enabled watched items
WatchPattern := ""      ; i)(?:...) OR-pattern of enabled watched items
RXItems    := []        ; custom rules: {name, pat, on} (text/regex matched in the message)
RXNames    := []        ; enabled rule display names (parallel to RXParts)
RXParts    := []        ; enabled rule regex fragments
OverlayOn    := 0       ; live overlay panel visible?
OverlayLines := []      ; recent alerts shown in the overlay (max 12)

; -------------------- runtime --------------------
Pattern      := ""
WordParts    := []
Watching     := false
hLog         := ""
LastAlarm    := 0
MatchCount   := 0
hAlert       := ""
hToast       := ""
SettingsOpen := 0
CtxRow       := 0
StatusMsg    := "starting..."

; ------------------------------------------------------------
InitConfig()
BuildMainGui()
RefreshHistory()
BuildTray()
OnExit("OnScriptExit")

if (LogPath = "" or !FileExist(LogPath))
{
    LogPath := FindPoELog()
    if (LogPath != "")
    {
        if (GameMode = "poe1")
            LogPathPoe1 := LogPath
        else
            LogPathPoe2 := LogPath
        SaveSettings()
    }
}

if (LogPath != "" and FileExist(LogPath))
{
    StartWatching()
}
else
{
    SetStatus("Log not found — click ""Choose log...""")
    GuiControl, Main:, BtnToggle, Start
    LogPath := ""
    UpdateStatus()
}

if (!StartMinimized)
    Gui, Main:Show, w680 h660, %AppName%

return
; ==================== END OF AUTO-EXECUTE ====================


; ============================================================
;  FILE HELPERS  (atomic writes, escaping, legacy INI reading)
; ============================================================
StoreEsc(s)
{
    s := "" . s
    StringReplace, s, s, \, \\, All
    StringReplace, s, s, `t, \t, All
    StringReplace, s, s, `r, \r, All
    StringReplace, s, s, `n, \n, All
    return s
}

StoreUnesc(s)
{
    out := ""
    i := 1
    n := StrLen(s)
    while i <= n
    {
        c := SubStr(s, i, 1)
        nx := SubStr(s, i + 1, 1)
        if (c = "\" and nx = "t")
        {
            out .= Chr(9)
            i += 2
        }
        else if (c = "\" and nx = "r")
        {
            out .= Chr(13)
            i += 2
        }
        else if (c = "\" and nx = "n")
        {
            out .= Chr(10)
            i += 2
        }
        else if (c = "\" and nx = "\")
        {
            out .= "\"
            i += 2
        }
        else
        {
            out .= c
            i++
        }
    }
    return out
}

StoreWrite(path, content)
{
    tmp := path ".tmp"
    f := FileOpen(tmp, "w", "UTF-8-RAW")
    if !IsObject(f)
        return false
    f.Write(content)
    f.Close()
    FileMove, %tmp%, %path%, 1
    return true
}

StoreRead(path)
{
    if !FileExist(path)
        return ""
    f := FileOpen(path, "r", "UTF-8-RAW")
    if !IsObject(f)
        return ""
    t := f.Read()
    f.Close()
    return t
}

StoreAppend(path, line)
{
    try
    {
        f := FileOpen(path, "a", "UTF-8-RAW")
        if !IsObject(f)
            return
        f.Write(line . "`r`n")
        f.Close()
    }
}

; read the raw text of an INI file (handles both UTF-16 and ANSI)
IniRawText(path)
{
    if !FileExist(path)
        return ""
    t := ""
    f := FileOpen(path, "r", "UTF-16")
    if IsObject(f)
    {
        t := f.Read()
        f.Close()
        if (InStr(t, "[") = 0)
            t := ""
    }
    if (t = "")
    {
        f := FileOpen(path, "r")
        if IsObject(f)
        {
            t := f.Read()
            f.Close()
        }
    }
    return t
}

; extract the raw "key=value" lines of one INI section
IniRawSection(path, section)
{
    txt := IniRawText(path)
    if (txt = "")
        return ""
    lines := []
    inSec := false
    Loop, Parse, txt, `n, `r
    {
        ln := RTrim(A_LoopField, "`r")
        if (InStr(ln, "[") = 1 and InStr(ln, "]") > 1)
        {
            nm := SubStr(ln, 2, InStr(ln, "]") - 2)
            inSec := (Trim(nm) = section)
            continue
        }
        if (inSec and Trim(ln) != "")
            lines.Push(ln)
    }
    return lines
}


; ============================================================
;  CONFIG  —  load / save
; ============================================================
InitConfig()
{
    global ActiveProfile, ProfileList
    LoadSettings()
    LoadCategories()
    LoadStats()
    LoadProfileList()
    if !HasProfile(ActiveProfile)
        ActiveProfile := ProfileList[1]
    LoadWordSets()
    LoadProfile(ActiveProfile)
    LoadItems()
    LoadTrade()
    LoadPrices()
    LoadWatch()
    LoadWatchRegex()
    LoadHistory()
    BuildPattern()
    BuildWatchPattern()
    SaveAll()
    SetTimer, FlushPricesTimer, 15000     ; write the price history to disk every 15 s
}

HasProfile(name)
{
    global ProfileList
    for i, p in ProfileList
        if (p = name)
            return true
    return false
}

ApplyGameMode()
{
    global GameMode, AppName, ItemsFile, ItemsPoe1, ItemsPoe2
    GameMode  := (GameMode = "poe1") ? "poe1" : "poe2"
    AppName   := (GameMode = "poe1") ? "Chat Alert — PoE1" : "Chat Alert — PoE2"
    ItemsFile := (GameMode = "poe1") ? ItemsPoe1 : ItemsPoe2
}

LoadSettings()
{
    global IniFile, LogPath, Beeps, CooldownSec, AlertSec, Muted, Volume
    global AlertPos, AlertWidth, StartMinimized, ActiveProfile, CustomSound
    global NotifyDiscordOn, NotifyNtfyOn, NotifyDiscord, NotifyNtfy
    global GameMode, LogPathPoe1, LogPathPoe2
    IniRead, GameMode,       %IniFile%, settings, game,            poe2
    if !(GameMode = "poe1" or GameMode = "poe2")
        GameMode := "poe2"
    ApplyGameMode()
    IniRead, LogPathPoe1,    %IniFile%, settings, log_path_poe1,    % ""
    IniRead, LogPathPoe2,    %IniFile%, settings, log_path_poe2,    % ""
    IniRead, LogPath,        %IniFile%, settings, log_path,        % ""
    if (LogPathPoe1 = "ERROR")
        LogPathPoe1 := ""
    if (LogPathPoe2 = "ERROR")
        LogPathPoe2 := ""
    if (LogPath = "ERROR")
        LogPath := ""
    LogPathPoe1 := Trim(LogPathPoe1)
    LogPathPoe2 := Trim(LogPathPoe2)
    LogPath     := Trim(LogPath)
    ; migrate the old single log_path key into the active game's slot
    if (LogPath != "")
    {
        if (GameMode = "poe1" and LogPathPoe1 = "")
            LogPathPoe1 := LogPath
        if (GameMode = "poe2" and LogPathPoe2 = "")
            LogPathPoe2 := LogPath
    }
    IniRead, Beeps,          %IniFile%, settings, beeps,           6
    IniRead, CooldownSec,    %IniFile%, settings, cooldown_sec,    10
    IniRead, AlertSec,       %IniFile%, settings, alert_sec,       8
    IniRead, Muted,          %IniFile%, settings, muted,           0
    IniRead, Volume,         %IniFile%, settings, volume,          80
    IniRead, AlertPos,       %IniFile%, settings, alert_position,  top
    IniRead, AlertWidth,     %IniFile%, settings, alert_width,     380
    IniRead, StartMinimized, %IniFile%, settings, start_minimized, 0
    IniRead, ActiveProfile,  %IniFile%, settings, active_profile,  Default
    IniRead, CustomSound,    %IniFile%, settings, custom_sound,    C:\Windows\Media\Alarm01.wav
    IniRead, NotifyDiscord,  %IniFile%, settings, notify_discord,  % ""
    IniRead, NotifyNtfy,     %IniFile%, settings, notify_ntfy,     % ""
    if (NotifyDiscord = "ERROR")
        NotifyDiscord := ""
    if (NotifyNtfy = "ERROR")
        NotifyNtfy := ""
    NotifyDiscord := Trim(NotifyDiscord)
    NotifyNtfy    := Trim(NotifyNtfy)
    ; migrate the old single-provider keys (notify_mode + notify_url) once,
    ; sending the URL to the provider that used it back then
    IniRead, legacyMode, %IniFile%, settings, notify_mode, % ""
    IniRead, legacyUrl,  %IniFile%, settings, notify_url,  % ""
    if (legacyMode = "ERROR")
        legacyMode := ""
    if (legacyUrl = "ERROR")
        legacyUrl := ""
    legacyUrl := Trim(legacyUrl)
    if (legacyUrl != "")
    {
        isNtfy := !(InStr(legacyUrl, "discord.com") or InStr(legacyUrl, "discordapp.com"))
        if (legacyMode = "discord")
            isNtfy := 0
        else if (legacyMode = "ntfy")
            isNtfy := 1
        if (isNtfy)
        {
            if (NotifyNtfy = "")
                NotifyNtfy := legacyUrl
        }
        else if (NotifyDiscord = "")
            NotifyDiscord := legacyUrl
    }
    ; per-provider switches: an existing key wins, a missing one is inferred
    ; from the URL (used before the split) or from the old single-provider mode
    IniRead, NotifyDiscordOn, %IniFile%, settings, notify_discord_on, -1
    IniRead, NotifyNtfyOn,    %IniFile%, settings, notify_ntfy_on,    -1
    if (NotifyDiscordOn = -1)
        NotifyDiscordOn := (NotifyDiscord != "") ? 1 : ((legacyMode = "discord" or legacyMode = "both") ? 1 : 0)
    if (NotifyNtfyOn = -1)
        NotifyNtfyOn := (NotifyNtfy != "") ? 1 : ((legacyMode = "ntfy" or legacyMode = "both") ? 1 : 0)
    NotifyDiscordOn := (NotifyDiscordOn ? 1 : 0)
    NotifyNtfyOn    := (NotifyNtfyOn ? 1 : 0)
    LogPath := (GameMode = "poe1") ? LogPathPoe1 : LogPathPoe2
    if (Beeps < 1 or Beeps > 20)
        Beeps := 6
    if (CooldownSec < 0 or CooldownSec > 300)
        CooldownSec := 10
    if (AlertSec < 3 or AlertSec > 60)
        AlertSec := 8
    if (Volume < 0 or Volume > 100)
        Volume := 80
    if (AlertWidth < 260 or AlertWidth > 900)
        AlertWidth := 380
    if !(AlertPos = "top" or AlertPos = "center" or AlertPos = "bottom")
        AlertPos := "top"
}

LoadCategories()
{
    global IniFile, CatColor, CatSound, CatOrder, ChanEnabled
    CatColor := {}
    CatSound := {}
    ChanEnabled := {}
    defaults := {Global:"4E86C0", Trade:"C8A55B", Party:"5E9E58", Whisper:"8A6FC0", Guild:"3FA0A8"}
    CatOrder := ["Global", "Trade", "Party", "Whisper", "Guild"]
    for i, name in CatOrder
    {
        def := defaults[name]
        IniRead, col, %IniFile%, categories, %name%, %def%
        if (col = "ERROR" or col = "")
            col := def
        IniRead, snd, %IniFile%, cat_sound, %name%, % ""
        if (snd = "ERROR")
            snd := ""
        IniRead, en, %IniFile%, channels, %name%, % 1
        if (en = "ERROR" or en = "")
            en := 1
        CatColor[name] := col
        CatSound[name] := snd
        ChanEnabled[name] := (en + 0) ? 1 : 0
    }
}

SaveCategories()
{
    global IniFile, CatColor, CatSound, CatOrder, ChanEnabled
    IniDelete, %IniFile%, categories
    IniDelete, %IniFile%, cat_sound
    IniDelete, %IniFile%, channels
    for i, name in CatOrder
    {
        IniWrite, % CatColor[name], %IniFile%, categories, %name%
        IniWrite, % CatSound[name], %IniFile%, cat_sound, %name%
        IniWrite, % ChanEnabled[name], %IniFile%, channels, %name%
    }
}

LoadStats()
{
    global IniFile, Stats
    Stats := {}
    IniRead, out, %IniFile%, stats
    if (out = "ERROR" or Trim(out) = "")
        return
    Loop, Parse, out, `n, `r
    {
        if (A_LoopField = "")
            continue
        p := InStr(A_LoopField, "=")
        if !p
            continue
        Stats[SubStr(A_LoopField,1,p-1)] := SubStr(A_LoopField,p+1) + 0
    }
}

SaveStats()
{
    global IniFile, Stats
    IniDelete, %IniFile%, stats
    for w, c in Stats
        IniWrite, %c%, %IniFile%, stats, %w%
}

LoadProfileList()
{
    global IniFile, ProfileList, ActiveProfile
    IniRead, pl, %IniFile%, settings, profiles, % "Default"
    if (pl = "ERROR" or Trim(pl) = "")
        pl := "Default"
    ProfileList := []
    Loop, Parse, pl, |
    {
        n := Trim(A_LoopField)
        if (n != "")
            ProfileList.Push(n)
    }
    if (ProfileList.Length() = 0)
        ProfileList := ["Default"]
}

SaveProfileList()
{
    global IniFile, ProfileList
    s := ""
    for i, p in ProfileList
        s .= (s = "" ? "" : "|") . p
    IniWrite, %s%, %IniFile%, settings, profiles
}

LoadProfile(name)
{
    global IniFile, Words, WordSets, GameMode
    Words := []
    key := name "|" GameMode
    if (WordSets.HasKey(key))
    {
        for i, w in WordSets[key]
            Words.Push({text: w.text, cs: w.cs, ww: w.ww, prio: w.prio, rx: w.rx})
        return
    }
    ; --- one-time migration from the old "keywords" key ---
    IniRead, kw, %IniFile%, settings, keywords, % ""
    if (kw != "" and kw != "ERROR")
    {
        Loop, Parse, kw, CSV
        {
            w := ToLower(Trim(A_LoopField))
            if (w = "" or WordSetsHas(name, w))
                continue
            WordSetsAdd(name, w, {text: w, cs: 0, ww: 0, prio: 0, rx: 0})
        }
        IniDelete, %IniFile%, settings, keywords
    }
    ; --- one-time migration from the old shared profile section ---
    IniRead, out, %IniFile%, profile:%name%
    if (out = "ERROR" or Trim(out) = "")
        return
    seen := {}
    Loop, Parse, out, `n, `r
    {
        if (A_LoopField = "")
            continue
        p := InStr(A_LoopField, "=")
        if !p
            continue
        w := SubStr(A_LoopField, 1, p-1)
        if (w = "" or seen.HasKey(w))
            continue
        seen[w] := 1
        o := ParseWordFlags(w, SubStr(A_LoopField, p+1))
        WordSetsAdd(name, w, o)
    }
    ; the old profile was shared by both games: copy it to the other game too
    other := (GameMode = "poe1") ? "poe2" : "poe1"
    if (!WordSets.HasKey(name "|" other) and WordSets.HasKey(key))
    {
        for i, w in WordSets[key]
            WordSetsAdd(name, w.text, {text: w.text, cs: w.cs, ww: w.ww, prio: w.prio, rx: w.rx}, other)
    }
    LoadProfile(name)
}

WordSetsHas(name, text, game := "")
{
    global WordSets, GameMode
    if (game = "")
        game := GameMode
    key := name "|" game
    if (!WordSets.HasKey(key))
        return false
    for i, w in WordSets[key]
    {
        if (w.text = text)
            return true
    }
    return false
}

WordSetsAdd(name, text, obj, game := "")
{
    global WordSets, GameMode
    if (game = "")
        game := GameMode
    key := name "|" game
    if (!WordSets.HasKey(key))
        WordSets[key] := []
    WordSets[key].Push(obj)
}

ParseWordFlags(text, val)
{
    cs := 0
    ww := 0
    prio := 0
    rx := 0
    Loop, Parse, val, |
    {
        f := Trim(A_LoopField)
        if (f = "cs")
            cs := 1
        else if (f = "ww")
            ww := 1
        else if (f = "rx")
            rx := 1
        else if (SubStr(f, 1, 1) = "p")
            prio := SubStr(f, 2) + 0
    }
    if (prio < 0 or prio > 2)
        prio := 0
    return {text: text, cs: cs, ww: ww, prio: prio, rx: rx}
}

WordFlagsText(w)
{
    fl := ""
    if (w.cs)
        fl .= (fl = "" ? "" : "|") . "cs"
    if (w.ww)
        fl .= (fl = "" ? "" : "|") . "ww"
    if (w.rx)
        fl .= (fl = "" ? "" : "|") . "rx"
    if (w.prio > 0)
        fl .= (fl = "" ? "" : "|") . "p" . w.prio
    if (fl = "")
        fl := "1"
    return fl
}

SaveProfile(name)
{
    global WordSets, Words, GameMode
    WordSets[name "|" GameMode] := []
    for i, w in Words
        WordSets[name "|" GameMode].Push({text: w.text, cs: w.cs, ww: w.ww, prio: w.prio, rx: w.rx})
    SaveWordSets()
}

LoadWordSets()
{
    global WordSets, WordsFile
    WordSets := {}
    txt := StoreRead(WordsFile)
    if (txt = "")
        return
    Loop, Parse, txt, `n, `r
    {
        if (A_LoopField = "")
            continue
        f := StrSplit(A_LoopField, "`t")
        if (f.Length() < 4)
            continue
        prof := StoreUnesc(f[1])
        game := f[2]
        text := StoreUnesc(f[3])
        o := ParseWordFlags(text, f[4])
        WordSetsAdd(prof, text, o, game)
    }
}

SaveWordSets()
{
    global WordSets, WordsFile
    out := ""
    for key, arr in WordSets
    {
        p := InStr(key, "|")
        prof := StoreEsc(SubStr(key, 1, p - 1))
        game := SubStr(key, p + 1)
        for i, w in arr
            out .= prof . "`t" . game . "`t" . StoreEsc(w.text) . "`t" . WordFlagsText(w) . "`r`n"
    }
    StoreWrite(WordsFile, out)
}

SaveSettings()
{
    global IniFile, LogPath, Beeps, CooldownSec, AlertSec, Muted, Volume
    global AlertPos, AlertWidth, StartMinimized, ActiveProfile, CustomSound
    global NotifyDiscordOn, NotifyNtfyOn, NotifyDiscord, NotifyNtfy
    global GameMode, LogPathPoe1, LogPathPoe2
    IniWrite, %GameMode%,       %IniFile%, settings, game
    IniWrite, %LogPathPoe1%,    %IniFile%, settings, log_path_poe1
    IniWrite, %LogPathPoe2%,    %IniFile%, settings, log_path_poe2
    IniWrite, %LogPath%,        %IniFile%, settings, log_path
    IniWrite, %Beeps%,          %IniFile%, settings, beeps
    IniWrite, %CooldownSec%,    %IniFile%, settings, cooldown_sec
    IniWrite, %AlertSec%,       %IniFile%, settings, alert_sec
    IniWrite, %Muted%,          %IniFile%, settings, muted
    IniWrite, %Volume%,         %IniFile%, settings, volume
    IniWrite, %AlertPos%,       %IniFile%, settings, alert_position
    IniWrite, %AlertWidth%,     %IniFile%, settings, alert_width
    IniWrite, %StartMinimized%, %IniFile%, settings, start_minimized
    IniWrite, %ActiveProfile%,  %IniFile%, settings, active_profile
    IniWrite, %CustomSound%,    %IniFile%, settings, custom_sound
    IniWrite, %NotifyDiscordOn%, %IniFile%, settings, notify_discord_on
    IniWrite, %NotifyNtfyOn%,    %IniFile%, settings, notify_ntfy_on
    IniWrite, %NotifyDiscord%,   %IniFile%, settings, notify_discord
    IniWrite, %NotifyNtfy%,      %IniFile%, settings, notify_ntfy
    IniDelete, %IniFile%, settings, notify_mode
    IniDelete, %IniFile%, settings, notify_url
}

SaveAll()
{
    global ActiveProfile
    SaveSettings()
    SaveCategories()
    SaveProfileList()
    SaveProfile(ActiveProfile)
    SaveTrade()
    SavePrices()
    SaveWatch()
    SaveWatchRegex()
}


; ============================================================
;  WORDS  ->  REGEX PATTERN
; ============================================================
SplitWords(raw)
{
    list := []
    Loop, Parse, raw, `n, `r
    {
        Loop, Parse, A_LoopField, `,
        {
            w := Trim(A_LoopField, " `t")
            if (w != "")
                list.Push(w)
        }
    }
    return list
}

EscapeRegex(s)
{
    static special := "\.*+?|{}[]()^$#"
    out := ""
    Loop, Parse, s
    {
        c := A_LoopField
        out .= InStr(special, c) ? "\" . c : c
    }
    return out
}

ToLower(s)
{
    StringLower, s, s
    return s
}

ToUpper(s)
{
    StringUpper, s, s
    return s
}

BuildPattern()
{
    global Words, WordParts, Pattern
    WordParts := []
    if (Words.Length() = 0)
    {
        Pattern := ""
        return
    }
    parts := []
    for i, o in Words
    {
        w := o.text
        if (o.rx)
        {
            ; user-supplied regular expression: used verbatim (already escaped by the user)
            part := w
            if (o.cs)
                part := "(?-i:" . part . ")"
            parts.Push(part)
            continue
        }
        esc := EscapeRegex(w)
        if (o.ww)
        {
            pre := RegExMatch(w, "^[a-zA-Z0-9_]") ? "\b" : ""
            suf := RegExMatch(w, "[a-zA-Z0-9_]$") ? "\b" : ""
            part := pre . esc . suf
        }
        else
        {
            plain := RegExMatch(w, "^[a-zA-Z0-9_]+$")
            if (plain)
                esc .= "\w*"
            pre := RegExMatch(w, "^[a-zA-Z0-9_]") ? "\b" : ""
            suf := (plain or RegExMatch(w, "[a-zA-Z0-9_]$")) ? "\b" : ""
            part := pre . esc . suf
        }
        if (o.cs)
            part := "(?-i:" . part . ")"
        parts.Push(part)
    }
    pat := ""
    for i, p in parts
        pat .= (pat = "" ? "" : "|") . p
    WordParts := parts
    Pattern := "i)(?:" . pat . ")"
}


; ============================================================
;  ITEM DATABASE + TRADE WATCH
; ============================================================
LoadItems()
{
    global ItemsFile, Items, ItemsLower
    Items := []
    ItemsLower := []
    if !FileExist(ItemsFile)
        return
    f := FileOpen(ItemsFile, "r", "UTF-8-RAW")
    if !IsObject(f)
        return
    txt := f.Read()
    f.Close()
    if (txt = "")
        return
    Loop, Parse, txt, `n, `r
    {
        line := A_LoopField
        if (Trim(line) = "")
            continue
        p1 := InStr(line, "|")
        if !p1
            continue
        p2 := InStr(line, "|", , p1 + 1)
        if !p2
            continue
        cat := SubStr(line, 1, p1 - 1)
        nm  := SubStr(line, p1 + 1, p2 - p1 - 1)
        uq  := SubStr(line, p2 + 1) + 0
        if (nm = "")
            continue
        Items.Push({name: nm, cat: cat, uniq: uq})
        ItemsLower.Push(ToLower(nm))
    }
}

LoadTrade()
{
    global IniFile, TradeOnly, ItemColor, ItemSound, PriceMin, PriceMax, BulkOnly, BulkMin
    IniRead, TradeOnly,  %IniFile%, trade, trade_only, 1
    IniRead, ItemColor,  %IniFile%, trade, item_color, E07B39
    IniRead, ItemSound,  %IniFile%, trade, item_sound, % ""
    IniRead, PriceMin,   %IniFile%, trade, price_min, 0
    IniRead, PriceMax,   %IniFile%, trade, price_max, 0
    IniRead, BulkOnly,   %IniFile%, trade, bulk_only, 0
    IniRead, BulkMin,    %IniFile%, trade, bulk_min, 0
    if (ItemColor = "ERROR" or ItemColor = "")
        ItemColor := "E07B39"
    if (ItemSound = "ERROR")
        ItemSound := ""
    TradeOnly := (TradeOnly + 0) ? 1 : 0
    PriceMin  := PriceMin + 0
    PriceMax  := PriceMax + 0
    BulkOnly  := (BulkOnly + 0) ? 1 : 0
    BulkMin   := BulkMin + 0
}

SaveTrade()
{
    global IniFile, TradeOnly, ItemColor, ItemSound, PriceMin, PriceMax, BulkOnly, BulkMin
    IniWrite, %TradeOnly%, %IniFile%, trade, trade_only
    IniWrite, %ItemColor%, %IniFile%, trade, item_color
    IniWrite, %ItemSound%, %IniFile%, trade, item_sound
    IniWrite, %PriceMin%,  %IniFile%, trade, price_min
    IniWrite, %PriceMax%,  %IniFile%, trade, price_max
    IniWrite, %BulkOnly%,  %IniFile%, trade, bulk_only
    IniWrite, %BulkMin%,   %IniFile%, trade, bulk_min
}

PassTradeFilter(msg)
{
    global PriceMin, PriceMax, BulkOnly, BulkMin
    if (PriceMin <= 0 and PriceMax <= 0 and !BulkOnly and BulkMin <= 0)
        return true

    price := -1
    if RegExMatch(msg, "i)(\d+(?:\.\d+)?)\s*(?:div|divine|ex|exalt|exalted|chaos|alch|alchemy)\b", m)
        price := m1 + 0
    if (price >= 0)
    {
        if (PriceMin > 0 and price < PriceMin)
            return false
        if (PriceMax > 0 and price > PriceMax)
            return false
    }

    if (BulkOnly or BulkMin > 0)
    {
        qty := 0
        if RegExMatch(msg, "i)\b(\d+)\s*x\b", m)
            qty := m1 + 0
        else if RegExMatch(msg, "i)\bx\s*(\d+)\b", m)
            qty := m1 + 0
        else if RegExMatch(msg, "i)\bbulk\b")
            qty := 999999
        if (BulkOnly and qty = 0)
            return false
        if (BulkMin > 0 and qty > 0 and qty < BulkMin)
            return false
    }
    return true
}

; ============================================================
;  PRICE  —  extract / history / drop alerts
; ============================================================
ExtractPrice(msg)
{
    if RegExMatch(msg, "i)(\d+(?:[.,]\d+)?)\s*(divine|divi|divs|div|exalted|exalts|exalt|ex|chaos|alchemy|alch)\b", m)
    {
        amt := m1
        StringReplace, amt, amt, ",", ".", All
        cur := ToLower(m2)
        if (cur = "div" or cur = "divs" or cur = "divine" or cur = "divi")
            cur := "divine"
        else if (cur = "ex" or cur = "exalt" or cur = "exalts" or cur = "exalted")
            cur := "exalted"
        else if (cur = "chaos")
            cur := "chaos"
        else if (cur = "alch" or cur = "alchemy")
            cur := "alchemy"
        return {amt: amt + 0, cur: cur}
    }
    return ""
}

PriceKey(item)
{
    k := item
    StringReplace, k, k, "=", "_", All
    StringReplace, k, k, "[", "_", All
    StringReplace, k, k, "]", "_", All
    StringReplace, k, k, "|", "_", All
    StringReplace, k, k, `n, "", All
    StringReplace, k, k, `r, "", All
    return k
}

PriceNowStr(item)
{
    global PriceHist
    key := PriceKey(item)
    if !PriceHist.HasKey(key)
        return ""
    parts := StrSplit(PriceHist[key], ";")
    if (parts.Length() = 0)
        return ""
    e := StrSplit(parts[parts.Length()], "_")
    if (e.Length() < 3)
        return ""
    return e[2] " " e[3]
}

SavePriceHist(item, amt, cur)
{
    global PriceHist
    key := PriceKey(item)
    ts := A_YYYY . "-" . A_MM . "-" . A_DD . "T" . A_Hour . ":" . A_Min . ":" . A_Sec
    entry := ts . "_" . amt . "_" . cur
    parts := PriceHist.HasKey(key) ? StrSplit(PriceHist[key], ";") : []
    if (parts.Length() > 0)
    {
        last := StrSplit(parts[parts.Length()], "_")
        if (last.Length() >= 3 and last[2] = (amt "") and last[3] = cur)
            return
    }
    parts.Push(entry)
    if (parts.Length() > 50)
        parts.RemoveAt(1)
    s := ""
    for i, p in parts
        s .= (s = "" ? "" : ";") . p
    PriceHist[key] := s
}

LoadPrices()
{
    global IniFile, PriceHist, PriceAlerts, PricesFile
    PriceHist := {}
    PriceAlerts := {}
    ; one-time migration from the old INI section
    if (!FileExist(PricesFile))
    {
        legacy := IniRawSection(IniFile, "prices")
        for i, ln in legacy
        {
            p := InStr(ln, "=")
            if (!p)
                continue
            k := SubStr(ln, 1, p - 1)
            v := SubStr(ln, p + 1)
            if InStr(k, "hist_", 1) = 1
            {
                PriceHist[SubStr(k, 6)] := v
                continue
            }
            if InStr(k, "alert_", 1) = 1
            {
                bar := InStr(v, "|")
                if (!bar)
                    continue
                amt := SubStr(v, 1, bar - 1) + 0
                nm  := SubStr(v, bar + 1)
                if (nm != "" and amt > 0)
                    PriceAlerts[nm] := amt
            }
        }
        if (PriceHist.Count() > 0 or PriceAlerts.Count() > 0)
            SavePrices()
        return
    }
    txt := StoreRead(PricesFile)
    if (txt = "")
        return
    Loop, Parse, txt, `n, `r
    {
        if (Trim(A_LoopField) = "")
            continue
        f := StrSplit(A_LoopField, "`t")
        if (f.Length() < 3)
            continue
        if (f[1] = "h")
            PriceHist[StoreUnesc(f[2])] := StoreUnesc(f[3])
        else if (f[1] = "a" and f.Length() >= 4)
        {
            amt := f[3] + 0
            nm := StoreUnesc(f[4])
            if (nm != "" and amt > 0)
                PriceAlerts[nm] := amt
        }
    }
}
SavePrices()
{
    global PriceHist, PriceAlerts, PricesFile, PricesDirty
    out := ""
    for name, amt in PriceAlerts
    {
        k := PriceKey(name)
        out .= "a`t" . StoreEsc(k) . "`t" . amt . "`t" . StoreEsc(name) . "`r`n"
    }
    for key, s in PriceHist
    {
        if (s != "")
            out .= "h`t" . StoreEsc(key) . "`t" . StoreEsc(s) . "`r`n"
    }
    StoreWrite(PricesFile, out)
    PricesDirty := 0
}

; the price history changes on every trade match: write it to disk rarely,
; not on every single match
MarkPricesDirty()
{
    global PricesDirty
    PricesDirty := 1
}

FlushPrices()
{
    global PricesDirty
    if (PricesDirty)
        SavePrices()
    return
}

FlushPricesTimer:
    FlushPrices()
return


; ============================================================
;  EXTERNAL NOTIFICATIONS  (Discord / ntfy)
; ============================================================
JsonEscape(s)
{
    bs := Chr(92)
    dq := Chr(34)
    s := StrReplace(s, bs, bs bs)          ; backslash  -> \\
    s := StrReplace(s, dq, bs . dq)        ; quote      -> \"
    s := StrReplace(s, "`r", " ")
    s := StrReplace(s, "`n", " ")
    s := StrReplace(s, "`t", " ")
    while RegExMatch(s, "[\x00-\x08\x0B\x0C\x0E-\x1F]", m)
        s := StrReplace(s, m, "")
    return s
}

SendOne(kind, url, title, body, replyCmd := "", linkUrl := "", linkLabel := "")
{
    try
    {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.SetTimeouts(4000, 4000, 4000, 4000)
        if (kind = "discord")
        {
            q := Chr(34)
            text := title . " — " . body
            if (replyCmd != "")
                text .= "`n" . replyCmd
            payload := "{" . q . "content" . q . ":" . q . JsonEscape(text) . q
            if (linkUrl != "")
            {
                payload .= "," . q . "components" . q . ":[{" . q . "type" . q . ":1," . q . "components" . q . ":[{"
                payload .= q . "type" . q . ":2," . q . "style" . q . ":5," . q . "label" . q . ":" . q . JsonEscape(linkLabel) . q
                payload .= "," . q . "url" . q . ":" . q . JsonEscape(linkUrl) . q . "}]}]"
            }
            payload .= "}"
            whr.Open("POST", url, false)
            whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            whr.Send(payload)
        }
        else
        {
            whr.Open("POST", url, false)
            whr.SetRequestHeader("Title", RegExReplace(title, "[^\x20-\x7E]", "-"))
            if (linkUrl != "")
                whr.SetRequestHeader("X-Click", linkUrl)
            whr.Send(body)
        }
        code := whr.Status
        return (code >= 200 and code < 300) ? "ok" : "HTTP " . code
    }
    catch e
    {
        code := 0
        try
        {
            code := whr.Status
        }
        catch
        {
            code := 0
        }
        return (code ? "HTTP " . code : "network error: " . e.Message)
    }
}

SendNotify(title, body, replyCmd := "", linkUrl := "", linkLabel := "")
{
    global NotifyDiscordOn, NotifyNtfyOn, NotifyDiscord, NotifyNtfy
    out := ""
    bad := 0
    if (NotifyDiscordOn)
    {
        r := (NotifyDiscord = "") ? "no URL" : SendOne("discord", NotifyDiscord, title, body, replyCmd, linkUrl, linkLabel)
        out .= (out = "" ? "" : " · ") . "discord: " . r
        if (r != "ok")
            bad := 1
    }
    if (NotifyNtfyOn)
    {
        r := (NotifyNtfy = "") ? "no URL" : SendOne("ntfy", NotifyNtfy, title, body, replyCmd, linkUrl, linkLabel)
        out .= (out = "" ? "" : " · ") . "ntfy: " . r
        if (r != "ok")
            bad := 1
    }
    if (out = "")
        return "off"
    return bad ? out : "ok"
}

SendNotifyChat(label, chan, name, kind, shortMsg, priceTxt, priceDrop)
{
    global AppName, PriceAlerts, NotifyDiscordOn, NotifyNtfyOn, GameMode
    if !NotifyDiscordOn and !NotifyNtfyOn
        return
    nbody := chan . " — " . (name != "" ? name : "?")
    nbody .= (kind = "ITEM") ? "  ·  ITEM: " . label : "  ·  " . label
    if (priceTxt != "")
        nbody .= "  ·  " . priceTxt
    if (priceDrop)
        nbody .= "  ·  dropped below " . PriceAlerts[label] . " divine"
    nbody .= "  —  " . shortMsg
    ; a ready-to-paste whisper command so the phone can answer in one tap
    replyCmd := ""
    if (name != "" and name != "?")
        replyCmd := "/whisper " . name . " "
    ; a link to the in-game trade search for the item that was matched
    linkUrl := ""
    linkLabel := ""
    if (kind = "ITEM" and label != "")
    {
        linkUrl := "https://www.pathofexile.com/trade/search/" . (GameMode = "poe1" ? "poe1" : "poe2")
        linkLabel := "Răspunde"
    }
    SendNotify(AppName, nbody, replyCmd, linkUrl, linkLabel)
}

CollectMatches(hay, pat, names, poss)
{
    pos := 1
    while (p := RegExMatch(hay, pat, m, pos))
    {
        names.Push(m1)
        poss.Push(p)
        pos := p + 1
    }
}

AddItemRow(order, seen, cat, name, uniq)
{
    name := UnescapeJson(name)
    key := ToLower(name)
    if (key = "" or seen.HasKey(key))
        return
    seen[key] := 1
    order.Push(cat . "|" . name . "|" . uniq)
}

UnescapeJson(s)
{
    pos := 1
    while (p := RegExMatch(s, "\\u([0-9A-Fa-f]{4})", m, pos))
    {
        s := SubStr(s, 1, p - 1) . Chr("0x" . m1) . SubStr(s, p + 6)
        pos := p + 1
    }
    return s
}

ParseItemsJson(json)
{
    global ItemsFile
    q := Chr(34)
    labPat := q . "label" . q . ":" . q . "([^" . q . "]*)" . q
    tPat   := q . "type"  . q . ":" . q . "([^" . q . "]*)" . q
    nPat   := q . "name"  . q . ":" . q . "([^" . q . "]*)" . q
    uniqKey := q . "unique" . q . ":true"
    catMap := {}
    catMap["Accessories"] := "accessory"
    catMap["Armour"] := "armour"
    catMap["Currency"] := "currency"
    catMap["Flasks"] := "flask"
    catMap["Gems"] := "gem"
    catMap["Jewels"] := "jewel"
    catMap["Maps"] := "map"
    catMap["Weapons"] := "weapon"
    catMap["Sanctum"] := "sanctum"
    catMap["Wombgift"] := "wombgift"

    labName := [], labPos := []
    CollectMatches(json, labPat, labName, labPos)
    if (labName.Length() = 0)
        return -1

    order := []
    seen := {}
    total := StrLen(json) + 1
    for ci, catRaw in labName
    {
        cat := catMap.HasKey(catRaw) ? catMap[catRaw] : ToLower(catRaw)
        start := labPos[ci]
        end := (ci < labName.Length()) ? labPos[ci+1] : total
        region := SubStr(json, start, end - start)

        tName := [], tPos := [], nName := [], nPos := []
        CollectMatches(region, tPat, tName, tPos)
        CollectMatches(region, nPat, nName, nPos)
        rtotal := StrLen(region) + 1

        for ei, t in tName
        {
            wStart := tPos[ei]
            wEnd := (ei < tName.Length()) ? tPos[ei+1] : rtotal
            win := SubStr(region, wStart, wEnd - wStart)
            AddItemRow(order, seen, cat, t, 0)
            if InStr(win, uniqKey)
            {
                uname := ""
                for nj, np in nPos
                {
                    if (np >= wStart and np < wEnd)
                    {
                        uname := nName[nj]
                        break
                    }
                }
                if (uname != "")
                    AddItemRow(order, seen, cat, uname, 1)
            }
        }
    }

    out := ""
    for i, ln in order
        out .= ln . "`r`n"
    f := FileOpen(ItemsFile, "w", "UTF-8-RAW")
    if IsObject(f)
    {
        f.Write(out)
        f.Close()
    }
    return order.Length()
}

FetchItemsFromApi()
{
    global GameMode
    url := (GameMode = "poe1") ? "https://www.pathofexile.com/api/trade/data/items" : "https://www.pathofexile.com/api/trade2/data/items"
    try
    {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36")
        whr.SetRequestHeader("Accept", "application/json")
        whr.Send()
    }
    catch
    {
        return -1
    }
    if (whr.Status != 200)
        return -1
    n := ParseItemsJson(whr.ResponseText)
    if (n > 0)
    {
        LoadItems()
        BuildWatchPattern()
    }
    return n
}

LoadWatch()
{
    global IniFile, WatchList, WatchOn, WatchFile
    WatchList := []
    WatchOn := {}
    ; one-time migration from the old INI sections
    if (!FileExist(WatchFile))
    {
        legacy := IniRawSection(IniFile, "watch")
        for i, ln in legacy
        {
            p := InStr(ln, "=")
            if (!p)
                continue
            nm := SubStr(ln, 1, p - 1)
            if (nm = "")
                continue
            WatchList.Push(nm)
            WatchOn[nm] := (SubStr(ln, p + 1) + 0) ? 1 : 0
        }
        legacyRx := IniRawSection(IniFile, "watch_regex")
        for i, ln in legacyRx
        {
            p := InStr(ln, "=")
            if (!p)
                continue
            ParseWatchRuleLine(SubStr(ln, p + 1))
        }
        SaveWatch()
        return
    }
    txt := StoreRead(WatchFile)
    if (txt = "")
        return
    Loop, Parse, txt, `n, `r
    {
        if (Trim(A_LoopField) = "")
            continue
        f := StrSplit(A_LoopField, "`t")
        if (f.Length() < 2)
            continue
        if (f[1] = "W" and f.Length() >= 3)
        {
            nm := StoreUnesc(f[2])
            if (nm = "")
                continue
            WatchList.Push(nm)
            WatchOn[nm] := (f[3] + 0) ? 1 : 0
        }
        else if (f[1] = "R" and f.Length() >= 4)
        {
            AddWatchRule(StoreUnesc(f[2]), StoreUnesc(f[3]), (f[4] + 0) ? 1 : 0)
        }
    }
}

SaveWatch()
{
    global WatchList, WatchOn, RXItems, WatchFile
    out := ""
    for i, nm in WatchList
        out .= "W`t" . StoreEsc(nm) . "`t" . (WatchOn.HasKey(nm) ? WatchOn[nm] : 1) . "`r`n"
    for i, r in RXItems
        out .= "R`t" . StoreEsc(r.name) . "`t" . StoreEsc(r.pat) . "`t" . (r.on ? 1 : 0) . "`r`n"
    StoreWrite(WatchFile, out)
}

AddWatchRule(name, pat, on)
{
    global RXItems
    RXItems.Push({name: name, pat: pat, on: on})
}

; parse one legacy "0|Name => pattern" line
ParseWatchRuleLine(val)
{
    en := 1
    bar := InStr(val, "|")
    if bar
    {
        en := (SubStr(val, 1, bar - 1) + 0) ? 1 : 0
        val := SubStr(val, bar + 1)
    }
    arrow := InStr(val, "=>")
    if arrow
    {
        nm := Trim(SubStr(val, 1, arrow - 1))
        pt := Trim(SubStr(val, arrow + 2))
    }
    else
    {
        nm := Trim(val)
        pt := Trim(val)
    }
    if (pt = "")
        return
    if (nm = "")
        nm := pt
    AddWatchRule(nm, pt, en)
}

LoadWatchRegex()
{
    ; the rules are stored together with the watch list in the watch file
    global RXItems, WatchFile
    RXItems := []
    if (!FileExist(WatchFile))
        return
    txt := StoreRead(WatchFile)
    if (txt = "")
        return
    Loop, Parse, txt, `n, `r
    {
        if (Trim(A_LoopField) = "")
            continue
        f := StrSplit(A_LoopField, "`t")
        if (f.Length() < 4)
            continue
        if (f[1] = "R")
            AddWatchRule(StoreUnesc(f[2]), StoreUnesc(f[3]), (f[4] + 0) ? 1 : 0)
    }
}

SaveWatchRegex()
{
    ; written by SaveWatch together with the watch list
    SaveWatch()
}

RXValid(pat)
{
    if (Trim(pat) = "")
        return false
    try
        RegExMatch("x", pat)
    catch
        return false
    return true
}

BuildWatchPattern()
{
    global WatchList, WatchOn, WatchNames, WatchParts, WatchPattern
    global RXItems, RXNames, RXParts
    WatchNames := []
    WatchParts := []
    RXNames := []
    RXParts := []
    pat := ""
    for i, nm in WatchList
    {
        if !(WatchOn.HasKey(nm) ? WatchOn[nm] : 1)
            continue
        part := "(?<![A-Za-z0-9])" . EscapeRegex(nm) . "(?![A-Za-z0-9])"
        WatchNames.Push(nm)
        WatchParts.Push(part)
        pat .= (pat = "" ? "" : "|") . part
    }
    for i, r in RXItems
    {
        if (!r.on or r.pat = "")
            continue
        RXNames.Push(r.name)
        RXParts.Push(r.pat)
        pat .= (pat = "" ? "" : "|") . "(?:" . r.pat . ")"
    }
    WatchPattern := (pat = "") ? "" : "i)(?:" . pat . ")"
}


; ============================================================
;  LOG  —  find / open / tail
; ============================================================
FindPoELog(game := "")
{
    global GameMode
    if (game = "")
        game := GameMode
    want2 := (game = "poe2")
    WinGet, poePath, ProcessPath, ahk_class POEWindowClass
    if (!ErrorLevel and poePath != "")
    {
        SplitPath, poePath, , folder
        is2 := InStr(folder, "Path of Exile 2") ? true : false
        if (is2 = want2 and FileExist(folder "\logs\Client.txt"))
            return folder "\logs\Client.txt"
    }
    doc := ""
    try doc := A_MyDocuments
    candidates := []
    steam := ["C:\Program Files (x86)\Steam\steamapps\common\", A_ProgramFiles "\Steam\steamapps\common\", "D:\SteamLibrary\steamapps\common\", "E:\SteamLibrary\steamapps\common\"]
    if want2
    {
        for i, s in steam
            candidates.Push(s "Path of Exile 2\logs\Client.txt")
        candidates.Push("C:\Program Files (x86)\Grinding Gear Games\Path of Exile 2\logs\Client.txt")
        candidates.Push("C:\Program Files\Grinding Gear Games\Path of Exile 2\logs\Client.txt")
        if (doc != "")
            candidates.Push(doc "\My Games\Path of Exile 2\logs\Client.txt")
    }
    else
    {
        for i, s in steam
            candidates.Push(s "Path of Exile\logs\Client.txt")
        candidates.Push("C:\Program Files (x86)\Grinding Gear Games\Path of Exile\logs\Client.txt")
        candidates.Push("C:\Program Files\Grinding Gear Games\Path of Exile\logs\Client.txt")
        candidates.Push("C:\Program Files\Epic Games\PathOfExile\logs\Client.txt")
        candidates.Push(A_ProgramFiles "\Epic Games\PathOfExile\logs\Client.txt")
        if (doc != "")
            candidates.Push(doc "\My Games\Path of Exile\logs\Client.txt")
    }
    for i, c in candidates
        if FileExist(c)
            return c
    return ""
}

UpdateBranding()
{
    global AppName, MainHwnd, GameMode
    gn := (GameMode = "poe1") ? "Path of Exile 1" : "Path of Exile 2"
    if (MainHwnd and WinExist("ahk_id " . MainHwnd))
    {
        try WinSetTitle, ahk_id %MainHwnd%,, %AppName%
        try GuiControl, Main:, MainSub, %gn% — chat watcher
    }
    try Menu, Tray, Tip, %AppName%
}

StartWatching()
{
    global LogPath, Watching, hLog, IniFile, AppName
    if (LogPath = "" or !FileExist(LogPath))
    {
        MsgBox, 48, %AppName%, Cannot find the log file (Client.txt).`nUse the "Choose log..." button.
        return false
    }
    if IsObject(hLog)
    {
        try hLog.Close()
        hLog := ""
    }
    hLog := FileOpen(LogPath, "r", "UTF-8")
    if !IsObject(hLog)
    {
        MsgBox, 16, %AppName%, Cannot open the file:`n%LogPath%
        return false
    }
    hLog.Seek(0, 2)          ; start from the END (ignore old history)
    Watching := true
    SetTimer, TailLog, 500
    GuiControl, Main:, BtnToggle, Stop
    IniWrite, %LogPath%, %IniFile%, settings, log_path
    UpdateStatus()
    return true
}

StopWatching()
{
    global Watching, hLog
    Watching := false
    SetTimer, TailLog, Off
    if IsObject(hLog)
    {
        try hLog.Close()
        hLog := ""
    }
    GuiControl, Main:, BtnToggle, Start
    UpdateStatus()
}

TailLog:
    if (!Watching or !IsObject(hLog))
        return
    FileGetSize, size, %LogPath%
    if (ErrorLevel or size < hLog.Tell())    ; log recreated -> reopen
    {
        hLog := FileOpen(LogPath, "r", "UTF-8")
        if !IsObject(hLog)
        {
            StopWatching()
            SetStatus("ERROR — log unavailable")
            return
        }
        hLog.Seek(0, 2)
        return
    }
    newText := ""
    try newText := hLog.Read()
    catch
        return
    if (newText = "")
        return
    Loop, Parse, newText, `n, `r
    {
        line := A_LoopField
        if (line = "")
            continue
        hit := false
        if (Pattern != "" and RegExMatch(line, Pattern))
            hit := true
        else if (WatchPattern != "" and RegExMatch(line, WatchPattern))
            hit := true
        if (hit)
            OnMatch(line)
    }
return


; ============================================================
;  MATCH  ->  banner + sound + history + stats
; ============================================================
OnMatch(line)
{
    global MatchCount, WordParts, Words, CooldownSec, LastAlarm, ChanEnabled
    global WatchParts, WatchNames, WatchPattern, TradeOnly
    global RXNames, RXParts
    global MatchLogFile, AppName
    global PriceAlerts

    chan := ChannelOf(line)
    if (chan = "" or !ChanEnabled[chan])
        return                       ; channel ignored (unknown or disabled)

    foundWord := ""
    foundPrio := 0
    for i, p in WordParts
    {
        if RegExMatch(line, "i)" . p)
        {
            foundWord := Words[i].text
            foundPrio := Words[i].prio
            break
        }
    }

    foundItem := ""
    ; custom text/regex rules always apply (explicit user intent)
    for i, p in RXParts
    {
        if RegExMatch(line, "i)" . p)
        {
            foundItem := RXNames[i]
            break
        }
    }
    ; item-name watches are gated by the trade-only filter.
    ; A line in the TRADE channel itself is a trade signal (a shared/linked
    ; item there often has no "wts" keyword), so treat it as a trade line.
    if (foundItem = "" and WatchPattern != "" and RegExMatch(line, WatchPattern))
    {
        isTrade := (chan = "Trade") or RegExMatch(line, "i)(?<![A-Za-z0-9])(?:wts|wtb|wtt|selling|buying|sell|buy|iso|s>|b>)(?![A-Za-z0-9])")
        if (!TradeOnly or isTrade)
        {
            for i, p in WatchParts
            {
                if RegExMatch(line, "i)" . p)
                {
                    foundItem := WatchNames[i]
                    break
                }
            }
        }
    }

    label := (foundItem != "") ? foundItem : foundWord
    kind  := (foundItem != "") ? "ITEM" : "WORD"
    if (label = "")
        return

    MatchCount++

    name := ""
    fullMsg := ""
    if RegExMatch(line, "\] [#$%&]([^:]{1,40}): (.*)", m)
    {
        name := m1
        fullMsg := m2
    }
    else if RegExMatch(line, "\] @(?:From|To) ([^:]{1,40}): (.*)", m)
    {
        name := m1
        fullMsg := m2
    }
    if (fullMsg = "")
        fullMsg := Shorten(line)

    t := A_Hour . ":" . A_Min . ":" . A_Sec

    ; price: extract from the message, record it in the per-item history and
    ; flag it when a divine price drops below the configured threshold
    priceTxt := ""
    priceDrop := false
    if (kind = "ITEM" or chan = "Trade")
    {
        priceInfo := ExtractPrice(fullMsg)
        if (priceInfo != "")
        {
            priceTxt := priceInfo.amt " " priceInfo.cur
            SavePriceHist(label, priceInfo.amt, priceInfo.cur)
            MarkPricesDirty()            ; written to disk at most every few seconds
            if (priceInfo.cur = "divine" and PriceAlerts.HasKey(label) and priceInfo.amt < PriceAlerts[label])
                priceDrop := true
        }
    }

    if ((chan = "Trade" or kind = "ITEM") and !PassTradeFilter(fullMsg))
    {
        PushHistory(t, chan, name, label, fullMsg, line, priceTxt)
        return
    }

    UpdateStats(label)

    if (chan != "Whisper" and A_TickCount - LastAlarm < CooldownSec * 1000)
    {
        PushHistory(t, chan, name, label, fullMsg, line, priceTxt)
        return
    }
    LastAlarm := A_TickCount

    try FileAppend, % "[" . A_Now . "] " . line . "`r`n", %MatchLogFile%
    PushHistory(t, chan, name, label, fullMsg, line, priceTxt)
    OverlayPush(t, label, name, chan)

    shortMsg := Shorten(line)
    sndPrio := foundPrio
    if (chan = "Whisper" and sndPrio < 1)
        sndPrio := 1
    if (priceDrop and sndPrio < 2)
        sndPrio := 2
    TrayTip, %shortMsg%, %AppName% — Chat, 5, 2
    ShowAlert(label, chan, name, shortMsg, kind, sndPrio, priceTxt, priceDrop)
    if (kind = "ITEM")
        PlayItemSound()
    else
        PlayAlarmSound(chan, sndPrio)
    SendNotifyChat(label, chan, name, kind, shortMsg, priceTxt, priceDrop)
    UpdateStatus()
}

ChannelOf(line)
{
    if RegExMatch(line, "\[INFO Client \d+\] #")
        return "Global"
    if RegExMatch(line, "\[INFO Client \d+\] \$")
        return "Trade"
    if RegExMatch(line, "\[INFO Client \d+\] %")
        return "Party"
    if RegExMatch(line, "\[INFO Client \d+\] @From ")
        return "Whisper"
    if RegExMatch(line, "\[INFO Client \d+\] &")
        return "Guild"
    return ""
}

Shorten(line)
{
    p := RegExMatch(line, "\[INFO Client \d+\] (.*)", m) ? m1 : line
    if (StrLen(p) > 200)
        p := SubStr(p, 1, 200) . "..."
    return p
}

UpdateStats(word)
{
    global Stats
    if (word = "")
        word := "(unknown)"
    Stats[word] := Stats.HasKey(word) ? Stats[word] + 1 : 1
}


; ============================================================
;  SOUND
; ============================================================
GetCatColor(name)
{
    global CatColor
    return CatColor.HasKey(name) ? CatColor[name] : "7A7A82"
}

PlayAlarmSound(cat := "", prio := 0)
{
    global Muted, Volume, Beeps, CatSound, CustomSound
    if (Muted)
        return
    vol := Volume
    if (prio = 2)
        vol := 100
    else if (prio = 1 and vol < 80)
        vol := 80
    try SoundSet, %vol%
    snd := ""
    if (cat != "" and CatSound.HasKey(cat))
        snd := CatSound[cat]
    if (snd = "")
        snd := CustomSound
    if (snd != "" and FileExist(snd))
    {
        try SoundPlay, %snd%
        return
    }
    n := Beeps + (prio = 2 ? 4 : (prio = 1 ? 2 : 0))
    Loop, %n%
    {
        if (Muted)
            break
        SoundBeep, 880, 160
        SoundBeep, 1318, 160
        Sleep, 80
    }
}

PlayItemSound()
{
    global Muted, Volume, Beeps, ItemSound, CustomSound
    if (Muted)
        return
    try SoundSet, %Volume%
    snd := ItemSound
    if (snd = "")
        snd := CustomSound
    if (snd != "" and FileExist(snd))
    {
        try SoundPlay, %snd%
        return
    }
    Loop, %Beeps%
    {
        if (Muted)
            break
        SoundBeep, 1046, 150
        SoundBeep, 1568, 150
        Sleep, 70
    }
}


; ============================================================
;  MODERN ALERT BANNER
; ============================================================
ShowAlert(word, cat, player, msg, kind := "", prio := 0, priceTxt := "", priceDrop := false)
{
    global AppName, AlertPos, AlertWidth, AlertSec, hAlert, cDim, cText, cYellow, ItemColor
    col := (kind = "ITEM") ? ItemColor : GetCatColor(cat)
    if (prio >= 2)
        col := "D9534F"
    else if (prio = 1)
        col := "D9A441"
    catLabel := ((kind = "ITEM") ? "ITEM · " : "") . (priceDrop ? "DROP · " : "") . (prio = 2 ? "URGENT · " : (prio = 1 ? "HIGH · " : "")) . cat
    dur := Round(AlertSec * (prio = 2 ? 2.0 : (prio = 1 ? 1.5 : 1.0)))
    SetTimer, AlertClose, Off
    Gui, Alert:Destroy

    w  := AlertWidth
    h  := (player != "" and player != "Unknown") ? 118 : 102
    w2 := w - 40
    if (AlertPos = "bottom")
        yPos := A_ScreenHeight - h - 80
    else if (AlertPos = "center")
        yPos := Round((A_ScreenHeight - h) / 2)
    else
        yPos := 60
    xPos := Round((A_ScreenWidth - w) / 2)

    Gui, Alert:New, +AlwaysOnTop +ToolWindow -Caption +E0x20 +HWNDhAlert, %AppName%
    Gui, Alert:Color, 16161C
    Gui, Alert:Add, Text, x0 y0 w6 h%h% Background%col%,

    Gui, Alert:Font, s8 bold c%cDim%, Segoe UI
    Gui, Alert:Add, Text, x20 y10 w%w2% BackgroundTrans, CHAT ALERT
    Gui, Alert:Font, s8 bold c%col%, Segoe UI
    Gui, Alert:Add, Text, x20 y10 w%w2% Right BackgroundTrans, %catLabel%

    Gui, Alert:Font, s16 bold c%col%, Segoe UI
    Gui, Alert:Add, Text, x20 y30 w%w2% BackgroundTrans, % (word != "" ? ToUpper(word) : "WORD DETECTED")
    if (priceTxt != "")
    {
        Gui, Alert:Font, s13 bold c%cYellow%, Segoe UI
        Gui, Alert:Add, Text, x20 y34 w%w2% Right BackgroundTrans, % priceTxt
    }

    if (player != "" and player != "Unknown")
    {
        Gui, Alert:Font, s9 bold c%cYellow%, Segoe UI
        Gui, Alert:Add, Text, x20 y64 w%w2% BackgroundTrans, %player%
        Gui, Alert:Font, s9 norm c%cText%, Segoe UI
        Gui, Alert:Add, Text, x20 y84 w%w2% r2 BackgroundTrans, %msg%
    }
    else
    {
        Gui, Alert:Font, s9 norm c%cText%, Segoe UI
        Gui, Alert:Add, Text, x20 y64 w%w2% r2 BackgroundTrans, %msg%
    }

    Gui, Alert:Show, % "x" . xPos . " y" . yPos . " w" . w . " h" . h . " NoActivate", %AppName%
    WinSet, Transparent, 0, ahk_id %hAlert%
    Loop, 14
    {
        WinSet, Transparent, % A_Index * 18, ahk_id %hAlert%
        Sleep, 12
    }
    SetTimer, AlertClose, % -dur * 1000
}

AlertClose:
    if !WinExist("ahk_id " . hAlert)
        return
    Loop, 10
    {
        if !WinExist("ahk_id " . hAlert)
            return
        WinSet, Transparent, % 255 - A_Index * 25, ahk_id %hAlert%
        Sleep, 15
    }
    Gui, Alert:Destroy
return


; ============================================================
;  COPY TOAST  (small on-screen confirmation for clipboard actions)
; ============================================================
CopyToast(text, kind := "ok")
{
    global AppName, cBg, cText, cGood, cBad, hToast
    if (hToast and WinExist("ahk_id " . hToast))
        Gui, Toast:Destroy
    SetTimer, ToastClose, Off
    Gui, Toast:Destroy
    col := (kind = "err") ? cBad : cGood
    w := (StrLen(text) > 36) ? 480 : 340
    tw := w - 64
    Gui, Toast:New, +AlwaysOnTop +ToolWindow -Caption +E0x20 +HWNDhToast, %AppName%
    Gui, Toast:Color, %cBg%
    Gui, Toast:Add, Text, x0 y0 w6 h44 Background%col%,
    Gui, Toast:Font, s10 bold c%col%, Segoe UI
    Gui, Toast:Add, Text, x16 y0 w34 h44 Center BackgroundTrans, % (kind = "err") ? "!" : "OK"
    Gui, Toast:Font, s10 norm c%cText%, Segoe UI
    Gui, Toast:Add, Text, x54 y0 w%tw% h44 r2 BackgroundTrans, %text%
    xPos := Round((A_ScreenWidth - w) / 2)
    yPos := A_ScreenHeight - 96
    Gui, Toast:Show, % "x" . xPos . " y" . yPos . " w" . w . " h44 NoActivate",
    SetTimer, ToastClose, -1800
}

ToastClose:
    global hToast
    if (hToast and WinExist("ahk_id " . hToast))
        Gui, Toast:Destroy
    hToast := 0
return


; ============================================================
;  LIVE OVERLAY PANEL  (recent alerts + counter)
; ============================================================
OverlayPush(time, word, player, chan)
{
    global OverlayLines, OverlayOn, MatchCount, OVCount, OVLV
    OverlayLines.Push({time: time, word: word, player: player, chan: chan})
    if (OverlayLines.Length() > 12)
        OverlayLines.RemoveAt(1)
    if !OverlayOn
        return
    Gui, Overlay:Default
    Gui, Overlay:ListView, OVLV
    LV_Delete()
    Loop, % OverlayLines.Length()
    {
        e := OverlayLines[A_Index]
        LV_Add("", e.time, e.word, (e.player != "" ? e.player : "—"), e.chan)
    }
    if (OverlayLines.Length() > 0)
        LV_Modify(OverlayLines.Length(), "Vis")
    GuiControl, Overlay:, OVCount, % "Total: " . MatchCount . "   ·   Recent: " . OverlayLines.Length()
}

ToggleOverlay()
{
    global OverlayOn
    OverlayOn := !OverlayOn
    if (OverlayOn)
        BuildOverlay()
    else
        Gui, Overlay:Destroy
    RefreshOverlayMenu()
    SetStatus(OverlayOn ? "Overlay on (Ctrl+Alt+O)." : "Overlay off.")
}

BuildOverlay()
{
    global MatchCount, OverlayLines, OVCount, OVLV
    Gui, Overlay:Destroy
    Gui, Overlay:New, +AlwaysOnTop +ToolWindow -Caption +E0x08000020, Chat Alert overlay
    Gui, Overlay:Color, 12131A
    Gui, Overlay:Font, s9 bold cD9A441, Segoe UI
    Gui, Overlay:Add, Text, x14 y12 w292 h18 BackgroundTrans, ● CHAT ALERT — LIVE
    Gui, Overlay:Font, s8 norm c9AA0B0, Segoe UI
    Gui, Overlay:Add, Text, x14 y32 w292 h16 BackgroundTrans vOVCount, % "Total: " . MatchCount . "   ·   Recent: " . OverlayLines.Length()
    Gui, Overlay:Font, s8 norm cE8E8EE, Segoe UI
    Gui, Overlay:Add, ListView, x14 y52 w292 h182 vOVLV Grid -Multi Background1B1D26 cE8E8EE, Time|Word|Player|Ch
    Gui, Overlay:Default
    Gui, Overlay:ListView, OVLV
    LV_ModifyCol(1, 54)
    LV_ModifyCol(2, 96)
    LV_ModifyCol(3, 96)
    LV_ModifyCol(4, 40)
    Loop, % OverlayLines.Length()
    {
        e := OverlayLines[A_Index]
        LV_Add("", e.time, e.word, (e.player != "" ? e.player : "—"), e.chan)
    }
    x := A_ScreenWidth - 320 - 20
    Gui, Overlay:Show, % "x" . x . " y20 w320 h248 NoActivate", Chat Alert overlay
}

RefreshOverlayMenu()
{
    global OverlayOn
    Menu, Tray, % (OverlayOn ? "Check" : "Uncheck"), Overlay panel (Ctrl+Alt+O)
}

BtnOverlayToggle:
    ToggleOverlay()
return


; ============================================================
;  MAIN WINDOW
; ============================================================
FlatBtn(x, y, w, h, text, label, bg, fg)
{
    opt := "x" . x . " y" . y . " w" . w . " h" . h . " Center 0x200 Background" . bg . " c" . fg . " g" . label
    Gui, Main:Add, Text, %opt%, %text%
}

ShowWordOpts(row)
{
    global Words, WordOptRow, cBg, cPanel, cText, cDim, cGold, cInput
    global WoCase, WoWhole, WoPrio, WoRx
    WordOptRow := row
    o := Words[row]
    Gui, WordOpt:Destroy
    Gui, WordOpt:+OwnerMain -MaximizeBox -Resize
    Gui, WordOpt:Color, %cBg%
    Gui, WordOpt:Font, s9 norm c%cDim%, Segoe UI
    Gui, WordOpt:Add, Text, x18 y14 w320 h18, Options for this word:
    Gui, WordOpt:Font, s14 bold c%cGold%, Segoe UI
    Gui, WordOpt:Add, Text, x18 y34 w320 h24, % o.text
    Gui, WordOpt:Font, s9 norm c%cText%, Segoe UI
    cort := (o.cs ? "Checked" : "")
    Gui, WordOpt:Add, CheckBox, x18 y74 w320 h22 vWoCase %cort%, Case-sensitive (match exact letter case)
    wort := (o.ww ? "Checked" : "")
    Gui, WordOpt:Add, CheckBox, x18 y102 w320 h22 vWoWhole %wort%, Whole word only (not inside a larger word)
    rxt := (o.rx ? "Checked" : "")
    Gui, WordOpt:Add, CheckBox, x18 y130 w320 h22 vWoRx %rxt%, Regular expression (the text above is used as-is)
    Gui, WordOpt:Font, s9 norm c%cDim%, Segoe UI
    Gui, WordOpt:Add, Text, x18 y160 w320 h18 BackgroundTrans, Priority:
    psel := (o.prio = 1) ? "High" : (o.prio = 2 ? "Urgent" : "Normal")
    Gui, WordOpt:Font, s9 norm c%cText%, Segoe UI
    Gui, WordOpt:Add, DropDownList, x18 y180 w200 vWoPrio, Normal|High|Urgent
    GuiControl, WordOpt:ChooseString, WoPrio, %psel%
    Gui, WordOpt:Add, Button, x18 y220 w110 h30 Default gWordOptSave, Save
    Gui, WordOpt:Add, Button, x140 y220 w110 h30 gWordOptCancel, Cancel
    Gui, WordOpt:Show, w320 h264, Word options
    return
}

WordOptSave:
    Gui, WordOpt:Submit, NoHide
    GuiControlGet, pv, WordOpt:, WoPrio
    prio := (pv = "High") ? 1 : ((pv = "Urgent") ? 2 : 0)
    o := Words[WordOptRow]
    o.cs := WoCase
    o.ww := WoWhole
    o.rx := WoRx
    o.prio := prio
    if (o.rx and !RXValid(o.text))
    {
        badRx := "This is not a valid regular expression:" . "`n" . o.text
        MsgBox, 48, %AppName%, %badRx%
        return
    }
    Gui, WordOpt:Destroy
    SaveProfile(ActiveProfile)
    BuildPattern()
    RefreshWordList()
    SetStatus("Updated: " . o.text)
return

WordOptCancel:
WordOptGuiClose:
    Gui, WordOpt:Destroy
return

BuildMainGui()
{
    global AppName, cBg, cPanel, cLine, cText, cDim, cGold, cBtn, cBtnOn, cInput
    global Volume, Muted, LogPath, ProfileList, GameMode
    global StatusPill, ProfileDDL, WordsCount, NewWord
    global WordLV, HistLV, Vol, VolLabel, BtnToggle, BtnMute, StatusVal, LogLine, HistMsg, QuickReply
    global HistSearch, HistChan
    global MainHwnd, HistHwnd, MainSub

    Gui, Main:New, +HwndMainHwnd, %AppName%
    Gui, Main:Color, %cBg%
    Gui, Main:Font, s9 c%cText%, Segoe UI

    ; header
    Gui, Main:Font, s15 bold c%cGold%, Segoe UI
    Gui, Main:Add, Text, x18 y14 w300 BackgroundTrans, CHAT ALERT
    Gui, Main:Font, s9 norm c%cDim%, Segoe UI
    gn := (GameMode = "poe1") ? "Path of Exile 1" : "Path of Exile 2"
    Gui, Main:Add, Text, x18 y40 w320 BackgroundTrans vMainSub, %gn% — chat watcher
    Gui, Main:Font, s9 bold cFFFFFF, Segoe UI
    Gui, Main:Add, Text, x392 y18 w130 h22 Center 0x200 Background5E9E58 vStatusPill, WATCHING
    FlatBtn(532, 14, 130, 30, "Trade watch", "BtnWatch", "8A6A28", "FFFFFF")

    Gui, Main:Add, Text, x18 y66 w644 h1 Background%cLine%,

    ; profile row
    Gui, Main:Font, s9 norm c%cDim%, Segoe UI
    Gui, Main:Add, Text, x18 y82 w52 h20 BackgroundTrans, Profile
    plist := ""
    for i, p in ProfileList
        plist .= (plist = "" ? "" : "|") . p
    Gui, Main:Add, DropDownList, x74 y78 w160 c%cInput% vProfileDDL gProfileChanged, %plist%
    FlatBtn(242, 78, 56, 26, "New",    "BtnNewProfile", cBtn, cText)
    FlatBtn(302, 78, 64, 26, "Delete", "BtnDelProfile", cBtn, cText)
    FlatBtn(372, 78, 70, 26, "Export", "BtnExportProfile", cBtn, cText)
    FlatBtn(448, 78, 70, 26, "Import", "BtnImportProfile", cBtn, cText)

    ; words
    Gui, Main:Font, s9 bold c%cGold%, Segoe UI
    Gui, Main:Add, Text, x18 y116 w200 h18 BackgroundTrans, WORDS
    Gui, Main:Font, s8 norm c%cDim%, Segoe UI
    Gui, Main:Add, Text, x400 y118 w262 h16 Right BackgroundTrans vWordsCount,

    Gui, Main:Font, s9 norm c%cText%, Segoe UI
    Gui, Main:Add, Edit, x18 y138 w340 h24 c%cInput% vNewWord,
    FlatBtn(364, 138, 60, 24, "Add",    "BtnAddWords",   cBtn, cText)
    FlatBtn(430, 138, 70, 24, "Delete", "BtnDeleteWord", cBtn, cText)
    FlatBtn(506, 138, 86, 24, "Options...", "BtnWordOpts", cBtn, cText)

    Gui, Main:Add, ListView, x18 y170 w628 h116 vWordLV Grid -Multi Background%cPanel% c%cText% gWordDblClick, Word|Cs|WW|Prio
    Gui, Main:Default
    Gui, Main:ListView, WordLV
    LV_ModifyCol(1, 400)
    LV_ModifyCol(2, 70)
    LV_ModifyCol(3, 60)
    LV_ModifyCol(4, 80)

    ; history
    Gui, Main:Font, s9 bold c%cGold%, Segoe UI
    Gui, Main:Add, Text, x18 y296 w58 h18 BackgroundTrans, HISTORY
    Gui, Main:Font, s9 norm c%cText%, Segoe UI
    Gui, Main:Add, Edit, x78 y291 w132 h24 c%cInput% vHistSearch gHistFilterChanged,
    Gui, Main:Add, DropDownList, x214 y291 w86 vHistChan gHistFilterChanged, All|Global|Trade|Party|Whisper|Guild
    GuiControl, Main:Choose, HistChan, 1
    Gui, Main:Add, ComboBox, x304 y291 w118 vQuickReply, on my way|still available?|how much?|no thanks
    FlatBtn(428, 292, 56, 24, "Reply", "BtnQuickReply", cBtn, cText)
    FlatBtn(490, 292, 46, 24, "Copy",    "BtnCopy",  cBtn, cText)
    FlatBtn(540, 292, 56, 24, "Whisper", "BtnWhisper", cBtn, cText)
    FlatBtn(600, 292, 44, 24, "Clear",   "BtnClear", cBtn, cText)
    Gui, Main:Add, ListView, x18 y320 w628 h112 vHistLV Grid -Multi Background%cPanel% c%cText% gHistDblClick, Time|Ch|Player|Word|Message
    Gui, Main:Default
    Gui, Main:ListView, HistLV
    LV_ModifyCol(1, 50)     ; Time
    LV_ModifyCol(2, 46)     ; Ch
    LV_ModifyCol(3, 90)     ; Player
    LV_ModifyCol(4, 58)     ; Word
    LV_ModifyCol(5, 360)    ; Message (fills width; read full text in the box below)
    GuiControlGet, HistHwnd, Main:Hwnd, HistLV
    Gui, Main:Font, s9 norm c%cText%, Segoe UI
    Gui, Main:Add, Edit, x18 y438 w628 h104 ReadOnly Multi vHistMsg,
    GuiControl, Main:, HistMsg, Click a history row to read its full message here.
    SetTimer, HistHover, 220
    SetTimer, HistSelPoll, 300

    Gui, Main:Add, Text, x18 y550 w628 h1 Background%cLine%,

    ; controls
    Gui, Main:Add, Text, x18 y560 w92 h28 Center 0x200 Background%cBtn% c%cText% vBtnToggle gBtnToggle, Stop
    Gui, Main:Add, Text, x116 y560 w92 h28 Center 0x200 Background%cBtn% c%cText% vBtnMute gBtnMute, Mute
    Gui, Main:Font, s8 norm c%cDim%, Segoe UI
    Gui, Main:Add, Text, x216 y568 w30 h16 BackgroundTrans, VOL
    Gui, Main:Add, Slider, x248 y562 w128 vVol gVolChanged ToolTip Range0-100, %Volume%
    Gui, Main:Font, s9 norm c%cText%, Segoe UI
    Gui, Main:Add, Text, x380 y568 w34 h16 BackgroundTrans vVolLabel, %Volume%
    FlatBtn(422, 560, 96, 28, "Test sound",  "BtnTest",    cBtn, cText)
    FlatBtn(524, 560, 122, 28, "Choose log...", "BtnChooseLog", cBtn, cText)

    FlatBtn(18, 594, 92, 26, "Settings",   "BtnSettings",   cBtn, cText)
    FlatBtn(116, 594, 100, 26, "Categories", "BtnCategories", cBtn, cText)
    FlatBtn(222, 594, 74, 26, "Stats",     "BtnStats",      cBtn, cText)
    FlatBtn(302, 594, 100, 26, "Export CSV", "BtnExport",   cBtn, cText)
    FlatBtn(408, 594, 122, 26, "Open log file", "BtnOpenFolder", cBtn, cText)
    FlatBtn(536, 594, 118, 26, "Prices", "BtnPrices", cBtn, cText)

    Gui, Main:Font, s8 norm c%cDim%, Segoe UI
    Gui, Main:Add, Text, x18 y626 w644 h16 BackgroundTrans vStatusVal,
    Gui, Main:Add, Text, x18 y644 w644 h16 BackgroundTrans vLogLine,

    RefreshProfileDDL()
    RefreshWordList()
    GuiControl, Main:, BtnMute, % (Muted ? "Unmute" : "Mute")
    UpdateStatus()
}

; --- list / dropdown refreshers ---
RefreshProfileDDL()
{
    global ProfileList, ActiveProfile, cPanel
    GuiControl, Main:, ProfileDDL, |
    for i, p in ProfileList
        GuiControl, Main:, ProfileDDL, %p%
    GuiControl, Main:ChooseString, ProfileDDL, %ActiveProfile%
}

RefreshWordList()
{
    global Words, GameMode
    Gui, Main:Default
    Gui, Main:ListView, WordLV
    LV_Delete()
    prioName := ["", "High", "Urgent"]
    for i, o in Words
    {
        pn := (o.prio >= 1 and o.prio <= 2) ? prioName[o.prio] : ""
        LV_Add("", o.text, (o.rx ? "rx" : ((o.cs ? "yes" : ""))), (o.ww ? "yes" : ""), pn)
    }
    gn := (GameMode = "poe1") ? "Path of Exile 1" : "Path of Exile 2"
    GuiControl, Main:, WordsCount, % Words.Length() . " word(s) - " . gn
}

UpdateStatus()
{
    global Watching, Words, MatchCount, LogPath, cGood, cBad, StatusMsg
    if (Watching)
    {
        GuiControl, Main:, StatusPill, % "● WATCHING"
        GuiControl, Main:+Background%cGood%, StatusPill
    }
    else
    {
        GuiControl, Main:, StatusPill, % "○ STOPPED"
        GuiControl, Main:+Background%cBad%, StatusPill
    }
    GuiControl, Main:, StatusVal, % "Words: " . Words.Length() . "   ·   Matches: " . MatchCount . "   ·   " . (Watching ? "listening to chat (every 500 ms)" : "not watching")
    GuiControl, Main:, LogLine, % "Log: " . (LogPath != "" ? LogPath : "(not set)")
}

SetStatus(t)
{
    global StatusMsg
    StatusMsg := t
    GuiControl, Main:, StatusVal, %t%
    SetTimer, ClearStatus, -4000
}

ClearStatus:
    UpdateStatus()
return

PushHistory(time, chan, player, word, msg, line, price := "")
{
    global History, HistoryFile, HistoryMem, HistoryKeep, HistoryLines
    rec := {time: time, chan: chan, player: player, word: word, msg: msg, line: line, price: price}
    History.Push(rec)
    if (History.Length() > HistoryMem)
        History.RemoveAt(1)
    ; append-only: one line per match, written immediately so a crash cannot lose it
    StoreAppend(HistoryFile, StoreEsc(time) . "`t" . StoreEsc(chan) . "`t" . StoreEsc(player) . "`t" . StoreEsc(word) . "`t" . StoreEsc(msg) . "`t" . StoreEsc(line) . "`t" . StoreEsc(price))
    HistoryLines++
    if (HistoryLines > HistoryKeep)
        TrimHistoryFile()
    RefreshHistory()
}

; keep the history log bounded: rewrite it with the newest rows only
TrimHistoryFile()
{
    global History, HistoryFile, HistoryLines
    out := ""
    for i, h in History
        out .= StoreEsc(h.time) . "`t" . StoreEsc(h.chan) . "`t" . StoreEsc(h.player) . "`t" . StoreEsc(h.word) . "`t" . StoreEsc(h.msg) . "`t" . StoreEsc(h.line) . "`t" . StoreEsc(h.price) . "`r`n"
    StoreWrite(HistoryFile, out)
    HistoryLines := History.Length()
}

HistIdx(row)
{
    global HistView
    if (row < 1 or row > HistView.Length())
        return 0
    return HistView[row]
}

RefreshHistory()
{
    global History, HistView, HistFilter, HistChanFilter
    HistView := []
    Gui, Main:Default
    Gui, Main:ListView, HistLV
    LV_Delete()
    q := ToLower(Trim(HistFilter))
    for i, h in History
    {
        if (HistChanFilter != "" and HistChanFilter != "All" and h.chan != HistChanFilter)
            continue
        if (q != "")
        {
            hay := ToLower(h.msg . " " . h.player . " " . h.word . " " . h.line)
            if !InStr(hay, q)
                continue
        }
        HistView.Push(i)
        LV_Add("", h.time, h.chan, h.player, h.word, h.msg)
    }
    if (HistView.Length() > 0)
        LV_Modify(HistView.Length(), "Vis")
}

SaveHistory()
{
    ; history is append-only in its own file; nothing to do here
}

LoadHistory()
{
    global History, HistoryFile, HistoryMem, IniFile
    History := []
    ; one-time migration from the old INI section
    if (!FileExist(HistoryFile))
    {
        legacy := IniRawSection(IniFile, "history")
        for i, ln in legacy
        {
            p := InStr(ln, "=")
            if (!p)
                continue
            f := StrSplit(SubStr(ln, p + 1), "`t")
            if (f.Length() < 6)
                continue
            price := (f.Length() >= 7) ? f[7] : ""
            History.Push({time: f[1], chan: f[2], player: f[3], word: f[4], msg: f[5], line: f[6], price: price})
        }
        if (History.Length() > 0)
        {
            out := ""
            for i, h in History
                out .= StoreEsc(h.time) . "`t" . StoreEsc(h.chan) . "`t" . StoreEsc(h.player) . "`t" . StoreEsc(h.word) . "`t" . StoreEsc(h.msg) . "`t" . StoreEsc(h.line) . "`t" . StoreEsc(h.price) . "`r`n"
            StoreWrite(HistoryFile, out)
        }
    }
    txt := StoreRead(HistoryFile)
    if (txt = "")
        return
    lines := []
    Loop, Parse, txt, `n, `r
    {
        if (Trim(A_LoopField) = "")
            continue
        lines.Push(A_LoopField)
    }
    HistoryLines := lines.Length()
    ; keep only the newest HistoryMem rows
    if (lines.Length() > HistoryMem)
    {
        keep := []
        for i, ln in lines
        {
            if (i > lines.Length() - HistoryMem)
                keep.Push(ln)
        }
        lines := keep
    }
    for i, ln in lines
    {
        f := StrSplit(ln, "`t")
        if (f.Length() < 6)
            continue
        price := (f.Length() >= 7) ? f[7] : ""
        History.Push({time: StoreUnesc(f[1]), chan: StoreUnesc(f[2]), player: StoreUnesc(f[3]), word: StoreUnesc(f[4]), msg: StoreUnesc(f[5]), line: StoreUnesc(f[6]), price: StoreUnesc(price)})
    }
}

HistSelRow()
{
    Gui, Main:Default
    Gui, Main:ListView, HistLV
    return LV_GetNext(0)
}


; ============================================================
;  LABELS  —  main window buttons
; ============================================================
BtnAddWords:
    GuiControlGet, raw, Main:, NewWord
    if (Trim(raw) = "")
    {
        SetStatus("Type a word first.")
        return
    }
    incoming := []
    trimmed := Trim(raw)
    if (SubStr(trimmed, 1, 2) = "//" and SubStr(trimmed, -2) = "//" and StrLen(trimmed) > 4)
        incoming.Push(trimmed)          ; a single regex: never split it (it may contain commas)
    else
        incoming := SplitWords(raw)
    added := 0
    skipped := 0
    for i, w in incoming
    {
        ; //pattern// is treated as a regular expression
        isRx := (SubStr(w, 1, 2) = "//" and SubStr(w, -2) = "//" and StrLen(w) > 4)
        if (isRx)
            w := SubStr(w, 3, StrLen(w) - 4)
        else
            w := ToLower(w)
        if (w = "")
            continue
        if (isRx and !RXValid(w))
        {
            skipped++
            continue
        }
        dup := false
        for j, ex in Words
        {
            if (ex.text = w)
            {
                dup := true
                break
            }
        }
        if dup
            continue
        Words.Push({text: w, cs: 0, ww: 0, prio: 0, rx: isRx})
        added++
    }
    GuiControl, Main:, NewWord,
    if (added)
    {
        SaveProfile(ActiveProfile)
        BuildPattern()
        RefreshWordList()
    }
    if (skipped)
        SetStatus("Added " . added . " word(s), skipped " . skipped . " invalid regex.")
    else
        SetStatus("Added " . added . " word(s).")
return

BtnDeleteWord:
    Gui, Main:Default
    Gui, Main:ListView, WordLV
    row := LV_GetNext(0)
    if (row < 1)
    {
        SetStatus("Select a word in the list first.")
        return
    }
    w := Words[row].text
    Words.RemoveAt(row)
    SaveProfile(ActiveProfile)
    BuildPattern()
    RefreshWordList()
    SetStatus("Deleted: " . w)
return

WordDblClick:
    Gui, Main:Default
    Gui, Main:ListView, WordLV
    row := LV_GetNext(0)
    if (row < 1)
        return
    ShowWordOpts(row)
return

BtnWordOpts:
    Gui, Main:Default
    Gui, Main:ListView, WordLV
    row := LV_GetNext(0)
    if (row < 1)
    {
        SetStatus("Select a word in the list first.")
        return
    }
    ShowWordOpts(row)
return

BtnToggle:
    if (Watching)
        StopWatching()
    else
    {
        if (LogPath = "" or !FileExist(LogPath))
        {
            LogPath := FindPoELog()
            if (LogPath = "")
            {
                SetStatus("Log not found — click ""Choose log...""")
                return
            }
            if (GameMode = "poe1")
                LogPathPoe1 := LogPath
            else
                LogPathPoe2 := LogPath
            SaveSettings()
        }
        StartWatching()
    }
return

BtnMute:
    ToggleMute()
return

^!m::
    ToggleMute()
return

^!s::
    Gosub, BtnToggle
return

^!w::
    Gosub, BtnWatch
return

^!h::
    ToggleMain()
return

^!o::
    Gosub, BtnOverlayToggle
return

ToggleMain()
{
    global MainHwnd, AppName
    if !WinExist("ahk_id " . MainHwnd)
    {
        Gui, Main:Show, w680 h660, %AppName%
        return
    }
    if DllCall("IsWindowVisible", "Ptr", MainHwnd)
        Gui, Main:Hide
    else
        Gui, Main:Show, w680 h660, %AppName%
}

ToggleMute()
{
    global Muted, IniFile
    Muted := !Muted
    GuiControl, Main:, BtnMute, % (Muted ? "Unmute" : "Mute")
    IniWrite, %Muted%, %IniFile%, settings, muted
    SetStatus(Muted ? "Sound muted." : "Sound on.")
    TrayTip, % (Muted ? "Sound muted (Ctrl+Alt+M)" : "Sound on (Ctrl+Alt+M)"), Chat Alert, 2, 1
}

BtnTest:
    ShowAlert((Words.Length() > 0 ? Words[1].text : "test"), "Trade", "AnonymousPlayer", "[TEST] 210% rarity lfg — this is a test alert")
    PlayAlarmSound("Trade")
    SetStatus("Test alert fired.")
return

BtnChooseLog:
    FileSelectFile, picked, 3, %LogPath%, Choose the game's Client.txt file, Text / log (*.txt)
    if (picked != "" and FileExist(picked))
    {
        StopWatching()
        LogPath := picked
        IniWrite, %LogPath%, %IniFile%, settings, log_path
        StartWatching()
        SetStatus("Log set: " . LogPath)
    }
return

BtnOpenFolder:
    SplitPath, LogPath, , dir
    if (dir != "")
        Run, explorer.exe "%dir%"
return

VolChanged:
    GuiControlGet, v, Main:, Vol
    Volume := v
    try SoundSet, %Volume%
    GuiControl, Main:, VolLabel, %Volume%
return

ProfileChanged:
    GuiControlGet, sel, Main:, ProfileDDL
    if (sel = "" or sel = ActiveProfile)
        return
    SaveProfile(ActiveProfile)
    ActiveProfile := sel
    LoadProfile(ActiveProfile)
    SaveSettings()
    BuildPattern()
    RefreshWordList()
    SetStatus("Switched to profile: " . ActiveProfile)
return

BtnNewProfile:
    InputBox, pname, New profile, Name of the new profile:,, 280, 120
    if (ErrorLevel or Trim(pname) = "")
        return
    pname := Trim(pname)
    if InStr(pname, "|")
    {
        MsgBox, 48, %AppName%, The name cannot contain the "|" character.
        return
    }
    if HasProfile(pname)
    {
        MsgBox, 48, %AppName%, A profile with this name already exists.
        return
    }
    SaveProfile(ActiveProfile)
    ProfileList.Push(pname)
    SaveProfileList()
    ActiveProfile := pname
    Words := []
    SaveProfile(pname)
    SaveSettings()
    BuildPattern()
    RefreshProfileDDL()
    RefreshWordList()
    SetStatus("Created profile: " . pname)
return

BtnDelProfile:
    if (ProfileList.Length() <= 1)
    {
        MsgBox, 48, %AppName%, You cannot delete the last profile.
        return
    }
    MsgBox, 4, %AppName%, Delete profile "%ActiveProfile%" and all of its words?
    IfMsgBox, No
        return
    IniDelete, %IniFile%, profile:%ActiveProfile%
    newList := []
    for i, p in ProfileList
        if (p != ActiveProfile)
            newList.Push(p)
    ProfileList := newList
    SaveProfileList()
    ActiveProfile := ProfileList[1]
    LoadProfile(ActiveProfile)
    SaveSettings()
    BuildPattern()
    RefreshProfileDDL()
    RefreshWordList()
    SetStatus("Profile deleted.")
return

BtnExportProfile:
    if (Words.Length() = 0)
    {
        SetStatus("No words in this profile.")
        return
    }
    defName := A_ScriptDir . "\profile-" . ActiveProfile . ".ini"
    FileSelectFile, out, S16, %defName%, Export profile, INI (*.ini)
    if (out = "")
        return
    if !RegExMatch(out, "i)\.ini$")
        out .= ".ini"
    n := DoExportProfile(out)
    SetStatus("Exported " . n . " word(s).")
    MsgBox, 64, %AppName%, Profile "%ActiveProfile%" exported to:`n%out%
return

DoExportProfile(path)
{
    global Words, ActiveProfile, WordSets, GameMode
    FileDelete, %path%
    IniWrite, %ActiveProfile%, %path%, profile, name
    total := 0
    ; export the word list of every game, so a profile can be shared between PoE1 and PoE2
    for key, arr in WordSets
    {
        p := InStr(key, "|")
        if (!p)
            continue
        prof := SubStr(key, 1, p - 1)
        game := SubStr(key, p + 1)
        if (prof != ActiveProfile)
            continue
        for i, o in arr
        {
            sec := "words:" game
            IniWrite, % WordFlagsText(o), %path%, %sec%, % o.text
            total++
        }
    }
    if (total = 0)
    {
        secCur := "words:" GameMode
        for i, o in Words
        {
            IniWrite, % WordFlagsText(o), %path%, %secCur%, % o.text
            total++
        }
    }
    return total
}

BtnImportProfile:
    FileSelectFile, src, 3, %A_ScriptDir%, Import profile, INI (*.ini)
    if (src = "" or !FileExist(src))
        return
    added := DoImportProfile(src)
    if (added < 0)
    {
        MsgBox, 48, %AppName%, This file has no [words] or [profile:Default] section.
        return
    }
    SetStatus("Imported " . added . " word(s).")
    MsgBox, 64, %AppName%, Imported %added% word(s) into "%ActiveProfile%".
return

DoImportProfile(src)
{
    global Words, ActiveProfile, WordSets, GameMode
    added := 0
    ; new format: one section per game
    games := ["poe1", "poe2"]
    for gi, game in games
    {
        sec := "words:" game
        IniRead, out, %src%, %sec%
        if (out = "ERROR" or Trim(out) = "")
            continue
        seen := {}
        Loop, Parse, out, `n, `r
        {
            if (A_LoopField = "")
                continue
            p := InStr(A_LoopField, "=")
            if (!p)
                continue
            w := SubStr(A_LoopField, 1, p-1)
            if (w = "" or seen.HasKey(w))
                continue
            seen[w] := 1
            o := ParseWordFlags(w, SubStr(A_LoopField, p+1))
            if (!WordSetsHas(ActiveProfile, w, game))
            {
                WordSetsAdd(ActiveProfile, w, o, game)
                added++
            }
        }
    }
    if (added = 0)
    {
        ; old format: one shared word list
        IniRead, out, %src%, words
        if (out = "ERROR" or Trim(out) = "")
            IniRead, out, %src%, profile:Default
        if (out = "ERROR" or Trim(out) = "")
            return -1
        seen := {}
        Loop, Parse, out, `n, `r
        {
            if (A_LoopField = "")
                continue
            p := InStr(A_LoopField, "=")
            if (!p)
                continue
            w := SubStr(A_LoopField, 1, p-1)
            if (w = "" or seen.HasKey(w))
                continue
            seen[w] := 1
            o := ParseWordFlags(w, SubStr(A_LoopField, p+1))
            if (!WordSetsHas(ActiveProfile, w, GameMode))
            {
                WordSetsAdd(ActiveProfile, w, o, GameMode)
                added++
            }
        }
    }
    if (added = 0)
        return -1
    SaveWordSets()
    LoadProfile(ActiveProfile)
    BuildPattern()
    RefreshWordList()
    return added
}
    Loop, Parse, out, `n, `r

BtnCopy:
    row := HistSelRow()
    idx := HistIdx(row)
    if (idx < 1)
    {
        SetStatus("Select a history row first.")
        CopyToast("Select a history row first.", "err")
        return
    }
    Clipboard := History[idx].line
    SetStatus("Full line copied to clipboard.")
    CopyToast("Full line copied to clipboard.")
return

BtnWhisper:
    row := HistSelRow()
    idx := HistIdx(row)
    if (idx < 1)
    {
        SetStatus("Select a history row first.")
        CopyToast("Select a history row first.", "err")
        return
    }
    p := History[idx].player
    if (p = "")
    {
        SetStatus("That message has no player name.")
        CopyToast("That message has no player name.", "err")
        return
    }
    Clipboard := "/whisper " . p . " "
    SetStatus("Whisper to " . p . " copied — paste in the game chat.")
    CopyToast("/whisper " . p . "  —  paste in game chat")
return

BtnQuickReply:
    row := HistSelRow()
    idx := HistIdx(row)
    if (idx < 1)
    {
        SetStatus("Select a history row first.")
        CopyToast("Select a history row first.", "err")
        return
    }
    p := History[idx].player
    if (p = "")
    {
        SetStatus("That message has no player name.")
        CopyToast("That message has no player name.", "err")
        return
    }
    GuiControlGet, qr, Main:, QuickReply
    qr := Trim(qr)
    if (qr = "")
    {
        SetStatus("Type or choose a reply first.")
        CopyToast("Type or choose a reply first.", "err")
        return
    }
    Clipboard := "/whisper " . p . " " . qr
    SetStatus("Reply to " . p . " copied — paste in the game chat.")
    CopyToast("/whisper " . p . " " . qr . "  —  paste in game chat")
return

BtnClear:
    History := []
    HistView := []
    Gui, Main:Default
    Gui, Main:ListView, HistLV
    LV_Delete()
    SetStatus("History cleared.")
return

HistDblClick:
    row := HistSelRow()
    idx := HistIdx(row)
    if (idx < 1)
        return
    Clipboard := History[idx].line
    SetStatus("Full line copied to clipboard.")
    CopyToast("Full line copied to clipboard.")
return

HistFilterChanged:
    GuiControlGet, HistFilter, Main:, HistSearch
    GuiControlGet, HistChanFilter, Main:, HistChan
    RefreshHistory()
return

HistSelPoll:
    global History, HistShowRow
    Gui, Main:Default
    Gui, Main:ListView, HistLV
    row := LV_GetNext(0)
    if (row = HistShowRow)
        return
    HistShowRow := row
    idx := HistIdx(row)
    if (idx >= 1)
    {
        h := History[idx]
        GuiControl, Main:, HistMsg, % h.msg . "`r`n`r`n— " . h.player . "  [" . h.chan . "]  " . h.time
    }
    else
        GuiControl, Main:, HistMsg, Click a history row to read its full message here.
return

HistHover:
    global MainHwnd, HistHwnd, History
    MouseGetPos, mx, my, mhwnd, , 2
    if (mhwnd != MainHwnd)
    {
        ToolTip
        return
    }
    ctl := DllCall("WindowFromPoint", "Int64", (my << 32) | (mx & 0xFFFFFFFF), "Ptr")
    if (ctl != HistHwnd)
    {
        ToolTip
        return
    }
    VarSetCapacity(ptb, 8, 0)
    NumPut(mx, ptb, 0, "Int")
    NumPut(my, ptb, 4, "Int")
    DllCall("ScreenToClient", "Ptr", HistHwnd, "Ptr", &ptb)
    VarSetCapacity(hit, 28, 0)
    NumPut(NumGet(ptb, 0, "Int"), hit, 20, "Int")
    NumPut(NumGet(ptb, 4, "Int"), hit, 24, "Int")
    DllCall("SendMessage", "Ptr", HistHwnd, "UInt", 0x1012, "Ptr", 0, "Ptr", &hit)
    row := NumGet(hit, 8, "Int")
    idx := HistIdx(row)
    if (idx < 1)
    {
        ToolTip
        return
    }
    ToolTip, % History[idx].line, mx + 16, my + 22
return

GuiContextMenu:
    if (A_GuiControl != "HistLV")
        return
    row := A_EventInfo
    if (row < 1)
        return
    CtxRow := row
    Menu, Ctx, Show
return

CtxCopyLine:
    idx := HistIdx(CtxRow)
    if (idx < 1)
        return
    Clipboard := History[idx].line
    SetStatus("Full line copied.")
    CopyToast("Full line copied to clipboard.")
return

CtxCopyName:
    idx := HistIdx(CtxRow)
    if (idx < 1)
        return
    Clipboard := History[idx].player
    SetStatus("Player name copied.")
    CopyToast("Player name " . History[idx].player . " copied.")
return

CtxWhisper:
    idx := HistIdx(CtxRow)
    if (idx < 1)
        return
    Clipboard := "/whisper " . History[idx].player . " "
    SetStatus("Whisper copied — paste in game chat.")
    CopyToast("/whisper " . History[idx].player . "  —  paste in game chat")
return


; ============================================================
;  SETTINGS DIALOG
; ============================================================
BtnSettings:
    ShowSettings()
return

ShowSettings()
{
    global AppName, cBg, cPanel, cLine, cText, cDim, cGold, cInput
    global LogPath, CustomSound, Beeps, CooldownSec, AlertSec, AlertWidth, AlertPos, StartMinimized
    global PriceMin, PriceMax, BulkOnly, BulkMin
    global NotifyDiscordOn, NotifyNtfyOn, NotifyDiscord, NotifyNtfy
    global S_Log, S_Sound, S_Pos, S_Width, S_Beeps, S_Cool, S_Alert, S_Run, S_Min
    global S_PMin, S_PMax, S_Bulk, S_BMin
    global S_NDiscOn, S_NNtfyOn, S_NDiscord, S_NNtfy, S_Game
    global GameMode, SettingsOpen
    SettingsOpen := 1
    Gui, Set:Destroy
    Gui, Set:New, +OwnerMain, %AppName% — Settings
    Gui, Set:Color, %cBg%
    Gui, Set:Font, s9 c%cText%, Segoe UI

    Gui, Set:Add, Text, x18 y16 w120 BackgroundTrans, Log file:
    Gui, Set:Add, Edit, x18 y36 w400 h24 c%cInput% vS_Log, %LogPath%
    Gui, Set:Font, s9 c%cText%, Segoe UI
    Gui, Set:Add, Text, x426 y36 w60 h24 Center 0x200 Background%cPanel% gBrowseLog, Browse

    Gui, Set:Add, Text, x300 y16 w44 BackgroundTrans, Game:
    Gui, Set:Add, DropDownList, x346 y13 w140 c%cInput% vS_Game gSetGameChanged, Path of Exile 2|Path of Exile 1
    gLabel := (GameMode = "poe1") ? "Path of Exile 1" : "Path of Exile 2"
    GuiControl, Set:ChooseString, S_Game, %gLabel%

    Gui, Set:Font, s9 c%cText%, Segoe UI
    Gui, Set:Add, Text, x18 y70 w120 BackgroundTrans, Alarm sound (.wav):
    Gui, Set:Add, Edit, x18 y90 w400 h24 c%cInput% vS_Sound, %CustomSound%
    Gui, Set:Add, Text, x426 y90 w60 h24 Center 0x200 Background%cPanel% gBrowseSound, Browse

    Gui, Set:Add, Text, x18 y124 w120 BackgroundTrans, Banner position:
    Gui, Set:Add, DropDownList, x18 y144 w120 c%cInput% vS_Pos, top|center|bottom
    GuiControl, Set:ChooseString, S_Pos, %AlertPos%

    Gui, Set:Add, Text, x160 y124 w120 BackgroundTrans, Banner width:
    Gui, Set:Add, Edit, x160 y144 w80 h24 c%cInput% vS_Width, %AlertWidth%

    Gui, Set:Add, Text, x260 y124 w90 BackgroundTrans, Beeps:
    Gui, Set:Add, Edit, x260 y144 w60 h24 c%cInput% vS_Beeps, %Beeps%

    Gui, Set:Add, Text, x340 y124 w90 BackgroundTrans, Cooldown (s):
    Gui, Set:Add, Edit, x340 y144 w60 h24 c%cInput% vS_Cool, %CooldownSec%

    Gui, Set:Add, Text, x420 y124 w90 BackgroundTrans, Banner (s):
    Gui, Set:Add, Edit, x420 y144 w60 h24 c%cInput% vS_Alert, %AlertSec%

    Gui, Set:Font, s9 c%cText%, Segoe UI
    Gui, Set:Add, CheckBox, x18 y186 w300 vS_Run BackgroundTrans c%cText%, Start with Windows (login)
    Gui, Set:Add, CheckBox, x18 y210 w300 vS_Min BackgroundTrans c%cText%, Start minimized in the tray
    GuiControl, Set:, S_Min, %StartMinimized%
    runState := GetRunAtStartup()
    GuiControl, Set:, S_Run, %runState%

    ; --- external notifications ---
    Gui, Set:Font, s9 c%cText%, Segoe UI
    Gui, Set:Add, Text, x18 y238 w60 BackgroundTrans, Notify:
    Gui, Set:Add, CheckBox, x80 y240 w80 vS_NDiscOn BackgroundTrans c%cText%, Discord
    GuiControl, Set:, S_NDiscOn, %NotifyDiscordOn%
    Gui, Set:Add, CheckBox, x170 y240 w80 vS_NNtfyOn BackgroundTrans c%cText%, ntfy
    GuiControl, Set:, S_NNtfyOn, %NotifyNtfyOn%
    Gui, Set:Font, s8 c%cDim%, Segoe UI
    Gui, Set:Add, Text, x18 y266 w104 h24 BackgroundTrans, Discord webhook:
    Gui, Set:Add, Text, x18 y296 w104 h24 BackgroundTrans, ntfy topic URL:
    Gui, Set:Font, s9 c%cText%, Segoe UI
    Gui, Set:Add, Edit, x126 y262 w356 h24 c%cInput% vS_NDiscord, %NotifyDiscord%
    Gui, Set:Add, Edit, x126 y292 w356 h24 c%cInput% vS_NNtfy, %NotifyNtfy%
    Gui, Set:Font, s8 c%cDim%, Segoe UI
    Gui, Set:Add, Text, x18 y320 w464 BackgroundTrans, Tick the providers to use. Both can be enabled at the same time.

    Gui, Set:Add, Text, x18 y342 w464 h1 Background%cLine%,
    Gui, Set:Font, s8 c%cDim%, Segoe UI
    Gui, Set:Add, Text, x18 y350 w464 BackgroundTrans, Trade filters (0 = off). Prices are plain numbers found in trade messages.

    Gui, Set:Font, s9 c%cText%, Segoe UI
    Gui, Set:Add, Text, x18 y374 w30 BackgroundTrans, Min
    Gui, Set:Add, Edit, x50 y370 w60 h24 c%cInput% vS_PMin, %PriceMin%
    Gui, Set:Add, Text, x120 y374 w30 BackgroundTrans, Max
    Gui, Set:Add, Edit, x152 y370 w60 h24 c%cInput% vS_PMax, %PriceMax%
    Gui, Set:Add, CheckBox, x228 y372 w90 vS_Bulk BackgroundTrans c%cText%, Only bulk
    GuiControl, Set:, S_Bulk, %BulkOnly%
    Gui, Set:Add, Text, x326 y374 w60 BackgroundTrans, Bulk min
    Gui, Set:Add, Edit, x390 y370 w48 h24 c%cInput% vS_BMin, %BulkMin%

    Gui, Set:Add, Text, x18 y404 w464 h1 Background%cLine%,
    Gui, Set:Font, s8 c%cDim%, Segoe UI
    Gui, Set:Add, Text, x18 y412 w464 BackgroundTrans, The alarm sound is used only if the matched category has no sound of its own.

    Gui, Set:Font, s9 c%cText%, Segoe UI
    Gui, Set:Add, Text, x18 y450 w70 h28 Center 0x200 Background3E5A3E gSetDoSave cFFFFFF, Save
    Gui, Set:Add, Text, x98 y450 w70 h28 Center 0x200 Background%cPanel% gCloseSettings, Cancel
    Gui, Set:Add, Text, x178 y450 w90 h28 Center 0x200 Background%cPanel% gTestFromSettings, Test sound
    Gui, Set:Add, Text, x278 y450 w92 h28 Center 0x200 Background%cPanel% gTestNotify, Test notify

    Gui, Set:Show, w512 h506, %AppName% — Settings
}

BrowseLog:
    GuiControlGet, cur, Set:, S_Log
    FileSelectFile, picked, 3, %cur%, Choose Client.txt, Text (*.txt)
    if (picked != "")
        GuiControl, Set:, S_Log, %picked%
return

BrowseSound:
    GuiControlGet, cur, Set:, S_Sound
    FileSelectFile, picked, 3, %cur%, Choose a .wav file, Sound (*.wav)
    if (picked != "")
        GuiControl, Set:, S_Sound, %picked%
return

TestFromSettings:
    GuiControlGet, snd, Set:, S_Sound
    GuiControlGet, vol, Main:, Vol
    if (FileExist(snd))
        try SoundPlay, %snd%
    else
        PlayAlarmSound("Alerts")
return

TestNotify:
    GuiControlGet, vNDiscOn, Set:, S_NDiscOn
    GuiControlGet, vNNtfyOn, Set:, S_NNtfyOn
    GuiControlGet, vNDisc,   Set:, S_NDiscord
    GuiControlGet, vNNtfy,   Set:, S_NNtfy
    vNDisc := Trim(vNDisc)
    vNNtfy := Trim(vNNtfy)
    provs := ""
    if (vNDiscOn)
        provs .= (provs = "" ? "" : " + ") . "discord"
    if (vNNtfyOn)
        provs .= (provs = "" ? "" : " + ") . "ntfy"
    if (provs = "")
    {
        MsgBox, 48, %AppName%, Tick Discord and/or ntfy first.
        return
    }
    if (vNDiscOn and vNDisc = "")
    {
        MsgBox, 48, %AppName%, Enter the Discord webhook URL first.
        return
    }
    if (vNNtfyOn and vNNtfy = "")
    {
        MsgBox, 48, %AppName%, Enter the ntfy topic URL first.
        return
    }
    savedDiscordOn := NotifyDiscordOn
    savedNtfyOn    := NotifyNtfyOn
    savedDiscord   := NotifyDiscord
    savedNtfy      := NotifyNtfy
    NotifyDiscordOn := (vNDiscOn ? 1 : 0)
    NotifyNtfyOn    := (vNNtfyOn ? 1 : 0)
    NotifyDiscord   := vNDisc
    NotifyNtfy      := vNNtfy
    res := SendNotify(AppName, "Test notification from " . AppName . ". If you see this on your phone, it works.")
    NotifyDiscordOn := savedDiscordOn
    NotifyNtfyOn    := savedNtfyOn
    NotifyDiscord   := savedDiscord
    NotifyNtfy      := savedNtfy
    if (res = "ok")
    {
        SetStatus("Test notification sent (" . provs . ").")
        CopyToast("Test notification sent via " . provs, "ok")
    }
    else
    {
        SetStatus("Test notification FAILED (" . provs . ").")
        msg := "Could not send the test notification via " . provs . "." . "`n`n" . res
        msg .= "`n`nCheck the URL(s) and that the phone is subscribed to the same ntfy topic."
        MsgBox, 16, %AppName%, %msg%
    }
return

SetGameChanged:
    GuiControlGet, gLabel, Set:, S_Game
    newGame := (gLabel = "Path of Exile 1") ? "poe1" : "poe2"
    if (newGame = GameMode)
        return
    SaveProfile(ActiveProfile)          ; keep the current game's word list
    StopWatching()
    GameMode := newGame
    ApplyGameMode()
    UpdateBranding()
    LoadProfile(ActiveProfile)          ; load the new game's word list
    BuildPattern()
    RefreshWordList()
    p := (GameMode = "poe1") ? LogPathPoe1 : LogPathPoe2
    if (p = "" or !FileExist(p))
        p := FindPoELog(GameMode)
    if (GameMode = "poe1")
        LogPathPoe1 := p
    else
        LogPathPoe2 := p
    LogPath := p
    LoadItems()
    BuildWatchPattern()
    SaveSettings()
    if (LogPath != "" and FileExist(LogPath))
    {
        StartWatching()
        UpdateStatus()
        SetStatus(AppName . " — watching")
    }
    else
    {
        UpdateStatus()
        SetStatus("No log found for " . ((GameMode = "poe1") ? "PoE1" : "PoE2") . " — use Browse to pick it.")
        GuiControl, Main:, BtnToggle, Start
    }
    SetTimer, ReopenSettings, -80
return

ReopenSettings:
    if SettingsOpen
    {
        Gui, Set:Destroy
        ShowSettings()
    }
return

SetDoSave:
    SettingsOpen := 0
    GuiControlGet, vLog,   Set:, S_Log
    GuiControlGet, vSnd,   Set:, S_Sound
    GuiControlGet, vPos,   Set:, S_Pos
    GuiControlGet, vWidth, Set:, S_Width
    GuiControlGet, vB,     Set:, S_Beeps
    GuiControlGet, vC,     Set:, S_Cool
    GuiControlGet, vA,     Set:, S_Alert
    GuiControlGet, vRun,   Set:, S_Run
    GuiControlGet, vMin,   Set:, S_Min
    GuiControlGet, vPMin,  Set:, S_PMin
    GuiControlGet, vPMax,  Set:, S_PMax
    GuiControlGet, vBulk,  Set:, S_Bulk
    GuiControlGet, vBMin,  Set:, S_BMin
    GuiControlGet, vNDiscOn, Set:, S_NDiscOn
    GuiControlGet, vNNtfyOn, Set:, S_NNtfyOn
    GuiControlGet, vNDisc, Set:, S_NDiscord
    GuiControlGet, vNNtfy, Set:, S_NNtfy

    ; validate numbers
    vB := (vB < 1) ? 1 : (vB > 20 ? 20 : vB)
    vC := (vC < 0) ? 0 : (vC > 300 ? 300 : vC)
    vA := (vA < 3) ? 3 : (vA > 60 ? 60 : vA)
    vWidth := (vWidth < 260) ? 260 : (vWidth > 900 ? 900 : vWidth)
    vPMin := (vPMin < 0) ? 0 : vPMin
    vPMax := (vPMax < 0) ? 0 : vPMax
    vBMin := (vBMin < 0) ? 0 : vBMin

    Beeps       := vB
    CooldownSec := vC
    AlertSec    := vA
    AlertWidth  := vWidth
    AlertPos    := (vPos = "" ? "top" : vPos)
    StartMinimized := vMin
    CustomSound := vSnd
    PriceMin    := vPMin + 0
    PriceMax    := vPMax + 0
    BulkOnly    := (vBulk ? 1 : 0)
    BulkMin     := vBMin + 0
    NotifyDiscordOn := (vNDiscOn ? 1 : 0)
    NotifyNtfyOn    := (vNNtfyOn ? 1 : 0)
    NotifyDiscord := Trim(vNDisc)
    NotifyNtfy    := Trim(vNNtfy)
    if (vSnd != "" and FileExist(vSnd))
        try SoundSet, %Volume%

    newLog := Trim(vLog)

    ; keep the selected game in sync with the chosen log file
    det := ""
    if InStr(newLog, "Path of Exile 2")
        det := "poe2"
    else if InStr(newLog, "Path of Exile")
        det := "poe1"
    if (det != "" and det != GameMode)
    {
        SaveProfile(ActiveProfile)
        StopWatching()
        GameMode := det
        ApplyGameMode()
        UpdateBranding()
        LoadProfile(ActiveProfile)
        BuildPattern()
        RefreshWordList()
        LoadItems()
        BuildWatchPattern()
    }
    if (GameMode = "poe1")
        LogPathPoe1 := newLog
    else
        LogPathPoe2 := newLog

    if (newLog != LogPath)
    {
        StopWatching()
        LogPath := newLog
        if (LogPath != "" and FileExist(LogPath))
            StartWatching()
        else
            SetStatus("Log changed but not found.")
    }

    SetRunAtStartup(vRun)
    SaveSettings()
    SaveTrade()
    Gui, Set:Destroy
    SetStatus("Settings saved.")
return

CloseSettings:
    SettingsOpen := 0
    Gui, Set:Destroy
return

GetRunAtStartup()
{
    RegRead, v, HKCU, Software\Microsoft\Windows\CurrentVersion\Run, ChatAlertPoE2
    return (ErrorLevel = 0 and v != "") ? 1 : 0
}

SetRunAtStartup(enable)
{
    key := "Software\Microsoft\Windows\CurrentVersion\Run"
    if (enable)
        RegWrite, REG_SZ, HKCU, %key%, ChatAlertPoE2, "%A_AhkPath%" "%A_ScriptFullPath%"
    else
        RegDelete, HKCU, %key%, ChatAlertPoE2
}


; ============================================================
;  CATEGORIES DIALOG
; ============================================================
BtnCategories:
    ShowCategories()
return

ShowCategories()
{
    global AppName, cBg, cPanel, cLine, cText, cDim, cGold, CatOrder, PaletteOrder, cInput
    global CatPick, CatColorDDL, CatSwatch2, CatSoundEdit, CatEnabled
    Gui, Cat:Destroy
    Gui, Cat:New, +OwnerMain, %AppName% — Categories
    Gui, Cat:Color, %cBg%
    Gui, Cat:Font, s9 c%cText%, Segoe UI

    Gui, Cat:Add, Text, x18 y18 w100 BackgroundTrans, Channel:
    catList := ""
    for i, c in CatOrder
        catList .= (catList = "" ? "" : "|") . c
    Gui, Cat:Add, DropDownList, x18 y38 w200 c%cInput% vCatPick gCatPickChanged, %catList%

    Gui, Cat:Add, Text, x18 y72 w100 BackgroundTrans, Color:
    colList := ""
    for i, c in PaletteOrder
        colList .= (colList = "" ? "" : "|") . c
    Gui, Cat:Add, DropDownList, x18 y92 w140 c%cInput% vCatColorDDL gCatPreview, %colList%
    Gui, Cat:Add, Text, x170 y92 w160 h24 Background7A7A82 vCatSwatch2,

    Gui, Cat:Add, Text, x18 y126 w200 BackgroundTrans, Sound for this channel (.wav):
    Gui, Cat:Add, Edit, x18 y146 w420 h24 c%cInput% vCatSoundEdit,
    Gui, Cat:Add, Text, x446 y146 w70 h24 Center 0x200 Background%cPanel% gBrowseCatSound, Browse
    Gui, Cat:Font, s8 c%cDim%, Segoe UI
    Gui, Cat:Add, Text, x18 y176 w498 BackgroundTrans, Leave empty to use the general alarm sound from Settings.

    Gui, Cat:Font, s9 c%cText%, Segoe UI
    Gui, Cat:Add, CheckBox, x18 y202 w320 h24 BackgroundTrans vCatEnabled, Alert for this channel

    Gui, Cat:Add, Text, x18 y238 w80 h28 Center 0x200 Background3E5A3E gCatApply cFFFFFF, Apply
    Gui, Cat:Add, Text, x108 y238 w90 h28 Center 0x200 Background%cPanel% gCatClose, Close
    Gui, Cat:Font, s8 c%cDim%, Segoe UI
    Gui, Cat:Add, Text, x18 y280 w498 BackgroundTrans, Channels: Global (#) · Trade ($) · Party (`%) · Whisper (@From) · Guild (&).

    Gui, Cat:Show, w512 h316, %AppName% — Categories
    Gosub, CatPickChanged
}

CatPickChanged:
    GuiControlGet, pick, Cat:, CatPick
    if (pick = "")
        return
    col := GetCatColor(pick)
    ; find palette name by hex
    colName := ""
    for i, pn in PaletteOrder
        if (Palette[pn] = col)
            colName := pn
    if (colName != "")
        GuiControl, Cat:ChooseString, CatColorDDL, %colName%
    snd := CatSound.HasKey(pick) ? CatSound[pick] : ""
    GuiControl, Cat:, CatSoundEdit, %snd%
    GuiControl, Cat:+Background%col%, CatSwatch2
    GuiControl, Cat:, CatEnabled, % (ChanEnabled[pick] ? 1 : 0)
return

CatPreview:
    GuiControlGet, pn, Cat:, CatColorDDL
    if (pn = "")
        return
    pcol := Palette[pn]
    GuiControl, Cat:+Background%pcol%, CatSwatch2
return

BrowseCatSound:
    GuiControlGet, cur, Cat:, CatSoundEdit
    FileSelectFile, picked, 3, %cur%, Choose a .wav file, Sound (*.wav)
    if (picked != "")
        GuiControl, Cat:, CatSoundEdit, %picked%
return

CatApply:
    GuiControlGet, pick, Cat:, CatPick
    GuiControlGet, pn,  Cat:, CatColorDDL
    GuiControlGet, snd, Cat:, CatSoundEdit
    GuiControlGet, en,  Cat:, CatEnabled
    if (pick = "")
        return
    if (pn != "")
        CatColor[pick] := Palette[pn]
    CatSound[pick] := Trim(snd)
    ChanEnabled[pick] := (en ? 1 : 0)
    SaveCategories()
    SetStatus("Channel """ . pick . """ updated.")
return

CatClose:
    Gui, Cat:Destroy
return

RefreshCatDDL()
{
    global CatOrder
    GuiControl, Cat:, CatPick, |
    for i, c in CatOrder
        GuiControl, Cat:, CatPick, %c%
}


; ============================================================
;  TRADE WATCH DIALOG
; ============================================================
BtnWatch:
    ShowTradeWatch()
return

ShowTradeWatch()
{
    global AppName, cBg, cPanel, cLine, cText, cDim, cInput, PaletteOrder
    global Items, WatchList, WatchOn, TradeOnly, ItemColor, ItemSound
    global W_Search, W_Results, W_Watch, W_Enabled, W_TradeOnly, W_Color, W_Swatch, W_Sound
    global W_RuleEdit, W_Rules, W_RuleEnabled

    Gui, Watch:Destroy
    Gui, Watch:New, +OwnerMain, %AppName% — Trade Watch
    Gui, Watch:Color, %cBg%
    Gui, Watch:Font, s9 c%cText%, Segoe UI

    n := Items.Length()
    Gui, Watch:Add, Text, x18 y16 w360 BackgroundTrans, Item database (%n% entries):
    Gui, Watch:Add, Edit, x18 y36 w360 h24 c%cInput% vW_Search gW_SearchChanged,
    Gui, Watch:Add, ListBox, x18 y64 w360 h168 c%cInput% vW_Results gW_ResultsPick,
    Gui, Watch:Font, s8 c%cDim%, Segoe UI
    Gui, Watch:Add, Text, x18 y236 w360 BackgroundTrans, Type to filter. Double-click a result (or select + Add).
    Gui, Watch:Font, s9 c%cText%, Segoe UI
    Gui, Watch:Add, Text, x18 y258 w150 h28 Center 0x200 Background3E5A3E gW_Add cFFFFFF, Add to watch
    Gui, Watch:Add, Text, x174 y258 w150 h28 Center 0x200 Background%cPanel% gW_FetchItems, Update items (API)

    Gui, Watch:Add, Text, x400 y16 w200 BackgroundTrans, Watched items:
    Gui, Watch:Add, ListBox, x400 y36 w200 h168 c%cInput% vW_Watch gW_WatchPick,
    Gui, Watch:Add, CheckBox, x400 y212 w200 h22 BackgroundTrans vW_Enabled gW_ToggleItem, Alert for this item
    Gui, Watch:Add, Text, x400 y240 w96 h28 Center 0x200 Background%cPanel% gW_Remove, Remove
    Gui, Watch:Add, Text, x500 y240 w100 h28 Center 0x200 Background%cPanel% gW_SetPrice, Price alert
    Gui, Watch:Add, CheckBox, x400 y276 w210 h22 BackgroundTrans vW_TradeOnly, Only alert on trade lines

    Gui, Watch:Font, s8 c%cDim%, Segoe UI
    Gui, Watch:Add, Text, x18 y300 w580 BackgroundTrans, Custom rules — matched against the whole message (text or regex). Syntax:  friendly name => regex
    Gui, Watch:Font, s9 c%cText%, Segoe UI
    Gui, Watch:Add, Edit, x18 y320 w440 h24 c%cInput% vW_RuleEdit,
    Gui, Watch:Add, Text, x466 y320 w136 h24 Center 0x200 Background3E5A3E gW_AddRule cFFFFFF, Add rule
    Gui, Watch:Add, ListBox, x18 y352 w440 h130 c%cInput% vW_Rules gW_RulesPick,
    Gui, Watch:Add, CheckBox, x466 y352 w140 h22 BackgroundTrans vW_RuleEnabled gW_ToggleRule, Rule enabled
    Gui, Watch:Add, Text, x466 y384 w120 h26 Center 0x200 Background%cPanel% gW_RemoveRule, Remove rule

    Gui, Watch:Add, Text, x18 y498 w120 BackgroundTrans, Item alert color:
    colList := ""
    for i, c in PaletteOrder
        colList .= (colList = "" ? "" : "|") . c
    Gui, Watch:Add, DropDownList, x140 y496 w120 c%cInput% vW_Color gW_ColorPreview, %colList%
    Gui, Watch:Add, Text, x264 y496 w40 h24 Background7A7A82 vW_Swatch,
    Gui, Watch:Add, Text, x312 y498 w80 BackgroundTrans, Sound (.wav):
    Gui, Watch:Add, Edit, x396 y496 w150 h24 c%cInput% vW_Sound,
    Gui, Watch:Add, Text, x552 y496 w60 h24 Center 0x200 Background%cPanel% gW_BrowseSound, Browse

    Gui, Watch:Add, Text, x18 y534 w80 h30 Center 0x200 Background3E5A3E gW_Save cFFFFFF, Save
    Gui, Watch:Add, Text, x108 y534 w80 h30 Center 0x200 Background%cPanel% gW_Close, Close
    Gui, Watch:Font, s8 c%cDim%, Segoe UI
    Gui, Watch:Add, Text, x198 y540 w420 BackgroundTrans, Rules always fire; item names obey the trade-only filter.

    Gui, Watch:Show, w620 h600, %AppName% — Trade Watch

    Gosub, W_LoadSettings
    Gosub, W_RefreshResults
    Gosub, W_RefreshWatch
    Gosub, W_RefreshRules
}

RuleRaw(sel)
{
    if (SubStr(sel, 1, 6) = "(off) ")
        return SubStr(sel, 7)
    return sel
}

W_LoadSettings:
    global ItemColor, ItemSound, TradeOnly, PaletteOrder, Palette
    colName := ""
    for i, pn in PaletteOrder
        if (Palette[pn] = ItemColor)
            colName := pn
    if (colName != "")
        GuiControl, Watch:ChooseString, W_Color, %colName%
    else
        GuiControl, Watch:ChooseString, W_Color, Orange
    GuiControl, Watch:, W_Swatch, 
    GuiControl, Watch:+Background%ItemColor%, W_Swatch
    GuiControl, Watch:, W_Sound, %ItemSound%
    GuiControl, Watch:, W_TradeOnly, %TradeOnly%
    GuiControl, Watch:, W_RuleEdit, 
return

W_SearchChanged:
    Gosub, W_RefreshResults
return

W_RefreshResults:
    global Items, ItemsLower
    GuiControlGet, q, Watch:, W_Search
    ql := ToLower(Trim(q))
    GuiControl, Watch:, W_Results, |
    n := 0
    Loop, % Items.Length()
    {
        i := A_Index
        if (ql != "" and !InStr(ItemsLower[i], ql))
            continue
        GuiControl, Watch:, W_Results, % Items[i].name
        n++
        if (n >= 400)
            break
    }
return

W_ResultsPick:
    if (A_GuiEvent = "DoubleClick")
        Gosub, W_Add
return

W_RefreshWatch:
    global WatchList
    GuiControl, Watch:, W_Watch, |
    for i, nm in WatchList
        GuiControl, Watch:, W_Watch, %nm%
    GuiControl, Watch:, W_Enabled, 0
return

W_WatchPick:
    global WatchOn
    GuiControlGet, sel, Watch:, W_Watch
    if (sel = "")
        return
    GuiControl, Watch:, W_Enabled, % (WatchOn.HasKey(sel) ? WatchOn[sel] : 1)
return

W_ToggleItem:
    global WatchOn
    GuiControlGet, sel, Watch:, W_Watch
    if (sel = "")
        return
    GuiControlGet, en, Watch:, W_Enabled
    WatchOn[sel] := (en ? 1 : 0)
    BuildWatchPattern()
    SaveWatch()
    SetStatus("Item """ . sel . """" . (en ? " enabled" : " disabled") . ".")
return

W_FetchItems:
    SetStatus("Downloading item data...")
    n := FetchItemsFromApi()
    if (n < 0)
    {
        SetStatus("Item update failed.")
        MsgBox, 48, %AppName%, Could not download item data (check your connection). The existing database was kept.
        return
    }
    GuiControl, Watch:, W_Results, |
    Gosub, W_RefreshResults
    Gosub, W_RefreshWatch
    SetStatus("Item database updated (" . n . " entries).")
    MsgBox, 64, %AppName%, Item database updated: %n% entries.
return

W_Add:
    global WatchList, WatchOn
    GuiControlGet, sel, Watch:, W_Results
    if (sel = "")
    {
        SetStatus("Select an item from the list first.")
        return
    }
    exists := false
    for i, nm in WatchList
        if (nm = sel)
            exists := true
    if !exists
    {
        WatchList.Push(sel)
        WatchOn[sel] := 1
        BuildWatchPattern()
        SaveWatch()
        SetStatus("Now watching: " . sel)
    }
    Gosub, W_RefreshWatch
return

W_Remove:
    global WatchList, WatchOn, PriceAlerts
    GuiControlGet, sel, Watch:, W_Watch
    if (sel = "")
        return
    idx := 0
    for i, nm in WatchList
        if (nm = sel)
            idx := i
    if (idx = 0)
        return
    WatchList.RemoveAt(idx)
    WatchOn.Delete(sel)
    if PriceAlerts.HasKey(sel)
    {
        PriceAlerts.Delete(sel)
        SavePrices()
    }
    BuildWatchPattern()
    SaveWatch()
    SetStatus("Removed from watch: " . sel)
    Gosub, W_RefreshWatch
return

W_SetPrice:
    global AppName, PriceAlerts
    GuiControlGet, sel, Watch:, W_Watch
    if (sel = "")
    {
        MsgBox, 48, %AppName%, Select a watched item first.
        return
    }
    curTxt := PriceAlerts.HasKey(sel) ? "   (current: " . PriceAlerts[sel] . " div)" : ""
    prompt := "Price-drop threshold (divine) for " . Chr(34) . sel . Chr(34) . curTxt . "`nLeave empty to clear."
    if InputBox, thr, %AppName%, %prompt%
    {
        if (ErrorLevel)
            return
        thr := Trim(thr)
        if (thr = "")
            PriceAlerts.Delete(sel)
        else
        {
            if !RegExMatch(thr, "i)^\d+(?:[.,]\d+)?$")
            {
                MsgBox, 48, %AppName%, Please enter a number.
                return
            }
            StringReplace, thr, thr, ",", ".", All
            PriceAlerts[sel] := thr + 0
        }
        SavePrices()
        SetStatus("Price threshold for " . sel . ": " . (PriceAlerts.HasKey(sel) ? PriceAlerts[sel] . " divine" : "cleared"))
    }
return

W_RefreshRules:
    global RXItems
    GuiControl, Watch:, W_Rules, |
    for i, r in RXItems
        GuiControl, Watch:, W_Rules, % (r.on ? "" : "(off) ") . r.name
    GuiControl, Watch:, W_RuleEnabled, 0
return

W_RulesPick:
    global RXItems
    GuiControlGet, sel, Watch:, W_Rules
    if (sel = "")
        return
    nm := RuleRaw(sel)
    for i, r in RXItems
        if (r.name = nm)
        {
            GuiControl, Watch:, W_RuleEnabled, % r.on
            return
        }
return

W_ToggleRule:
    global RXItems
    GuiControlGet, sel, Watch:, W_Rules
    if (sel = "")
        return
    nm := RuleRaw(sel)
    GuiControlGet, en, Watch:, W_RuleEnabled
    for i, r in RXItems
        if (r.name = nm)
        {
            r.on := (en ? 1 : 0)
            BuildWatchPattern()
            SaveWatchRegex()
            SetStatus("Rule """ . nm . """" . (en ? " enabled" : " disabled") . ".")
            break
        }
    Gosub, W_RefreshRules
return

W_AddRule:
    global RXItems
    GuiControlGet, raw, Watch:, W_RuleEdit
    raw := Trim(raw)
    if (raw = "")
    {
        SetStatus("Type a rule first. Example:  +2 minion amulet => \+2 to Minion")
        return
    }
    arrow := InStr(raw, "=>")
    if arrow
    {
        nm := Trim(SubStr(raw, 1, arrow - 1))
        pt := Trim(SubStr(raw, arrow + 2))
    }
    else
    {
        nm := raw
        pt := raw
    }
    if (nm = "")
        nm := pt
    if (pt = "" or !RXValid(pt))
    {
        SetStatus("Invalid rule/regex: " . pt)
        return
    }
    for i, r in RXItems
        if (r.name = nm and r.pat = pt)
        {
            SetStatus("Rule already exists: " . nm)
            return
        }
    RXItems.Push({name: nm, pat: pt, on: 1})
    BuildWatchPattern()
    SaveWatchRegex()
    GuiControl, Watch:, W_RuleEdit, 
    SetStatus("Rule added: " . nm)
    Gosub, W_RefreshRules
return

W_RemoveRule:
    global RXItems
    GuiControlGet, sel, Watch:, W_Rules
    if (sel = "")
        return
    nm := RuleRaw(sel)
    idx := 0
    for i, r in RXItems
        if (r.name = nm)
        {
            idx := i
            break
        }
    if (idx = 0)
        return
    RXItems.RemoveAt(idx)
    BuildWatchPattern()
    SaveWatchRegex()
    SetStatus("Rule removed: " . nm)
    Gosub, W_RefreshRules
return

W_ColorPreview:
    global Palette
    GuiControlGet, pn, Watch:, W_Color
    if (pn = "")
        return
    pcol := Palette[pn]
    GuiControl, Watch:+Background%pcol%, W_Swatch
return

W_BrowseSound:
    GuiControlGet, cur, Watch:, W_Sound
    FileSelectFile, picked, 3, %cur%, Choose a .wav file, Sound (*.wav)
    if (picked != "")
        GuiControl, Watch:, W_Sound, %picked%
return

W_Save:
    global Palette, ItemColor, ItemSound, TradeOnly
    GuiControlGet, pn,    Watch:, W_Color
    GuiControlGet, snd,   Watch:, W_Sound
    GuiControlGet, tOnly, Watch:, W_TradeOnly
    if (pn != "")
        ItemColor := Palette[pn]
    ItemSound := Trim(snd)
    TradeOnly := (tOnly ? 1 : 0)
    SaveTrade()
    SaveWatch()
    SaveWatchRegex()
    SetStatus("Trade watch saved.")
    Gui, Watch:Destroy
return

W_Close:
    Gui, Watch:Destroy
return


; ============================================================
;  STATS + CSV EXPORT
; ============================================================
BtnStats:
    ShowStats()
return

ShowStats()
{
    global AppName, Stats, MatchCount, ActiveProfile
    if (Stats.Count() = 0)
    {
        MsgBox, 64, %AppName%, No matches recorded yet.
        return
    }
    arr := []
    for w, c in Stats
        arr.Push({word: w, count: c})
    InsertionSortDesc(arr, "count")
    top := (arr.Length() > 0) ? (arr[1].word . "  (" . arr[1].count . ")") : "—"
    txt := "Dashboard`r`n"
        . "────────────────────`r`n"
        . "Total matches:   " . MatchCount . "`r`n"
        . "Words with hits: " . arr.Length() . "`r`n"
        . "Top word:        " . top . "`r`n"
        . "Active profile:  " . ActiveProfile . "`r`n`r`n"
    for i, o in arr
        txt .= o.count . "`t" . o.word . "`r`n"
    txt .= "`r`nExport the full message history from the ""Export CSV"" button."
    MsgBox, 64, %AppName% — Statistics, %txt%
}

InsertionSortDesc(arr, key)
{
    n := arr.Length()
    Loop, % n - 1
    {
        i := A_Index + 1
        cur := arr[i]
        j := i - 1
        while (j >= 1 and arr[j][key] < cur[key])
        {
            arr[j+1] := arr[j]
            j--
        }
        arr[j+1] := cur
    }
}

BtnPrices:
    ShowPrices()
return

ShowPrices()
{
    global AppName, PriceHist, PriceAlerts
    if (PriceHist.Count() = 0)
    {
        MsgBox, 64, %AppName% — Prices, "No prices recorded yet." . "`r`n" . "Prices are captured automatically from trade messages (e.g. ""50 div"", ""2 ex"")."
        return
    }
    txt := "Price history (most recent last)" . "`r`n"
        . "──────────────────────────────" . "`r`n"
    for key, s in PriceHist
    {
        parts := StrSplit(s, ";")
        nm := key
        thr := ""
        for name, amt in PriceAlerts
        {
            if (PriceKey(name) = key)
            {
                nm := name
                thr := "   [alert < " . amt . " div]"
                break
            }
        }
        txt .= "`r`n" . nm . thr . "`r`n"
        cnt := parts.Length()
        startIdx := (cnt > 6) ? (cnt - 5) : 1
        Loop, % cnt - startIdx + 1
        {
            idx := startIdx + A_Index - 1
            e := StrSplit(parts[idx], "_")
            txt .= "    " . e[1] . "    " . e[2] " " . e[3] . "`r`n"
        }
    }
    txt .= "`r`nSet a per-item drop threshold:  Trade watch → select an item → ""Price alert""."
    MsgBox, 64, %AppName% — Prices, %txt%
}

BtnExport:
    if (History.Length() = 0)
    {
        SetStatus("No history to export.")
        return
    }
    defName := A_ScriptDir . "\PoE2-Chat-Alert-" . A_Now . ".csv"
    FileSelectFile, out, S16, %defName%, Save matches as CSV, CSV (*.csv)
    if (out = "")
        return
    if !RegExMatch(out, "i)\.csv$")
        out .= ".csv"
    FileDelete, %out%
    FileAppend, % "Time,Channel,Player,Word,Message,Price`r`n", %out%
    for i, r in History
        FileAppend, % CsvField(r.time) . "," . CsvField(r.chan) . "," . CsvField(r.player) . "," . CsvField(r.word) . "," . CsvField(r.msg) . "," . CsvField(r.HasProp("price") ? r.price : "") . "`r`n", %out%
    cnt := History.Length()
    SetStatus("Exported " . cnt . " rows.")
    MsgBox, 64, %AppName%, Exported %cnt% rows to:`n%out%
return

CsvField(s)
{
    s := "" . s
    StringReplace, s, s, `", `"`", All
    return "`"" . s . "`""
}


; ============================================================
;  TRAY + WINDOW EVENTS
; ============================================================
BuildTray()
{
    global AppName
    Menu, Tray, Tip, %AppName%
    Menu, Tray, NoStandard
    Menu, Tray, Add, Show window, BtnShowWindow
    Menu, Tray, Add, Mute / Unmute (Ctrl+Alt+M), BtnMute
    Menu, Tray, Add, Start / Stop (Ctrl+Alt+S), BtnToggle
    Menu, Tray, Add, Trade watch (Ctrl+Alt+W), BtnWatch
    Menu, Tray, Add, Overlay panel (Ctrl+Alt+O), BtnOverlayToggle
    Menu, Tray, Add, Settings, BtnSettings
    Menu, Tray, Add, Statistics, BtnStats
    Menu, Tray, Add
    Menu, Tray, Add, Exit, BtnExit

    Menu, Ctx, Add, Copy full line,  CtxCopyLine
    Menu, Ctx, Add, Copy player name, CtxCopyName
    Menu, Ctx, Add, Whisper player,  CtxWhisper
    RefreshOverlayMenu()
}

BtnShowWindow:
    Gui, Main:Show
    WinActivate, %AppName%
return

MainGuiClose:
BtnExit:
    SaveSettings()
    SaveStats()
    SaveProfile(ActiveProfile)
    SaveTrade()
    SavePrices()
    SaveWatch()
    SaveWatchRegex()
    SaveHistory()
    if IsObject(hLog)
    {
        try hLog.Close()
    }
    ExitApp
return

OnScriptExit()
{
    global hLog
    SaveStats()
    if IsObject(hLog)
    {
        try hLog.Close()
    }
}