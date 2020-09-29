if pcall(require, "gamesense/http") == false then --Check if the user has the http library
    error("Missing HTTP library, Library can be found at: https://gamesense.pub/forums/viewtopic.php?id=19253")
end

local http = require "gamesense/http" 

local messages = {
    time = {},
    name = {},
    message = {}
}

local last_update_success = false
local last_num_of_msg = nil
local next_send_time = 0
local time_offset = 0
local ip_address = ""

local lp = entity.get_local_player

local function remove_space(text)
    return string.gsub(text, "%s+", "__")
end

local function convert_space(text)
    return string.gsub(text, "%__", " ")
end

local function clamp(min, max, value)
    if min < max then
        return math.max(min, math.min(max, value))
    else
        return math.max(max, math.min(min, value))
    end
end

local function normalize_time(time)
    time = time + time_offset

    local normalized = false

    if time > 24 then
        time = 24 - time
    end       
    
    if time < 0 then
        time = 24 + time
    end

    if time > 12 then
        time = time - 12
    end

    if time == 0 then
        normalized = true
        time = 12
    end

    return {time, normalized}
end

local function find_timezone()
    http.get("https://api.ipgeolocation.io/timezone?apiKey=2cab7d21f5ba411e9c54ee63dafe7035&ip=" .. ip_address, {network_timeout = 200, absolute_timeout = 200}, function(success, response)
        if success then
            local body_json = json.parse(response.body)
            time_offset = body_json.timezone_offset + 1
        else
            client.delay_call(0.5, find_timezone)
        end
    end)
end

local function ip()
    http.get("https://api.ipify.org", {network_timeout = 200, absolute_timeout = 200}, function(success, response)
        if success then
            ip_address = response.body
            find_timezone()
        else
            client.delay_call(0.5, lp)
        end
    end)
end

ip()

local function collect_messages()
    http.get("http://offwhitechevysilverado.000webhostapp.com/chat/get.php", {network_timeout = 200, absolute_timeout = 200}, function(success, response)
        last_update_success = success
        if success then
            local response_json = json.parse(response.body)

            messages = {
                time = {},
                name = {},
                message = {}
            }

            for i=1, #response_json do
                local cur = response_json[i]
                table.insert(messages.time, cur.time)
                table.insert(messages.name, cur.author)
                table.insert(messages.message, cur.message)
            end
        end
    end)
end

local function send_message(name, text)
    local url = "http://offwhitechevysilverado.000webhostapp.com/chat/post.php?author=" .. remove_space(name) .. "&msg=" .. remove_space(text)
    local get = http.get(url, {network_timeout = 200, absolute_timeout = 200}, function(success, response)
        if success then
            client.delay_call(0.1, collect_messages)
            next_send_time = globals.realtime() + 4
        else
            send_message(name, text)
            client.color_log(255, 255, 100, "Failed to send message, FUCK FUCK")
        end
    end)
end

local function try_to_send(msg)
    if next_send_time - 1 < globals.realtime() then
        msg = string.gsub(msg, [[\]], "/")
        send_message(cvar.name:get_string(), msg)
    else
        client.color_log(255, 255, 100, "Please wait " .. math.floor((next_send_time - 1) - globals.realtime()) .. " seconds until you send another message")
    end
end

local msg_to_send = ui.new_textbox("config", "presets", "Message")
local send = ui.new_button("config", "presets", "Send", function()
    try_to_send(ui.get(msg_to_send))
    ui.set(msg_to_send, "")
end)

local function console_input(e)
    local trigger_key = "!"
    if e:sub(1, trigger_key:len()) == trigger_key then
        local removal = e:sub(trigger_key:len() + 1, e:len()) 
        try_to_send(removal)
    end
end

client.set_event_callback("console_input", console_input)

local until_sends = {}
for i=1, 3 do
    table.insert(until_sends, {i, ui.new_button("config", "presets", "Send (" .. i .. "s cooldown)", function() end)})
end

local sound = ui.new_checkbox("config", "presets", "Sound")

local function clamp(min, max, value)
    if min < max then
        return math.max(min, math.min(max, value))
    else
        return math.max(max, math.min(min, value))
    end
end

local function mouse_on(x, y, w, h)
    local mouse = {ui.mouse_position()}
    if mouse[1] > x - 1 and mouse[1] < x + w + 1 and mouse[2] > y - 1 and mouse[2] < y + h + 1 then
        return true
    end
    return false
end

local emojis = {
    {"smile", renderer.load_png(readfile("matrix_sb//smile.png") or error("Download icons dumbass @ https://anonfiles.com/ZdRfp7a8pe/matrix_icons_zip"), 32, 32)},
    {"happy", renderer.load_png(readfile("matrix_sb//happy.png") or error("Download icons dumbass @ https://anonfiles.com/ZdRfp7a8pe/matrix_icons_zip"), 32, 32)},
    {"meh", renderer.load_png(readfile("matrix_sb//meh.png") or error("Download icons dumbass @ https://anonfiles.com/ZdRfp7a8pe/matrix_icons_zip"), 32, 32)},
    {"angry", renderer.load_png(readfile("matrix_sb//angry.png") or error("Download icons dumbass @ https://anonfiles.com/ZdRfp7a8pe/matrix_icons_zip"), 32, 32)},
    {"sick", renderer.load_png(readfile("matrix_sb//sick.png") or error("Download icons dumbass @ https://anonfiles.com/ZdRfp7a8pe/matrix_icons_zip"), 32, 32)},
    {"love", renderer.load_png(readfile("matrix_sb//love.png") or error("Download icons dumbass @ https://anonfiles.com/ZdRfp7a8pe/matrix_icons_zip"), 32, 32)},
    {"flushed", renderer.load_png(readfile("matrix_sb//flushed.png") or error("Download icons dumbass @ https://anonfiles.com/ZdRfp7a8pe/matrix_icons_zip"), 32, 32)},
    {"quiet", renderer.load_png(readfile("matrix_sb//quiet.png") or error("Download icons dumbass @ https://anonfiles.com/ZdRfp7a8pe/matrix_icons_zip"), 32, 32)}
}

--texts = {flags, color(table: r,g,b,a), text}
local function multicolor(x, y, texts)
    local offset = 0
    for i=1, #texts do
        local msg = texts[i][3]
        local color = texts[i][2]
        local flag = texts[i][1]

        --{Start, end, emoji_name}
        local emoji_occurrences = {}

        local it_pos = nil
        local strings = {}
        msg:gsub(".",function(c) table.insert(strings,c) end)

        for i2=1, #strings do
            for i3=1, #emojis do
                if strings[i2] == ":" and (strings[i2 + emojis[i3][1]:len() + 1] ~= nil and strings[i2 + emojis[i3][1]:len() + 1] == ":") then

                    --Find whats inside the :*****:
                    local string_table = {}

                    for i4=i2 + 1, i2 + emojis[i3][1]:len() do
                        table.insert(string_table, strings[i4])
                    end

                    --Whats inside the :****:
                    local string_inside = table.concat(string_table)

                    --Check
                    if string_inside == emojis[i3][1] then
                        --YAY!!!
                        table.insert(emoji_occurrences, {i2, i2 + emojis[i3][1]:len() + 1, emojis[i3][2] })
                    end
                end
            end
        end
        for i2=1, #strings do
            local emote = false
            local mid_emote = false
            local start, end_, texture_id = nil, nil, nil

            for i3=1, #emoji_occurrences do
                local emoji_occurrence = emoji_occurrences[i3]
                if emoji_occurrence[1] == i2 then
                    emote = true
                    start, end_, texture_id = unpack(emoji_occurrence)
                end

                if emoji_occurrence[2] >= i2 and emoji_occurrence[1] < i2 then
                    mid_emote = true
                end
            end

            --print(strings[i2], " | E:", emote, " | S:", i2, " | End: ", end_, " | MD:", mid_emote)

            if mid_emote ~= true then
                local text_size = emote and {15, 15} or {renderer.measure_text(flag, strings[i2])}
                if emote then
                    renderer.texture(texture_id, x + offset - 1, y - 1, 16, 16, 255, 255, 255, 255, "f")
                else
                    renderer.text(x + offset, y, color[1], color[2], color[3], color[4], flag, 0, strings[i2])
                end
                offset = offset + text_size[1]
            end
        end

        --local text_size = {renderer.measure_text(flag, msg)}
        --renderer.text(x + offset, y, color[1], color[2], color[3], color[4], flag, 0, msg)


        --offset = offset + text_size[1]
    end
    return offset
end

local screen = {client.screen_size()}
local center = {screen[1]/2, screen[2]/2}

local color = ui.new_color_picker("config", "presets", "Name color", 150, 150, 255, 255)
local x_pos = ui.new_slider("config", "presets", "Matrix shout x", -100, screen[1] + 100, 10)
local y_pos = ui.new_slider("config", "presets", "Matrix shout y", -100, screen[2] + 100, 500)
local ind_w = ui.new_slider("config", "presets", "Matrix width", 200, 500, 250)
ui.set_visible(x_pos, false)
ui.set_visible(y_pos, false)
ui.set_visible(ind_w, false)

local size = {ui.get(ind_w), 187}
local position = {ui.get(x_pos), ui.get(y_pos)}
local background_color = {25, 25, 25, 125}

--Refresh stuff
local update_rate = 5
local update_timer = 0

local drag_mode = nil
local dragging = false
local drag_x = 0
local drag_y = 0

local function paint()

    local mouse = {ui.mouse_position()}
    local menu_pos = {ui.menu_position()}
    local menu_size = {ui.menu_size()}

    if ui.is_menu_open() then
        if dragging and not client.key_state(0x01) then
            dragging = false
            drag_mode = nil
        end

        if dragging and client.key_state(0x01) then
            if drag_mode == 0 then
                position[1] = mouse[1] - drag_x
                position[2] = mouse[2] - drag_y
                ui.set(x_pos, clamp(-100, screen[1] + 100, position[1]))
                ui.set(y_pos, clamp(-100, screen[2] + 100, position[2]))
            else
                ui.set(ind_w, clamp(200, 500, start_drag_width + mouse[1] - drag_x))
                size[1] = ui.get(ind_w)
            end
        end
        if mouse_on(menu_pos[1], menu_pos[2], menu_size[1], menu_size[2]) == false or client.key_state(0x01) then
            --Cope idfc
            if mouse_on(position[1], position[2], size[1] - 20, size[2]) and (drag_mode == nil or drag_mode == 0) then
                drag_mode = 0
                dragging = true
                drag_x = mouse[1] - position[1]
                drag_y = mouse[2] - position[2]
            elseif mouse_on(position[1] + size[1] - 17, position[2], 20, size[2]) and (drag_mode == nil or drag_mode == 1) then
                drag_mode = 1
                dragging = true
                start_drag_width = size[1]
                drag_x = mouse[1]
            end
        end
    end

    --Button stuff
    local time = math.floor(next_send_time - globals.realtime())
    for i=1, #until_sends do
        ui.set_visible(until_sends[i][2], time == until_sends[i][1])
    end
    ui.set_visible(send, next_send_time - 1 < globals.realtime())


    position = {ui.get(x_pos), ui.get(y_pos)}

    --Update
    if update_timer < globals.realtime() then
        collect_messages()
        update_timer = globals.realtime() + update_rate
    end

    --Top text
    local top_text = "Matrix shoutbox"
    local top_size = {renderer.measure_text(nil, top_text)}
    renderer.rectangle(position[1], position[2], size[1], 15, background_color[1], background_color[2], background_color[3], 225)
    renderer.text(position[1] + size[1]/2 - top_size[1]/2, position[2], 255, 255, 255, 255, "", 0, top_text)

    --Server status
    local server_color = last_update_success and {100, 255, 50} or {255, 100, 100}
    renderer.rectangle(position[1] + 5, position[2] + 5, 4, 4, server_color[1], server_color[2], server_color[3], 255)

    local left_top = "GMT +/- " .. math.abs(time_offset)
    local left_size = {renderer.measure_text("", left_top)}
    renderer.text(position[1] + 12, position[2] + 1, 255, 255, 255, 255, "", 0, left_top)

    --Background
    renderer.rectangle(position[1], position[2] + 17, size[1], size[2], background_color[1], background_color[2], background_color[3], background_color[4])

    if #messages.name ~= 0 then
        local offset = size[2] - 15

        local name_color = {ui.get(color)}

        --Cope..
        for i=#messages.name, clamp(1, #messages.name, #messages.name - 10 ), - 1 do
            local time = messages.time[i]

            time = string.sub(time, 12, time:len() - 3)

            local hours = tonumber(string.sub(time, 1, time:len() - 3))
            local minutes = tonumber(string.sub(time, 4, time:len()))

            local new_time = normalize_time(hours)

            time = string.format("%02d", new_time[1]) .. ":" .. string.format("%02d", minutes) .. " " .. (new_time[2] and "AM" or "PM") .. " "

            local name = convert_space(messages.name[i])
            local msg = convert_space(messages.message[i])
            local raw_msg = msg

            local name_long = true
            local name_was_2_long = false

            while name_long do
                local size = {renderer.measure_text(nil, name)}
                if size[1] < 100 then
                    name_long = false
                else
                    name_was_2_long = true
                    name = string.sub(name, 1, name:len() - 1)
                end 
            end

            if name_was_2_long then
                name = name .. ".. "
            end

            local format_string = string.format("%s %s: %s", time, name, msg)
            local text_size = {renderer.measure_text(nil, format_string)}

            local string_long = true
            local string_was_2_long = false

            while string_long do
                local format_string = string.format("%s %s: %s", time, name, msg)
                local text_size = {renderer.measure_text(nil, format_string)}
                if text_size[1] < size[1] then
                    string_long = false
                else
                    string_was_2_long = true
                    msg = string.sub(msg, 1, msg:len() - 1)
                end 
            end

            if string_was_2_long then
                msg = string.sub(msg, 1, msg:len() - 3) .. ".. "
            end 
            
            local alpha = clamp(0, 255, 155 + (((i - (#messages.name - 11)))/10)*100)

            if string.match(raw_msg, "@" .. cvar.name:get_string()) or string.match(raw_msg, "@everyone") then
                renderer.gradient(position[1], position[2] + 16 + offset, size[1], text_size[2] + 4, name_color[1], name_color[2], name_color[3], 100, name_color[1], name_color[2], name_color[3], 25, true)
            end

            local width = multicolor(position[1] + 5, position[2] + offset + 17, {
                {"", {255, 255, 255, clamp(0, 255, alpha)}, time},
                {"", name_color, name},
                {"", {255, 255, 255, 255}, ": " .. msg}
            })
            offset = offset - text_size[2] - 5
        end

        if #messages.name ~= last_num_of_msg then
            if ui.get(sound) then
                client.exec([[play buttons\lightswitch2]])
            end
            last_num_of_msg = #messages.name
        end
    end
end

client.set_event_callback("paint_ui", paint)
