--Menu--
local enable = ui.new_checkbox("lua", "a", "Radar")
local padding = ui.new_slider("lua", "a", "Padding", 10, 100, 30, true)
local size = ui.new_slider("lua", "a", "Size", 100, 175, 100)
local show_view = ui.new_checkbox("lua", "a", "Show view angles")
local color_mode = ui.new_combobox("lua", "a", "Color mode", {"Rainbow", "Static"})
local color_picker = ui.new_color_picker("lua", "a", "Static color", 64, 79, 243, 255)
local rainbow_speed = ui.new_slider("lua", "a", "Rainbow speed", 1, 15)

--ui.set_visible but with table of items
local function set_visible(state, ...)
    local items = {...}
    for i=1, #items do
        ui.set_visible(items[i], state)
    end
end

--Handle GUI
local function handle_gui()
    local enable_g = ui.get(enable)
    set_visible(enable_g, padding, size, show_view, color_mode)
    ui.set_visible(color_picker, enable_g and ui.get(color_mode) == "Static")
    ui.set_visible(rainbow_speed, enable_g and ui.get(color_mode) == "Rainbow")
end

--LP
local function lp()
    local real_lp = entity.get_local_player()
    if entity.is_alive(real_lp) then
        return real_lp
    else
        local obvserver = entity.get_prop(real_lp, "m_hObserverTarget")
        return obvserver ~= nil and obvserver <= 64 and obvserver or nil
    end
end

--search through tables
local function include(table, key)
    for i=1, #table do
        if table[i] == key then
            return true, i
        end
    end
    return false, nil
end

--Normalize dis bitch
local function normalize(yaw)
    yaw = (yaw % 360 + 360) % 360
    return yaw > 180 and yaw - 360 or yaw
end

--Clamp a number
local function clamp(min, max, value)
    return math.max(min < max and min or max, math.min(min < max and max or min, value))
end

--Distance between 2 points
local function distance2d(origin, origin2)
    local delta = {origin[1] - origin2[1], origin[2] - origin2[2]}
    return math.sqrt(delta[1] * delta[1] + delta[2] * delta[2])
end

--fade 2 colors
local function fade(color, color_2, percent)
	local return_results = {}
	for i=1, #color do
		return_results[i] = color[i] + (color_2[i] - color[i]) * percent
	end
	return return_results
end

--Calculate angle between 2 points
local function calculate_angle(p1, p2)
    local delta = {p1[1] - p2[1], p1[2] - p2[2]}
    local yaw = math.atan(delta[2] / delta[1])
    yaw = normalize(yaw * 180 / math.pi)
    if delta[1] >= 0 then
        yaw = normalize(yaw + 180)
    end
    return yaw
end

--Rotate point around a center point
local function rotate_point(cx, cy, angle, distance)
    angle = math.rad(angle or 0)
    distance = distance or 0

    local x = math.sin(angle) * distance
    local y = math.cos(angle) * distance

    x = cx - x
    y = cy - y

    return {x, y}
end

--Yaw
local function calculate_yaw(index)
    local head = {entity.hitbox_position(index, 0)}
    local penis = {entity.hitbox_position(index, 2)}
    return normalize(calculate_angle({head[1], head[2]}, {penis[1], penis[2]}) + 180) --Cope but best way i thought of
end

--Get all weapons
local function get_weapons(index)
    local results = {}
    for i=0, 64 do
        if entity.get_prop(index, "m_hMyWeapons", i) then
            table.insert(results, entity.get_classname(entity.get_prop(index, "m_hMyWeapons", i)))
        end
    end
    return results
end

--Does player have c4?
local function has_c4(index)
    local weapons = get_weapons(index)
    local contains, i = include(weapons, "CC4")
    return contains
end

--Draw player
local function draw_player(postiion, color, angle, distance, draw_view, view, has_bomb)
    local rotated = rotate_point(postiion[1], postiion[2], angle, distance)

    local circle_size = 0

    if has_bomb then
        circle_size = 8
        renderer.circle(rotated[1], rotated[2], color[1], color[2], color[3], 125, circle_size, 90, 1)
        renderer.text(rotated[1], rotated[2] - 1, 255, 255, 255, 255, "c", 0, "C4")
    else
        circle_size = 5
        renderer.circle(rotated[1], rotated[2], color[1], color[2], color[3], color[4], circle_size, 90, 1)
    end

    if draw_view then
        --Find arrow point
        local arrow_point = rotate_point(rotated[1], rotated[2], view, circle_size)

        --Draw arrow
        local top = rotate_point(arrow_point[1], arrow_point[2], view, 10)
        local left = rotate_point(arrow_point[1], arrow_point[2], view + 60, 5)
        local right = rotate_point(arrow_point[1], arrow_point[2], view - 60, 5)

        renderer.triangle(top[1], top[2], left[1], left[2], right[1], right[2], color[1], color[2], color[3], 120)
    end
end

local function draw_bomb(postiion, color, angle, distance)
    local rotated = rotate_point(postiion[1], postiion[2], angle, distance)
    renderer.circle(rotated[1], rotated[2], color[1], color[2], color[3], 125, 7, 90, 1)
    renderer.text(rotated[1], rotated[2] - 1, 255, 255, 255, 255, "c", 0, "C4")
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

--Gradient function
local function gradient_circle(position, color, color2, outline_color, start_offset, radius, thickness, percent, percent_whole_circle)
    --Higher number == less fps due to drawing (#precision) amount of circles
    local precision = 250

    renderer.circle_outline(position[1], position[2], outline_color[1], outline_color[2], outline_color[3], outline_color[4], radius, 90, 1, thickness)

    --[[
    for i=0, (precision*(percent)) do
        local color = fade(color, color2, i/(precision*(percent)))
        renderer.circle_outline(position[1], position[2], color[1], color[2], color[3], color[4], radius - 1, 90 + start_offset + (360 * (i/precision)), 1/(precision * (percent)) , thickness - 2)
    end
    ]]

    local precision = 360

    for i=0, precision*(percent*percent_whole_circle) do
        local color = fade(color, color2, i/(precision*(percent*percent_whole_circle)))
        renderer.circle_outline(position[1], position[2], color[1], color[2], color[3], color[4], radius - 1, 90 + start_offset + i, 1/(precision * (percent)) , thickness - 2)
    end

    return position[1] + radius*2, position[2] + radius*2
end

--Colors
local background = {25, 25, 25, 255}
local green = {175, 255, 50, 255}
local blue = {125, 255, 255, 255}
local red = {255, 50, 50, 255}
local dormancy_color = {100, 100, 100, 255}

local base = {30, 30}
local radar_size = ui.get(size)
local radar_scale = 0.1

--Update on change 
ui.set_callback(size, function()
    radar_size = ui.get(size)
end)


ui.set_callback(padding, function()
    local padding_g = ui.get(padding)
    base = {padding_g, padding_g}
end)

local function collect_players()
    local results = {}
    local lp_origin = {entity.get_origin(lp())}

    for i=1, 64 do
        if entity.is_alive(i) then
            local player_origin = {entity.get_origin(i)}
            if player_origin[1] ~= nil and lp_origin[1] ~= nil then
                table.insert(results, {i, calculate_angle({lp_origin[1], lp_origin[2]}, {player_origin[1], player_origin[2]}), distance2d(player_origin, lp_origin), calculate_yaw(i)})
            end
        end
    end
    return results
end

local function radar_background()
    renderer.circle(base[1] + radar_size, base[2] + radar_size, background[1], background[2], background[3], 125, radar_size - 1, 90, 1)

    --Draw gradient around radar
    local increment = 360/10

    local mode_g = ui.get(color_mode)
    local color_g = {ui.get(color_picker)}
    local speed_g = ui.get(rainbow_speed)

    if mode_g == "Rainbow" then
        --Gradient circle thing
        for i=1, 10 do
            i = i - 1
            local start_color = rainbow(speed_g, i*increment, 100, 100, 255)
            local end_color = rainbow(speed_g, (i*increment)+increment, 100, 100, 255)
            gradient_circle({base[1] + radar_size, base[2] + radar_size}, start_color, end_color, {0, 0, 0, 0}, i*36, radar_size, 5, 1, 0.1)
        end
    else
        gradient_circle({base[1] + radar_size, base[2] + radar_size}, color_g, color_g, {0, 0, 0, 0}, 0, radar_size, 5, 1, 1)
    end
end

local function radar_players()
    local radars = collect_players()
    local camera = {client.camera_angles()}
    local lp_origin = {entity.get_origin(lp())}

    for i=1, #radars do
        local radar = radars[i]
        local index, yaw, distance, view = unpack(radar)

        yaw = normalize(yaw - camera[2])
        view = normalize(view - camera[2])

        local color = {255, 0, 0, 255}
        if entity.is_enemy(index) then
            color = entity.is_dormant(index) and dormancy_color or red
        else
            color = green
        end 

        draw_player({base[1] + radar_size, base[2] + radar_size}, color, yaw, clamp(0, radar_size - 15, distance * radar_scale), ui.get(show_view), view, has_c4(index))
    end

    --Bomb
    local bomb = entity.get_all("CPlantedC4")[1]
    if bomb ~= nil then
        local explode_time = entity.get_prop(bomb, "m_flC4Blow") - globals.curtime()
        if entity.get_prop(bomb, "m_bBombDefused") == 0 and explode_time > 0 then
            local bomb_origin = {entity.get_origin(bomb)}
            draw_bomb({base[1] + radar_size, base[2] + radar_size}, {255, 255, 0, 255}, normalize(calculate_angle({lp_origin[1], lp_origin[2]}, {bomb_origin[1], bomb_origin[2]}) - camera[2]), clamp(0, radar_size - 15, distance2d(bomb_origin, lp_origin) * radar_scale))
        end
    end

    draw_player({base[1] + radar_size, base[2] + radar_size}, blue, 0, 0, true, normalize(calculate_yaw(lp()) - camera[2]), has_c4(lp()))
end

local function handle_render()
    local enable_g = ui.get(enable)
    if enable_g == false or lp() == nil then
        return
    end

    --Hide
    cvar.cl_drawhud_force_radar:set_raw_int(-1)

    radar_background()
    radar_players()
end

local function shutdown()
    cvar.cl_drawhud_force_radar:set_raw_int(1)
end

--Same thing as client.set_event_callback but works with tables
local function callbacks(event, ...)
    local items = {...}
    for i=1, #items do
        client.set_event_callback(event, items[i])
    end
end

callbacks("paint_ui", handle_gui)
callbacks("paint", handle_render)
callbacks("shutdown", shutdown)
