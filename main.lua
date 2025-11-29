local mp = require 'mp'
local utils = require 'mp.utils'
local options = require 'mp.options'

local script_path = mp.command_native({ "expand-path", "~~/scripts/shazam" })
local script_opts = {
    python_path = "",
}
options.read_options(script_opts, "shazam")

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function get_python_path()
    if script_opts.python_path ~= "" then
        return script_opts.python_path
    end

    -- Try to find venv in the script directory
    local venv_python_win = utils.join_path(script_path, ".venv/Scripts/python.exe")
    local venv_python_unix = utils.join_path(script_path, ".venv/bin/python")

    if file_exists(venv_python_win) then
        return venv_python_win
    elseif file_exists(venv_python_unix) then
        return venv_python_unix
    end
    
    -- Fallback to system python
    return "python"
end

local python = get_python_path()
local recognizer = utils.join_path(script_path, "recognizer.py")
local temp_audio = utils.join_path(os.getenv("TMP") or os.getenv("TEMP") or "/tmp", "mpv_shazam_sample.wav")

local capture_length = 3
local continuous_recognition = false
local error_count = 0
local last_metadata = nil
local last_osd_message = nil
local max_errors = 3
local og_geometry
local og_snapwindow
local osd_overlay = mp.create_osd_overlay("ass-events")
local osd_timeout = 3
local osd_timer = nil
local recognition_timer = nil
local recognizing = false
local size = 540
local stop_recognition = false
local video = true
local video_window_visible = false

local function is_video_window_visible()
    if mp.get_property("term-size") == nil then
        video_window_visible = true
    end
end

local function update_osd(text, timeout)
    if last_osd_message ~= text then
        last_osd_message = text
    else
        return
    end

    osd_overlay.data = string.format("{\\bord1.5}{\\shad.15}{\\be1}{\\fncambria}{\\an3}%s", text)
    osd_overlay:update()

    if osd_timer then
        osd_timer:kill()
        osd_timer = nil
    end

    if timeout ~= false then
        osd_timer = mp.add_timeout(timeout or osd_timeout, function()
            osd_overlay:remove()
        end)
    end
end

local function handle_recognition_result(success, result)
    recognizing = false

    if stop_recognition then
        stop_recognition = false
        return
    end

    if not success or result.status ~= 0 then
        mp.msg.error("Python script failed or crashed")
        error_count = error_count + 1
    else
        local json = utils.parse_json(result.stdout)
        if not json or json.error then
            if json and json.error then
                mp.msg.warn("Shazam error: " .. json.error)
            end
            error_count = error_count + 1
        else
            error_count = 0

            local new_metadata = {
                title = json.title,
                artist = json.artist,
                album = json.album,
                year = json.year,
                genre = json.genre,
                label = json.label,
                cover = json.cover,
                link = json.link
            }

            if utils.to_string(last_metadata) ~= utils.to_string(new_metadata) then
                last_metadata = new_metadata
            else
                return
            end

            if stop_recognition then
                stop_recognition = false
                return
            end

            mp.set_property("file-local-options/force-media-title",
                string.format("%s - %s", new_metadata.artist, new_metadata.title))

            if video_window_visible then
                local osd_message = string.format(
                    "{\\b1}\"%s\"\\N\\N%s{\\b0}\\N\\N%s (%s)\\N\\N%s\\N\\N%s",
                    new_metadata.title, new_metadata.artist, new_metadata.album, new_metadata.year,
                    new_metadata.genre, new_metadata.label
                )
                if continuous_recognition then
                    update_osd(osd_message, false)
                else
                    update_osd(osd_message)
                end
                if not video then
                    mp.command("video-remove")
                    local cover_url = new_metadata.cover
                    if cover_url ~= "No Cover" then
                        cover_url = cover_url:gsub("(%d+)x%1cc%.jpg$", string.format("%dx%dcc.jpg", size, size))
                        mp.commandv("video-add", cover_url, "cached", new_metadata.title, "en", "yes")
                    end
                end
            else
                local osd_message = string.format(
                    "\n\"%s\"\n\n%s\n\n%s (%s)\n\n%s\n\n%s\n\n%s\n",
                    new_metadata.title, new_metadata.artist, new_metadata.album, new_metadata.year,
                    new_metadata.genre, new_metadata.label, new_metadata.link or ""
                )
                mp.osd_message(osd_message, 999)
            end
            return
        end
    end

    if error_count >= max_errors then
        last_metadata = nil
        mp.set_property("file-local-options/force-media-title", "")
        if video_window_visible then
            if continuous_recognition then
                update_osd("Shazam: Song Recognition Failed", false)
            else
                update_osd("Shazam: Song Recognition Failed")
            end
            if not video then
                mp.command("video-remove")
            end
        else
            mp.osd_message("\nShazam: Song Recognition Failed\n", 999)
        end
    end
end

local function handle_ffmpeg_result(success, result)
    if stop_recognition then
        recognizing = false
        stop_recognition = false
        return
    end

    if not success or result.status ~= 0 then
        mp.msg.error("FFmpeg failed to capture audio")
        recognizing = false
        return
    end

    if not continuous_recognition then
        if video_window_visible then
            update_osd("Shazam: Identifying...", false)
        else
            mp.osd_message("\nShazam: Identifying...\n", 999)
        end
    end

    mp.command_native_async({
        name = "subprocess",
        args = { python, recognizer, temp_audio },
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false
    }, handle_recognition_result)
end

local function recognize_song()
    if recognizing then return end
    recognizing = true

    if stop_recognition then
        stop_recognition = false
        recognizing = false
        return
    end

    if mp.get_property("aid") == "no" then
        mp.set_property("file-local-options/force-media-title", "")
        if video_window_visible then
            update_osd("No Audio Track")
        else
            mp.osd_message("\nNo Audio Track\n", 3)
        end
        recognizing = false
        return
    end

    if not continuous_recognition then
        if video_window_visible then
            if mp.get_property("vid") == "no" then
                video = false
            end
            update_osd("Shazam: Listening...", false)
        else
            mp.osd_message("\nShazam: Listening...\n", 999)
        end
    end

    mp.command_native_async({
        name = "subprocess",
        args = { "ffmpeg", "-y", "-i", mp.get_property("path"), "-t", tostring(capture_length), temp_audio },
        playback_only = false
    }, handle_ffmpeg_result)
end

local function start_continuous_recognition()
    recognition_timer = mp.add_periodic_timer(1, recognize_song)
end

local function toggle_continuous_recognition()
    continuous_recognition = not continuous_recognition
    if continuous_recognition then
        if video_window_visible then
            if mp.get_property("vid") == "no" then
                video = false
                og_geometry = mp.get_property("geometry")
                mp.set_property("geometry", string.format("%dx%d-50%%-50%%", size, size))
                og_snapwindow = mp.get_property("snap-window")
                mp.set_property("snap-window", "yes")
            end
            update_osd("Shazam: Continuous Recognition Started", false)
        else
            mp.osd_message("\nShazam: Continuous Recognition Started\n", 999)
        end
        start_continuous_recognition()
    else
        if recognition_timer then
            recognition_timer:kill()
            recognition_timer = nil
        end
        stop_recognition = true

        last_metadata = nil
        error_count = 0
        mp.set_property("file-local-options/force-media-title", "")
        if video_window_visible then
            update_osd("Shazam: Continuous Recognition Stopped", 3)
            if not video then
                mp.command("video-remove")
                mp.set_property("geometry", og_geometry)
                mp.set_property("geometry", "50%:50%")
                mp.set_property("snap-window", og_snapwindow)
            end
        else
            mp.osd_message("\nShazam: Continuous Recognition Stopped\n", 3)
        end
    end
end

local function on_file_change()
    if not recognizing and not continuous_recognition then return end

    stop_recognition = true
    last_metadata = nil
    error_count = 0
    mp.set_property("file-local-options/force-media-title", "")

    if video_window_visible then
        update_osd("Shazam: File Change Detected, Restarting Recognition", false)
        if not video then
            mp.command("video-remove")
        end
    else
        mp.osd_message("\nShazam: File Change Detected, Restarting Recognition\n", 999)
    end

    if recognition_timer then
        recognition_timer:kill()
        recognition_timer = nil
    end

    mp.add_timeout(0.5, function()
        stop_recognition = false
        if continuous_recognition then
            start_continuous_recognition()
        else
            if recognizing or continuous_recognition then
                recognize_song()
            end
        end
    end)
end

mp.register_event("file-loaded", on_file_change)
mp.add_key_binding("y", "shazam_recognize", recognize_song)
mp.add_key_binding("shift+y", "toggle_continuous_recognition", toggle_continuous_recognition)

is_video_window_visible()
