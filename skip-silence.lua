-- ============================================================================
-- SKIP-SILENCE: Subtitle-Based Silence Skipper for MPV
-- ============================================================================
--
-- Based on: mpv-skipsilence by ferreum
-- Author: kuronekozero
-- 
-- DESCRIPTION:
-- This script automatically speeds up silent parts of videos by reading
-- subtitle timing information. When no dialogue is present, the video plays
-- at increased speed, then returns to normal speed when subtitles appear.
--
-- I've decided to create it because I considered audio detection Silence
-- skippnig not accurate enough.
--
-- Originally developed for Memento Player but should work with regular MPV.
--
-- KNOWN LIMITATIONS:
-- - Cannot read subtitle files with non-ASCII characters in the path/filename
--   (e.g., Japanese, Chinese, Cyrillic characters). This is a limitation of
--   the file reading method used. The script will fail to load subtitles if
--   the path contains special characters.
-- - Only works with external subtitle files (.srt and .ass formats)
-- - Requires subtitles to be loaded before activation
--
-- Feel free to contribute fixes or improvements!
--
-- KEYBINDINGS:
-- F2 - Toggle silence skipping on/off
-- F5 - Reload subtitle file (useful if you switch subtitle tracks)
--
-- ============================================================================

-- ============================================================================
-- CONFIGURATION OPTIONS
-- ============================================================================
-- Customize these settings to control how the script behaves.
-- All time values are in seconds unless otherwise noted.
-- ============================================================================

local opts = {
    -- enabled: Whether the script starts enabled automatically when MPV opens
    -- Set to 'true' to auto-enable, 'false' to manually enable with F2
    -- Default: false (you need to press F2 to activate)
    enabled = false,

    -- silence_speed: Speed multiplier during silent parts (no subtitles)
    -- For example: 6 means silent parts play 6x faster than normal
    -- Range: 1.0 (no change) to 100 (never tried using it, probably will break everything...)
    -- Recommended: 3-8 for comfortable skipping
    -- Default: 6
    silence_speed = 6,

    -- speed_max: Maximum absolute playback speed allowed
    -- This caps the speed even if silence_speed × current speed exceeds it
    -- For example: If you're already playing at 2x speed and silence_speed is 6,
    -- the result would be 12x, but speed_max will limit it to this value
    -- Default: 6
    speed_max = 6,

    -- min_silence_duration: Minimum gap between subtitles to trigger speed-up
    -- Gaps shorter than this will play at normal speed (avoids jarring speed changes)
    -- Measured in seconds
    -- Recommended: 1.5-3.0 seconds
    -- Default: 2
    min_silence_duration = 2,

    -- margin_before: Time buffer before subtitle appears
    -- The script will slow down to normal speed this many seconds BEFORE
    -- a subtitle appears, giving you time to prepare for dialogue
    -- Measured in seconds
    -- Recommended: 0.3-0.8 seconds
    -- Default: 0.5
    margin_before = 0.5,

    -- margin_after: Time buffer after subtitle disappears
    -- The script waits this many seconds AFTER a subtitle ends before
    -- speeding up again (currently not actively used in logic)
    -- Measured in seconds
    -- Default: 0.5
    margin_after = 0.5,

    -- check_interval: How often the script checks playback position
    -- Lower values = more responsive but slightly higher CPU usage
    -- Higher values = less CPU usage but may miss subtitle timing slightly
    -- Measured in seconds
    -- Recommended: 0.05-0.2 seconds
    -- Default: 0.1
    check_interval = 0.1,

    -- infostyle: On-screen display style when speed changes
    -- Options:
    --   "compact" - Shows brief messages ("⏩ Skipping" / "▶ Normal")
    --   "off" - No on-screen messages
    -- Default: "compact"
    infostyle = "compact",

    -- debug: Enable debug logging to console
    -- Set to 'true' to see detailed information in MPV console (useful for troubleshooting)
    -- Default: false
    debug = false
}

-- ============================================================================
-- SCRIPT INTERNALS (No need to modify below this line)
-- ============================================================================

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

-- Internal state tracking
local state = {
    active = false,          -- Whether silence skipping is currently enabled
    silent = false,          -- Whether we're currently in a silent section
    base_speed = 1,          -- User's normal playback speed (to restore after skipping)
    saved = 0,               -- Reserved for future time-saved tracking
    silence_start = nil,     -- When current silence section started
    subs = {},               -- Array of subtitle timing segments {s=start, e=end}
    loaded = false,          -- Whether subtitle file was successfully loaded
    path = nil               -- Path to currently loaded subtitle file
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Format seconds into human-readable time (H:MM:SS or M:SS)
local function format_time(s)
    if not s or s < 0 then return "0:00" end
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local secs = math.floor(s % 60)
    if h > 0 then 
        return string.format("%d:%02d:%02d", h, m, secs)
    else 
        return string.format("%d:%02d", m, secs)
    end
end

-- Universal file reader compatible with older MPV versions
-- Tries multiple methods to read file content
local function read_content_universal(path)
    if not path then return nil end
    
    -- Method 1: Try utils.read_file if available (newer MPV versions)
    if utils.read_file then
        local success, content = pcall(utils.read_file, path)
        if success and content then return content end
    end

    -- Method 2: Standard Lua io.open (fallback for older versions)
    -- NOTE: This works fine for ASCII paths but struggles with non-ASCII
    -- characters (Japanese, Chinese, etc.) on some systems, especially Windows
    local f = io.open(path, "r")
    if not f then
        msg.warn("Failed to open file: " .. path)
        return nil 
    end
    local content = f:read("*all")
    f:close()
    return content
end

-- Clean up file paths from MPV (removes file:// prefix and URL encoding)
local function clean_path(path)
    if not path then return nil end
    
    -- Remove file:// protocol prefix
    if path:match("^file://") then
        path = path:gsub("^file:///?", "")
        -- Fix Windows paths that start with /C: -> C:
        if path:match("^/[A-Za-z]:") then 
            path = path:sub(2) 
        end
    end
    
    -- Decode URL-encoded characters (e.g., %20 -> space)
    path = path:gsub("%%(%x%x)", function(h) 
        return string.char(tonumber(h, 16)) 
    end)
    
    return path
end

-- ============================================================================
-- SUBTITLE PARSING FUNCTIONS
-- ============================================================================

-- Parse SRT timestamp format (00:00:00,000)
local function parse_time_srt(t)
    local h, m, s, ms = t:match("(%d+):(%d+):(%d+)[,.](%d+)")
    if not h then return nil end
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) / 1000
end

-- Parse ASS/SSA timestamp format (0:00:00.00)
local function parse_time_ass(t)
    local h, m, s = t:match("(%d+):(%d+):([%d.]+)")
    if not h then return nil end
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
end

-- Load and parse subtitle file
local function load_subs()
    state.loaded = false
    state.subs = {}
    
    -- Try to get subtitle file path from MPV
    local path = mp.get_property("current-tracks/sub/external-filename")
    if not path or path == "" then 
        path = mp.get_property("sub-file") 
    end
    
    -- Check if external subtitle file exists
    if not path or path == "" then
        msg.warn("No external subtitle file detected")
        mp.osd_message("Skip-Silence: No external subs found")
        return false
    end

    state.path = path
    local clean = clean_path(path)
    
    msg.info("Reading subtitle file: " .. clean)
    local content = read_content_universal(clean)
    
    if not content then
        msg.error("Could not read subtitle file - check path for special characters")
        mp.osd_message("Skip-Silence: Error reading subtitle file")
        return false
    end

    local segments = {}
    local count = 0
    
    -- Detect subtitle format and parse accordingly
    if clean:lower():match("%.srt$") then
        -- SRT format parser
        for line in content:gmatch("[^\r\n]+") do
            local s, e = line:match("([%d:,]+)%s*%-%->%s*([%d:,]+)")
            if s and e then
                local t1, t2 = parse_time_srt(s), parse_time_srt(e)
                if t1 and t2 then 
                    table.insert(segments, {s = t1, e = t2}) 
                    count = count + 1
                end
            end
        end
        
    elseif clean:lower():match("%.ass$") then
        -- ASS/SSA format parser
        local in_events = false
        for line in content:gmatch("[^\r\n]+") do
            if line:match("^%[Events%]") then 
                in_events = true
            elseif in_events and line:match("^Dialogue:") then
                local s, e = line:match("Dialogue:[^,]*,([^,]+),([^,]+),")
                if s and e then
                    local t1, t2 = parse_time_ass(s), parse_time_ass(e)
                    if t1 and t2 then 
                        table.insert(segments, {s = t1, e = t2}) 
                        count = count + 1
                    end
                end
            end
        end
    else
        msg.warn("Unsupported subtitle format (only .srt and .ass supported)")
        mp.osd_message("Skip-Silence: Unsupported subtitle format")
        return false
    end

    -- Validate that we found subtitle timings
    if count > 0 then
        -- Sort segments by start time for efficient searching
        table.sort(segments, function(a, b) return a.s < b.s end)
        state.subs = segments
        state.loaded = true
        msg.info("Successfully loaded " .. count .. " subtitle segments")
        mp.osd_message("Skip-Silence: Loaded " .. count .. " segments")
        return true
    else
        msg.warn("Subtitle file parsed but no timing data found")
        mp.osd_message("Skip-Silence: No subtitle timings found")
        return false
    end
end

-- ============================================================================
-- MAIN LOGIC
-- ============================================================================

-- Check current playback position and adjust speed accordingly
local function check()
    if not state.active or not state.loaded then return end
    
    -- Get current playback position
    local pos = mp.get_property_number("playback-time")
    if not pos then return end
    
    -- Account for subtitle delay offset
    local delay = mp.get_property_number("sub-delay") or 0
    pos = pos + delay
    
    -- Find next subtitle segment from current position
    local next_sub = nil
    for _, seg in ipairs(state.subs) do
        if seg.e >= pos then
            next_sub = seg
            break
        end
    end

    local should_speed = false
    
    -- Determine if we should be in speed-up mode
    if not next_sub then
        -- No more subtitles ahead - speed up
        should_speed = true
    elseif pos >= next_sub.s and pos <= next_sub.e then
        -- Currently inside a subtitle - play normal speed
        should_speed = false
    else
        -- Check gap until next subtitle
        local gap = next_sub.s - pos
        if gap > (opts.margin_before + opts.min_silence_duration) then
            -- Gap is large enough to warrant speed-up
            should_speed = true
        end
    end

    -- Apply speed changes when state transitions
    if should_speed and not state.silent then
        -- Entering silence - speed up
        state.base_speed = mp.get_property_number("speed") or 1
        local target = math.min(state.base_speed * opts.silence_speed, opts.speed_max)
        mp.set_property("speed", target)
        state.silent = true
        state.silence_start = mp.get_time()
        
        if opts.infostyle ~= "off" then 
            mp.osd_message("⏩ Skipping silence") 
        end
        
    elseif not should_speed and state.silent then
        -- Exiting silence - return to normal speed
        mp.set_property("speed", state.base_speed)
        state.silent = false
        
        if opts.infostyle ~= "off" then 
            mp.osd_message("▶ Normal speed") 
        end
    end
end

-- Toggle silence skipping on/off
local function toggle()
    if state.active then
        -- Disable silence skipping
        state.active = false
        mp.set_property("speed", state.base_speed)
        state.silent = false
        mp.osd_message("Skip-Silence: OFF")
        msg.info("Silence skipping disabled")
    else
        -- Enable silence skipping
        if load_subs() then
            state.active = true
            state.base_speed = mp.get_property_number("speed") or 1
            mp.osd_message("Skip-Silence: ON")
            msg.info("Silence skipping enabled")
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Start periodic check timer
local timer = mp.add_periodic_timer(opts.check_interval, check)

-- Register keybindings
mp.add_key_binding("F2", "toggle-silence-skip", toggle)
mp.add_key_binding("F5", "reload-subtitles", function() 
    if load_subs() then
        mp.osd_message("Skip-Silence: Subtitles reloaded")
    end
end)

msg.info("Skip-Silence script loaded successfully")