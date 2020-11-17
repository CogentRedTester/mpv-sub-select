--[[
    mpv-sub-select

    This script allows you to configure advanced subtitle track selection based on
    the current audio track and the names and language of the subtitle tracks.

    https://github.com/CogentRedTester/mpv-sub-select
]]--

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local opt = require 'mp.options'

local o = {
    --selects subtitles synchronously during the preloaded hook, which has better
    --compatability with other scripts and options
    --this requires that the script predict what the default audio track will be,
    --so this can be wrong on some rare occasions
    --disabling this will switch the subtitle track after playback starts
    preload = true,

    --remove any potential prediction failures by forcibly selecting whichever
    --audio track was predicted
    force_prediction = false,

    --detect when a prediction is wrong and re-check the subtitles
    --this is automatically disabled if `force_prediction` is enabled
    detect_incorrect_predictions = true,

    --observe audio switches and reselect the subtitles when alang changes
    observe_audio_switches = false,

    --the folder that contains the 'sub-select.json' file
    config = "~~/script-opts"
}

opt.read_options(o, "sub_select")

local file = assert(io.open(mp.command_native({"expand-path", o.config}) .. "/sub-select.json"))
local json = file:read("*all")
file:close()
local prefs = utils.parse_json(json)

if prefs == nil then
    error("Invalid JSON format in sub-select.json.")
end

local latest_audio = {}
local alang_priority = mp.get_property_native("alang", {})
local audio_tracks = {}
local sub_tracks = {}

--anticipates the default audio track
--returns the node for the predicted track
--this whole function can be skipped if the user decides to load the subtitles asynchronously instead,
--or if `--aid` is not set to `auto`
local function find_default_audio()
    local highest_priority = {}
    local priority_str = ""
    local num_prefs = #alang_priority
    local num_tracks = #audio_tracks

    --loop through the track list for any audio tracks
    for i = 1, #audio_tracks do
        local track = audio_tracks[i]

        --loop through the alang list to check if it has a preference
        local pref = 0
        for j = 1, #alang_priority do
            if track.lang == alang_priority[j] then

                --a lower number j has higher priority, so flip the numbers around so the lowest j has highest preference
                pref = num_prefs - j
                break
            end
        end

        --format the important preferences so that we can easily use a lexicographical comparison to find the default
        local formatted_str = string.format("%s-%04d-%s-%d", tostring(track.forced), pref, tostring(track.default), num_tracks - track.id)
        msg.trace("formatted track info: " .. formatted_str)

        if formatted_str > priority_str then
            priority_str = formatted_str
            highest_priority = track
        end
    end

    return highest_priority
end

--sets the subtitle track to the given sid
--this is a function to prepare for some upcoming functionality, but I've forgotten what that is
local function set_track(type, id)
    msg.verbose("setting "..type.." to " .. id)
    if mp.get_property_number(type) == id then return end
    mp.set_property('file-local-options/'..type, id)
end

--checks if the given audio matches the given track preference
local function is_valid_audio(alang, pref)
    if pref.alang == '*' then return true end
    if alang == nil then return (pref.alang == "no") end

    if alang:find(pref.alang) then return true end
    return false
end

--checks if the given sub matches the given track preference
local function is_valid_sub(sub, pref)
    if pref.slang == "default" then
        if not sub.default then return false end
    elseif pref.slang == "forced" then
        if not sub.forced then return false end
    elseif not sub.lang:find(pref.slang) then
        return false end

    local title = sub.title

    --whitelist/blacklist handling
    if pref.whitelist then
        if not title then return false end
        title = title:lower()
        local found = false

        for _,word in ipairs(pref.whitelist) do
            if title:find(word) then found = true end
        end

        if not found then return false end
    end

    if pref.blacklist then
        if not title then return true end
        title = title:lower()

        for _,word in ipairs(pref.blacklist) do
            if title:find(word) then return false end
        end
    end

    return true
end

--scans the track list and selects subtitle tracks which match the track preferences
local function select_subtitles(alang)
    --searching the selection presets for one that applies to this track
    for _,pref in ipairs(prefs) do
        msg.trace("testing pref: " .. utils.to_string(pref))
        if is_valid_audio(alang, pref) then
            --special handling when we want to disable subtitles
            if pref.slang == "no" then
                set_track("sid", "no")
                return
            end

            --checks if any of the subtitle tracks match the preset for the current audio
            for i = 1, #sub_tracks do
                if not sub_tracks[i].lang then sub_tracks[i].lang = "und" end
                if is_valid_sub(sub_tracks[i], pref) then
                    set_track("sid", sub_tracks[i].id)
                    return
                end
            end
        end
    end
end

--extract the language code from an audio track node and pass it to select_subtitles
local function process_audio(audio)
    latest_audio = audio
    local alang = audio.lang
    if not next(audio) then alang = nil
    elseif not alang then alang = "und" end
    select_subtitles(alang)
end

--returns the audio node for the currently playing audio track
local function find_current_audio()
    local aid = mp.get_property_number("aid", 0)
    return audio_tracks[aid] or {}
end

--select subtitles asynchronously after playback start
local function async_load()
    process_audio( find_current_audio() )
end

--select subtitles synchronously during the on_preloaded hook
local function preload()
    local opt = mp.get_property("options/aid", "auto")

    if opt == "no" then
        process_audio( {} )
        return
    elseif opt ~= "auto" then
        process_audio( audio_tracks[tonumber(opt)] )
        return
    end

    local audio = find_default_audio()
    msg.verbose("predicted audio track is "..tostring(audio.id))

    if next(audio) then
        if o.force_prediction then set_track("aid", audio.id) end
    end
    process_audio(audio)
end

local track_auto_selection = true
mp.observe_property("track-auto-selection", "bool", function(_,b) track_auto_selection = b end)

local function continue_script()
    if not track_auto_selection then return false end
    if #sub_tracks < 1 then return false end
    return true
end

--reselect the subtitles if the audio is different from what was last used
local function reselect_subtitles()
    if not continue_script() then return end
    local aid = mp.get_property_number("aid", 0)
    if latest_audio.id ~= aid then
        local audio = audio_tracks[aid] or {}
        if audio.lang ~= latest_audio.lang then
            msg.info("detected audio change - reselecting subtitles")
            process_audio(audio)
        end
    end
end

--setups the audio and subtitle track lists to use for the rest of the script
local function read_track_list()
    local track_list = mp.get_property_native("track-list", {})
    audio_tracks = {}
    sub_tracks = {}
    for _,track in ipairs(track_list) do
        if track.type == "audio" then
            table.insert(audio_tracks, track)
        elseif track.type == "sub" then
            table.insert(sub_tracks, track)
        end
    end
end

--setup the audio and subtitle track lists when a new file is loaded
mp.add_hook('on_preloaded', 25, read_track_list)

--events for file loading
if o.preload then
    mp.add_hook('on_preloaded', 30, function()
        if not continue_script() then return end
        if mp.get_property("options/sid", "auto") == "auto" then preload()
        elseif o.observe_audio_switches then latest_audio = find_default_audio() end
    end)

    --double check if the predicted subtitle was correct
    if o.detect_incorrect_predictions and not o.force_prediction and not o.observe_audio_switches then
        mp.register_event("file-loaded", reselect_subtitles)
    end
else
    mp.register_event("file-loaded", function()
        if not continue_script() then return end
        if mp.get_property("options/sid", "auto") == "auto" then async_load()
        elseif o.observe_audio_switches then latest_audio = find_current_audio() end
    end)
end

--reselect subs when changing audio tracks
if o.observe_audio_switches then
    mp.observe_property("aid", "string", function(_,aid)
        if aid ~= "auto" then reselect_subtitles() end
    end)
end

--force subtitle selection during playback
mp.register_script_message("select-subtitles", function()
    read_track_list()
    async_load()
end)
