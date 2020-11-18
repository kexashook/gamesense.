--[[
    Sexy radar
    Creator: kez#2466
]]

local function include(table, key)
    for i=1, #table do
        if table[i] == key then
            return true, i
        end
    end
    return false, nil
end

--Returns lp (us) or who we're specin 
local function lp()
    local real_lp = entity.get_local_player()
    if entity.is_alive(real_lp) then
        return real_lp
    else
        local obvserver = entity.get_prop(real_lp, "m_hObserverTarget")
        return obvserver ~= nil and entity.get_classname(obvserver) == "CCSPlayer" and obvserver or nil
    end
end

--Clamp
local function clamp(min, max, value)
    return math.max(min < max and min or max, math.min(min < max and max or min, value))
end

--Normalize
local function normalize(yaw)
    yaw = (yaw % 360 + 360) % 360
    return yaw > 180 and yaw - 360 or yaw
end

--lerp
local function fade(color, color_2, percent)
	local return_results = {}
	for i=1, #color do
		return_results[i] = color[i] + (color_2[i] - color[i]) * percent
	end
	return return_results
end

--Color converter
local function hsv_to_rgb(h, s, v)
    local r, g, b

    h = h/360
    s = s/100
    v = v/100
    
    local i = math.floor(h * 6);
    local f = h * 6 - i;
    local p = v * (1 - s);
    local q = v * (1 - f * s);
    local t = v * (1 - (1 - f) * s);

    i = i % 6

    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end

    return r * 255, g * 255, b * 255
end

--Rainbow function
local function rainbow(speed, offset, s, v, a)
    --Default to if nothing was provided (retards)
    speed = speed or 10
    offset = offset or 0
    s = s or 100
    v = v or 100

    local h = ((globals.tickcount() * speed) % 360) + offset

    --Normalize
    while h > 360 do
        h = h - 360
    end

    while h < 0 do
        h = 360 - h
    end

    --Just incase...
    h = clamp(0, 360, h)

    local color = {hsv_to_rgb(h, s, v)}
    --Add alpha
    table.insert(color, a)

    return color
end

--Angle between 2 points
local function calculate_angle(p1, p2) --Pasted
    local delta = {p1[1] - p2[1], p1[2] - p2[2]}
    local yaw = math.atan(delta[2] / delta[1])
    yaw = normalize(yaw * 180 / math.pi)
    if delta[1] >= 0 then
        yaw = normalize(yaw + 180)
    end
    return yaw
end

local roundto = function(value, to)
    local mod = value % to 
    return mod < to/2 and value - mod or value + (to - mod)
end

local calculate_yaw = function(index)
    local _, rot = entity.get_prop(index, "m_angRotation")
    local body_yaw = (entity.get_prop(index, "m_flPoseParameter", 11) or 1) * 120 - 60
    return normalize(rot + body_yaw)
end

local function get_weapons(index)
    local results = {}
    for i=0, 64 do
        if entity.get_prop(index, "m_hMyWeapons", i) then
            table.insert(results, entity.get_classname(entity.get_prop(index, "m_hMyWeapons", i)))
        end
    end
    return results
end

local function has_c4(index)
    local weapons = get_weapons(index)
    local contains, i = include(weapons, "CC4")
    return contains
end


local find_bomb = function()
    local planted_bomb = entity.get_all("CPlantedC4")[1]
    local bomb = entity.get_all("CC4")[1]

    if planted_bomb ~= nil then
        local explode_time = entity.get_prop(planted_bomb, "m_flC4Blow") - globals.curtime()
        if entity.get_prop(planted_bomb, "m_bBombDefused") == 0 and explode_time > 0 then
            return {true, {entity.get_origin(planted_bomb)}}
        end
        return nil
    elseif bomb ~= nil then
        return {false, {entity.get_origin(bomb)}}
    else
        return nil
    end 
end

--Location in menu
local spot = {"Visuals", "Other ESP"}

--Items
local enable = ui.new_checkbox(spot[1], spot[2], "Enable radar")
local color_mode = ui.new_combobox(spot[1], spot[2], "Color mode", {"Rainbow", "Static"})
local color_static = ui.new_color_picker(spot[1], spot[2], "Static radar color", 220, 220, 220, 125)
local rainbow_speed = ui.new_slider(spot[1], spot[2], "Rainbow speed", 1, 15, 5)

--Colors
local enemy_label = ui.new_label(spot[1], spot[2], "Enemy")
local enemy_color = ui.new_color_picker(spot[1], spot[2], "Enemy color picker", 255, 50, 50, 255)
local team_label = ui.new_label(spot[1], spot[2], "Team")
local team_color = ui.new_color_picker(spot[1], spot[2], "Team color picker", 100, 255, 100, 255)
local local_label = ui.new_label(spot[1], spot[2], "Local")
local local_color = ui.new_color_picker(spot[1], spot[2], "Local color picker", 69, 209, 255, 255)

--Pos stuff
local padding = ui.new_slider(spot[1], spot[2], "Padding", 10, 100, 25, true, "%")
local radar_size = ui.new_slider(spot[1], spot[2], "Size", 50, 100, 75, true, "%")

local radar_scale = ui.new_slider(spot[1], spot[2], "Scale", 10, 100, 50, true, "%")

local position = ui.get(padding)
local size = ui.get(radar_size)

local set_visible = function(state, ...)
    local items = {...}
    for i=1, #items do
        ui.set_visible(items[i], state)
    end
end

--Handle visibility  
local handle_gui = function()
    local master_state = ui.get(enable)
    set_visible(master_state, color_mode, enemy_label, enemy_color, team_label, team_color, local_label, local_color, padding, radar_size, radar_scale)

    local color_mode_g = ui.get(color_mode)
    ui.set_visible(color_static, master_state and color_mode_g == "Static")
    ui.set_visible(rainbow_speed, master_state and color_mode_g == "Rainbow")
end

local players = {
    index = {}, --Entindex
    valid = {}, --If entity is a player or not
    dormant_percent = {}, --Used to fade between dormancy and normal
    valid_percent = {}, --Used to fade out and in once a entity gets killed or respawns
    last_origin = {}
}

--Load tables with basic presets
for i=1, 64 do --For 64 possible players in a server 
    players.index[i] = i
    players.valid[i] = false
    players.dormant_percent[i] = 0
    players.valid_percent[i] = 0
    players.last_origin[i] = nil
end

--pythagorean theorem to calculate distance between 2 points
local distance2d = function(point, point2)
    local delta = {point[1] - point2[1], point[2] - point2[2]}
    return math.sqrt((delta[1] * delta[1]) + (delta[2] * delta[2]))
end

--Draws a cross 
local cross_rectangle = function(x, y, w, h, thickness, mode, ...)
    local color = {...}
    if mode then
        renderer.rectangle(x + w/2 - thickness/2, y, thickness, h, color[1], color[2], color[3], color[4])
        renderer.rectangle(x, y + h/2 - thickness/2, w, thickness, color[1], color[2], color[3], color[4])
    else
        renderer.gradient(x + w/2 - thickness, y, thickness, h/2, color[1], color[2], color[3], color[4], color[1], color[2], color[3], 0, false)
        renderer.gradient(x + w/2 - thickness, y + h/2, thickness, h/2, color[1], color[2], color[3], 0, color[1], color[2], color[3], color[4], false)
        renderer.gradient(x, y + h/2 - thickness/2, w/2, thickness, color[1], color[2], color[3], color[4], color[1], color[2], color[3], 0, true)
        renderer.gradient(x + w/2, y + h/2 - thickness/2, w/2, thickness, color[1], color[2], color[3], 0, color[1], color[2], color[3], color[4], true)
    end
end

--Draws an outlien
local outer_rectangle = function(x, y, w, h, thickness, mode, ...)
    if mode then 
        local color = {...}
        renderer.rectangle(x, y, w - thickness, thickness, color[1], color[2], color[3], color[4])
        renderer.rectangle(x + w - thickness, y, thickness, h, color[1], color[2], color[3], color[4])
        renderer.rectangle(x, y + h - thickness, w - thickness, thickness, color[1], color[2], color[3], color[4])
        renderer.rectangle(x, y + thickness, thickness, h - thickness*2, color[1], color[2], color[3], color[4])
    else
        local data = {...}
        local speed = data[1]
        local sat = 80

        --Rainbow stuff (COPE)
        local color_0 = rainbow(speed, 0, sat, 100, 255)
        local color_45 = rainbow(speed, 45, sat, 100, 255)
        local color_90 = rainbow(speed, 90, sat, 100, 255)
        local color_135 = rainbow(speed, 135, sat, 100, 255)
        local color_180 = rainbow(speed, 180, sat, 100, 255)
        local color_225 = rainbow(speed, 225, sat, 100, 255)
        local color_270 = rainbow(speed, 270, sat, 100, 255)
        local color_315 = rainbow(speed, 315, sat, 100, 255)
        local color_360 = rainbow(speed, 360, sat, 100, 255)

        --Top
        renderer.gradient(x, y, (w - thickness)/2, thickness, color_0[1], color_0[2], color_0[3], color_0[4], color_45[1], color_45[2], color_45[3], color_45[4], true)
        renderer.gradient(x + ((w - thickness)/2), y, (w - thickness)/2, thickness, color_45[1], color_45[2], color_45[3], color_45[4], color_90[1], color_90[2], color_90[3], color_90[4], true)
        --Right
        renderer.gradient(x + w - thickness, y, thickness, h/2, color_90[1], color_90[2], color_90[3], color_90[4], color_135[1], color_135[2], color_135[3], color_135[4], false)
        renderer.gradient(x + w - thickness, y + h/2, thickness, h/2, color_135[1], color_135[2], color_135[3], color_135[4], color_180[1], color_180[2], color_180[3], color_180[4], false)
        --Bottom
        renderer.gradient(x + (w - thickness)/2, y + h - thickness, (w - thickness)/2, thickness, color_225[1], color_225[2], color_225[3], color_225[4], color_180[1], color_180[2], color_180[3], color_180[4], true)
        renderer.gradient(x, y + h - thickness, (w - thickness)/2, thickness, color_270[1], color_270[2], color_270[3], color_270[4], color_225[1], color_225[2], color_225[3], color_225[4], true)
        --Left
        renderer.gradient(x, y + thickness, thickness, (h - thickness*2)/2, color_360[1], color_360[2], color_360[3], color_360[4], color_315[1], color_315[2], color_315[3], color_315[4], false)
        renderer.gradient(x, y + thickness + (h - thickness*2)/2, thickness, (h - thickness*2)/2, color_315[1], color_315[2], color_315[3], color_315[4], color_270[1], color_270[2], color_270[3], color_270[4], false)
    end
end

--Rotates point around another one
local rotate_point = function(cx, cy, angle, distance)
    angle = math.rad(angle or 0)
    distance = distance or 0

    local x = math.sin(angle) * distance
    local y = math.cos(angle) * distance

    x = cx - x
    y = cy - y

    return {x, y}
end

--Gets the entities position on the radar
local entity_position = function(origin)
    --if entity.is_alive(player) == false or entity.get_classname(player) ~= "CCSPlayer" then
    --    return nil
    --end
    local local_origin = {entity.get_origin(lp())}

    if origin[1] == nil or local_origin[1] == nil then
        return nil
    end

    --Calc stuff
    local distance = distance2d(origin, local_origin)
    local yaw = calculate_angle(local_origin, origin)

    local camera = {client.camera_angles()}
    yaw = normalize(yaw - camera[2])

    --Center of radar
    local center = {position + size/2, position + size/2}

    --Rotate point around center
    local point = rotate_point(center[1], center[2], yaw, distance * ui.get(radar_scale)/500)

    --Clamp to screen
    local edge_padding = 10

    point[1] = clamp(position + edge_padding, position + size - edge_padding, point[1])
    point[2] = clamp(position + edge_padding, position + size - edge_padding, point[2])

    --Finally.
    return point
end

local draw_icon = function(index, origin, color, text)
    local pos = index == lp() and {position + size/2, position + size/2} or entity_position(origin)
    renderer.circle(pos[1], pos[2], color[1], color[2], color[3], 125, 7, 90, 1)
    renderer.text(pos[1], pos[2] - 1, 255, 255, 255, 255, "c", 0, text)
end

local draw_arrow = function(x, y, circle_size, view, color)
    local arrow_point = rotate_point(x, y, view, circle_size)
    --Draw arrow
    local top = rotate_point(arrow_point[1], arrow_point[2], view, 10)
    local left = rotate_point(arrow_point[1], arrow_point[2], view + 60, 5)
    local right = rotate_point(arrow_point[1], arrow_point[2], view - 60, 5)
    renderer.triangle(top[1], top[2], left[1], left[2], right[1], right[2], color[1], color[2], color[3], color[4])
end

--Main function for da pogger radarenz1337 420 69
local radar = function()
    position = ui.get(padding)/2.85714285714
    size = roundto(ui.get(radar_size)/0.33333333333, 4)

    --Enable radar (so that it will draw if it doesn't pass the checks)
    cvar.cl_drawhud_force_radar:set_raw_int(1)

    --Checks
    if lp() == nil or ui.get(enable) == false then
        return
    end

    --Disable radar
    cvar.cl_drawhud_force_radar:set_raw_int(-1)

    --Get color
    local theme_color = {ui.get(color_static)}

    --Draw radar
    renderer.rectangle(position, position, size, size, 25, 25, 25, 120)
    cross_rectangle(position, position, size, size, 1, false, 100, 100, 100, 100)

    --Draw outline
    if ui.get(color_mode) == "Static" then
        outer_rectangle(position, position, size, size, 2, true, unpack(theme_color))
    else
        outer_rectangle(position, position, size, size, 2, false, ui.get(rainbow_speed))
    end

    --ya.
    local increment = 10 * globals.frametime()
    local decrement = 5 * globals.frametime()

    --Player colors
    local enemy_color_g = {ui.get(enemy_color)}
    local team_color_g = {ui.get(team_color)}
    local local_color_g = {ui.get(local_color)}

    --Loop through players 
    for i=1, #players.index do
        local entindex = players.index[i]

        --Valid check
        players.valid[i] = entity.is_alive(entindex) and entity.get_classname(entindex) == "CCSPlayer" and entindex ~= lp()

        --Update animation related shit
        local old_valid = players.valid_percent[i]
        local old_dormancy = players.dormant_percent[i]
        players.valid_percent[i] = clamp(0, 1, players.valid[i] and old_valid + increment or old_valid - decrement)
        players.dormant_percent[i] = clamp(0, 1, (players.valid[i] and entity.is_dormant(entindex)) and old_dormancy + increment or old_dormancy - decrement)

        --Update last origin
        if entity.get_origin(entindex) ~= nil then
            players.last_origin[i] = {entity.get_origin(entindex)}
        end

        local new_valid = players.valid_percent[i]
        local new_dormancy = players.dormant_percent[i]

        if new_valid > 0 then
            --Find the color of the entity
            local color = {0, 0, 0, 0}
            if entity.is_enemy(entindex) then
                color = fade(enemy_color_g, {75, 75, 75, new_valid * 255}, new_dormancy)
            else
                color = fade(team_color_g, {team_color_g[1], team_color_g[2], team_color_g[3], 0}, new_dormancy)
            end
            color = {color[1], color[2], color[3], clamp(0, new_valid*255, color[4])}

            --Get the current or last origin
            local player_origin = {entity.get_origin(entindex)} or players.last_origin[i]
            
            --Calculate the position on the radar
            local pos = entity_position(player_origin)
            if pos ~= nil then
                --Draw
                if has_c4(entindex) then
                    draw_icon(entindex, player_origin, color, "C4")
                else
                    renderer.circle(pos[1], pos[2], color[1], color[2], color[3], color[4], 4, 90, 1)
                end
            end
        end
    end

    --Bomb sites 
    local resource = entity.get_player_resource()
    local bombA = {entity.get_prop(resource, "m_bombsiteCenterA", lp())}
    local bombB = {entity.get_prop(resource, "m_bombsiteCenterB", lp())}

    if bombA[1] ~= 0 and bombA[2] ~= 0 and bombA[3] ~= 0 then
        draw_icon(nil, bombA, {255, 255, 50, 255}, "A")
    end

    if bombB[1] ~= 0 and bombB[2] ~= 0 and bombB[3] ~= 0 then
        draw_icon(nil, bombB, {255, 255, 50, 255}, "B")
    end

    --Dropped/Planted C4
    local bomb = find_bomb()
    if bomb ~= nil then
        if bomb[1] then
            draw_icon(nil, bomb[2], {255, 0, 0, 255}, "C4")
        else
            draw_icon(nil, bomb[2], {255, 255, 0, 255}, "C4")
        end
    end

    --Draw local player
    local camera = {client.camera_angles()}
    if has_c4(lp()) then
        draw_icon(lp(), {}, local_color_g, "C4")
        draw_arrow(position + size/2, position + size/2, 7, normalize(calculate_yaw(lp()) - camera[2]), local_color_g)
    else
        renderer.circle(position + size/2, position + size/2, local_color_g[1], local_color_g[2], local_color_g[3], local_color_g[4], 4, 90, 1)
        draw_arrow(position + size/2, position + size/2, 4, normalize(calculate_yaw(lp()) - camera[2]), local_color_g)
    end
end

local shutdown = function()
    cvar.cl_drawhud_force_radar:set_raw_int(1)
end

--Set multiple callbacks with one function 
local set_callbacks = function(event, ...)
    local table = {...}

    for i=1, #table do
        client.set_event_callback(event, table[i])
    end
end

set_callbacks("shutdown", shutdown)
set_callbacks("paint_ui", handle_gui)
set_callbacks("paint", radar)
