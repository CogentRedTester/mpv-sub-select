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

local latest_prediction = nil
local alang_priority = mp.get_property_native("alang", {})

--anticipates the default audio track
--returns the node for the predicted track
--this whole function can be skipped if the user decides to load the subtitles asynchronously instead
local function find_default_audio(track_list)
    local highest_priority = math.huge
    local default_track = nil
    local priority_track = nil
    local first_track = nil

    --loop through the track list for any audio tracks
    for i = 1, #track_list do
        if track_list[i].type == "audio" then
            if first_track == nil then first_track = i end
            if track_list[i].default and default_track == nil then default_track = i end

            --loop through the alang list to check if it has a preference
            for j = 1, #alang_priority do
                if track_list[i].lang == alang_priority[j] then
                    if (j < highest_priority) then
                        highest_priority = j
                        priority_track = i
                    end
                    break
                end
            end
        end
    end

    --preferred langauges have priority, then the default track, then the first
    --this will be wrong if the there are multiple tracks of the same highest priority language,
    --and the default is not the first of these tracks.
    --The forced flag is also not represented here
    if priority_track then latest_prediction = track_list[priority_track]
    elseif default_track then latest_prediction = track_list[default_track]
    elseif first_track then latest_prediction = track_list[first_track]
    else latest_prediction = nil end

    return latest_prediction
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

    if alang:find(pref.alang) then return true end
    return false
end

--checks if the given sub matches the given track preference
local function is_valid_sub(sub, pref)
    if not sub.lang:find(pref.slang) then return false end
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
local function select_subtitles(audio)
    local alang = audio.lang
    if not alang then alang = "und" end
    local subs = {}
    local track_list = mp.get_property_native("track-list", {})

    --creating a table of just the subtitles
    for i = 1, #track_list do
        if track_list[i].type == "sub" then
            table.insert(subs, track_list[i])
        end
    end

    --searching the selection presets for one that applies to this track
    for _,pref in ipairs(prefs) do
        if is_valid_audio(alang, pref) then
            --special handling when we want to disable subtitles
            if pref.slang == "no" then
                set_track("sid", "no")
                return
            end

            --checks if any of the subtitle tracks match the preset for the current audio
            for i = 1, #subs do
                if not subs[i].lang then subs[i].lang = "und" end
                if is_valid_sub(subs[i], pref) then
                    set_track("sid", subs[i].id)
                    return
                end
            end
        end
    end
end

--select subtitles asynchronously after playback start
local function async_load()
    local track_list = mp.get_property_native("track-list", {})
    for i = 1, #track_list do
        if track_list[i].selected and track_list[i].type == "audio" then
            select_subtitles(track_list[i])
            return
        end
    end
end

--select subtitles synchronously during the on_preloaded hook
local function preload()
    local track_list = mp.get_property_native("track-list", {})
    local opt = mp.get_property_number("options/aid", -1)

    if opt ~= -1 then
        for i = 1, #track_list do
            if track_list[i].type == "audio" and track_list[i].id == opt then
                select_subtitles(track_list[i])
                return
            end
        end
        return
    end

    local audio = find_default_audio(track_list)
    if not audio then return end

    msg.verbose("predicted audio track is "..audio.id)

    if o.force_prediction then set_track("aid", audio.id) end
    select_subtitles(audio)
end

--events for file loading
if o.preload then
    mp.add_hook('on_preloaded', 30, function()
        if mp.get_property("options/sid", "auto") == "auto" then preload() end
    end)

    --double check if the predicted subtitle was correct
    if o.detect_incorrect_predictions and not o.force_prediction then
        mp.register_event("file-loaded", function()
            if latest_prediction.id ~= mp.get_property_number("aid", 0) then
                async_load()
            end
        end)
    end
else
    mp.register_event("file-loaded", function()
        if mp.get_property("options/sid", "auto") == "auto" then async_load() end
    end)
end

--force subtitle selection during playback
mp.register_script_message("select-subtitles", async_load)
