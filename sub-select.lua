local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local opt = require 'mp.options'

local o = {
    --selects subtitles synchronously during the preloaded hook, which has better
    --compatability with other scripts and options
    --this requires that the script predict what the default audio track will be,
    --so theoretically this can be wrong on some rare occasions
    --disabling this will switch the subtitle track after playback starts
    preload = true,

    --remove any potential prediction failures by forcibly selecting whichever
    --audio track was predicted
    select_audio = false,

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

local alang_priority = mp.get_property_native("alang", {})
msg.debug(utils.to_string(prefs))

--anticipates the default audio track
--returns a tuple of the audio language code, and the audio id
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

    if priority_track then return track_list[priority_track].lang, track_list[priority_track].id
    elseif default_track then return track_list[default_track].lang, track_list[default_track].id
    elseif first_track then return track_list[first_track].lang, track_list[first_track].id
    else return nil,nil end
end

local function is_valid_audio(alang, pref)
    if pref.alang == '*' then return true end

    if alang:find(pref.alang) then return true end
    return false
end

--checks if the given sub matches the given track preference
local function is_valid_sub(sub, pref)
    if sub.lang:find(pref.slang) then return false end

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
    if mp.get_property("options/sid", "auto") ~= "auto" then return end

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
                mp.set_property_number('file-local-options/sid', 0)
                return
            end

            --checks if any of the subtitle tracks match the preset for the current audio
            for i = 1, #subs do
                if is_valid_sub(subs[i], pref) then
                    mp.set_property('file-local-options/sid', subs[i].id)
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
            select_subtitles(track_list[i].lang)
            return
        end
    end
end

--select subtitles synchronously during the on_preloaded hook
local function preload()
    local opt = mp.get_property("options/aid", "auto")
    print(opt)
    if opt ~= "auto" then select_subtitles(opt) ; return end

    local track_list = mp.get_property_native("track-list", {})
    local alang, aid = find_default_audio(track_list)
    if not aid then return end

    if not alang then alang = "und" end
    msg.verbose("default "..alang)

    msg.verbose("setting audio track to " .. tostring(aid))
    if o.select_audio then mp.set_property('file-local-options/aid', aid) end
    select_subtitles(alang)
end

if o.preload then
    mp.add_hook('on_preloaded', 30, preload)
else
    mp.register_event("file-loaded", async_load)
end