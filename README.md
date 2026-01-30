# Better version of this script
After searching for a while I've discovered the following [script](https://github.com/Ajatt-Tools/sub-transition). It works just like mine but it is much better, doesn't have this bug related to ASCII characters and it also can skip sounds by analyzing brackets. I recommend you using this script first instead of mine.
Also, set "reset_before" variable in this script to 2 seconds time. Otherwise this script will also speed up small parts of the speech, don't know why it works that way, i personally use following settings:
```
local config = {
    start_enabled = true, -- enable transitions when mpv starts without having to enable them in the menu
    notifications = false, -- enable notifications when speed changes
    pause_on_start = false, -- pause when a subtitle starts
    pause_before_end = false, -- pause before a subtitle ends
    hide_subs_when_playing = false, -- hide subtitles when playback is active
    start_delay = 0.5, -- if the next subtitle appears after this threshold then speedup
    reset_before = 2, --seconds to stop short of the next subtitle
    min_duration = 2.5, -- minimum duration of a skip
    normal_speed = 1, -- reset back to this speed
    inter_speed = 5, -- the value that "speed" is set to during speedup
    menu_font_size = 24, -- font size
    skip_non_dialogue = true, -- skip lines that are enclosed in parentheses
    skip_immediately = false, -- skip non-dialogue lines without transitioning
}
```

If it doesn't work to you for some reason you can try using my version.

# Skip-Silence

**Automatically skip silent parts in videos using subtitle timing data**

This MPV script speeds up playback during silent sections of videos by analyzing subtitle timing information. When dialogue appears, playback returns to normal speed automatically.

## Why I've created it?

The original [mpv-skipsilence](https://github.com/ferreum/mpv-skipsilence) by ferreum uses audio detection to identify silent parts, which works well for many use cases. However, I needed **maximum accuracy** for my workflow - specifically for watching and mining Japanese content in [Memento Player](https://github.com/ripose-jp/Memento) (the most convenient solution for studying Japanese with Anki integration).

Audio-based detection wasn't precise enough for my goals, so I created this subtitle-based version that analyzes subtitle files directly for **perfectly accurate** timing synchronization with dialogue.

**Key advantage**: The script automatically adapts to subtitle timing adjustments made within the player, so if you shift subtitle timing to fix sync issues, the silence detection updates accordingly.

---

## Features

- **Speed Control**: Automatically speeds up video during gaps between subtitles
- **Subtitle-Based Detection**: Uses subtitle timing for precise, accurate silence detection
- **Dynamic Timing Adaptation**: Automatically adjusts to subtitle timing changes made in the player
- **Customizable Settings**: Fine-tune skip speed, margins, and minimum silence duration inside of the skip-silence.lua file
- **Format Support**: Works with SRT and ASS subtitle formats
- **Non-Intrusive**: Preserves your preferred playback speed settings

---

## Requirements

- **MPV Player** (or Memento Player - MPV-based)
- **External subtitle files** (.srt or .ass format)
- Subtitle file must be loaded in the player (just drag and drop it)

---

## Installation

### For Memento Player

1. Navigate to your Memento configuration folder
2. Create a folder named `scripts` (if it doesn't already exist)
3. Copy `skip-silence.lua` into the `scripts` folder
4. Restart Memento Player

**Example path structure:**
```
[Memento Config Folder]/
└── scripts/
    └── skip-silence.lua
```

### For MPV Player

1. Locate your MPV configuration directory:
   - **Windows**: `C:\Users\[YourUsername]\AppData\Roaming\mpv\scripts\`
   - **Linux**: `~/.config/mpv/scripts/`
   - **macOS**: `~/.config/mpv/scripts/`

2. If the `scripts` folder doesn't exist, create it

3. Copy `skip-silence.lua` into the `scripts` folder

4. Restart MPV

**Note**: You can also place the script in a `scripts` subfolder next to your `mpv.conf` file.

---

## Usage

### Keybindings

| Key | Action |
|-----|--------|
| **F2** | Toggle silence skipping ON/OFF |
| **F5** | Reload subtitle file |

### Quick Start

1. Open a video with external subtitles loaded
2. Press **F2** to activate silence skipping
3. The script will automatically speed up during silent parts
4. Press **F2** again to disable

---

## Configuration

Open `skip-silence.lua` in a text editor to customize settings. All options are documented in the **CONFIGURATION OPTIONS** section at the top of the file.

---

## Known Limitations

### Non-ASCII Character Issue

**The script cannot read subtitle files with non-ASCII characters in the file path or filename.**

This includes:
- Japanese characters 
- Chinese characters 
- Cyrillic characters 
- Other special Unicode characters

**Workaround**: Rename subtitle files and parent folders to use only ASCII characters (A-Z, 0-9, basic punctuation). 
So far, I couldn't find any working solution to it. If you know how to fix it please tell me.

### Other Limitations

- Only works with **external** subtitle files (not embedded/internal subs)
- Supports **SRT** and **ASS** formats only
- Requires subtitles to be loaded before activation

**Contributions welcome!** If you know how to fix the non-ASCII path issue, please submit a pull request.

---

## Troubleshooting

### Script doesn't activate
- Ensure you have **external** subtitles loaded (not embedded)
- Check that the subtitle file path contains only ASCII characters
- Verify the subtitle format is .srt or .ass

### Speed doesn't change
- Check your subtitle file has proper timing data
- Try pressing **F5** to reload subtitles
- Verify `min_silence_duration` isn't set too high

### Can't find scripts folder
- Create the `scripts` folder manually in your MPV config directory
- See installation instructions above for exact paths

---

## License

This project inherits the license from the original mpv-skipsilence project.

---

## Contributing

Contributions, bug reports, and feature requests are welcome!

**Priority improvements:**
- Fix non-ASCII file path reading
- Add option to skip silence completely
- Add option to skip sounds 

---
