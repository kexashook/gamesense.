--Menu elements
local enable = ui.new_checkbox("lua", "a", "Enable spy cam")
local hotkey = ui.new_hotkey("lua", "a", "Spy key (◣_◢)")
local view_distance = ui.new_slider("lua", "a", "Camera distance", 60, 200, 75)

local handle_gui = function() --Handle vis shit
    ui.set_visible(hotkey, ui.get(enable))
    ui.set_visible(view_distance, ui.get(enable))
end

local lp = entity.get_local_player
local closest_to_crosshair = nil

local normalize_yaw = function(yaw) --not mine :flushed:
    yaw = (yaw % 360 + 360) % 360
    return yaw > 180 and yaw - 360 or yaw
end

local clamp = function(min, max, current) --Clamp a value between 2
    if min < max then
        return math.min(max, math.max(min, current))
    else
        return math.min(min, math.max(max, current))
    end
end

local calculate_angle = function(x, y, ex, ey)
    local delta = {x - ex, y - ey}
    local yaw = math.atan(delta[2] / delta[1])
    yaw = normalize_yaw(yaw * (180 / math.pi))
    if delta[1] >= 0 then
        yaw = normalize_yaw(yaw + 180)
    end
    return yaw
end

local lerp = function(from, to, percent)
    local yes = {}
	for i=1, #from do
		yes[i] = from[i] + (to[i] - from[i]) * percent
	end
	return yes
end

local calculate_best = function() --Find enemy closest to crosshair
    if lp() == nil or entity.is_alive(lp()) == false then
        return
    end

    if ui.get(hotkey) and entity.is_alive(closest_to_crosshair) ~= false then
        return
    end

    local data = {nil, 420}

    local local_origin = {entity.get_origin(lp())}
    local view_angles = {client.camera_angles()}

    --Loop thru all enemies
    local enemies = entity.get_players(true)
    for i=1, #enemies do
        local player = enemies[i]

        local player_origin = {entity.get_origin(player)}

        if player_origin[1] then
            local yaw = calculate_angle(local_origin[1], local_origin[2], player_origin[1], player_origin[2])
            local difference = math.abs(normalize_yaw(yaw - view_angles[2]))

            if difference < data[2] then
                data[1] = player
                data[2] = difference
            end
        end
    end
    closest_to_crosshair = data[1]
end

local rotate_point = function(cx, cy, angle, distance) --yas
    angle = math.rad(angle or 0)
    distance = distance or 0

    local x = math.cos(angle) * distance
    local y = math.sin(angle) * distance

    x = cx - x
    y = cy - y

    return {x, y}
end

local eye_position = function(index) --Get eye position for other players
    local origin = {entity.get_origin(index)}
    if origin[1] == nil then
        return nil
    end
    local view_offset = {entity.get_prop(index, "m_vecViewOffset")}

    if view_offset[1] == nil then 
        return nil
    end
    --return {origin[1] + view_offset[1], origin[2] + view_offset[2], origin[3] + view_offset[3]}
    return {origin[1], origin[2], origin[3] + 75}
end

local function angle_forward(angle)
    if angle[1] ~= nil and angle[2] ~= nil then
        angle[1] = math.rad(angle[1])
        angle[2] = math.rad(angle[2])

        local sin_pitch = math.sin(angle[1])
        local sin_yaw = math.sin(angle[2])
        local cos_pitch = math.cos(angle[1])
        local cos_yaw = math.cos(angle[2])

        return {cos_pitch * cos_yaw, cos_pitch * sin_yaw, -sin_pitch}
    end
end

--Extrapolate an angle until it hits a wall
local function extrapolate_angle(index, camera, angles, limit)
    local forward = angle_forward(angles)
    local trace = {client.trace_line(index, camera[1], camera[2], camera[3], forward[1] * (8192), forward[2] * (8192), forward[3] * (8192))}

    trace[1] = trace[1] - 0.01

    return {
        camera[1] + (forward[1] * clamp(0, limit, (8192 * trace[1]))),
        camera[2] + (forward[2] * clamp(0, limit, (8192 * trace[1]))),
        camera[3] + (forward[3] * clamp(0, limit, (8192 * trace[1])))
    }, 8192 * trace[1] --Returns where it was hit, and the distance
end

--Yeeeesss...
local old_view = {0, 0}
local last_view = 0
local target_view_add = 0
local transition_int = 0
local transition_percent = 0

--ye
local old_state = ui.get(hotkey)

local override_view = function(view) --Set view angles
    if ui.get(enable) == false or lp() == nil or entity.is_alive(lp()) == false then
        return 
    end

    --State
    local state = ui.get(hotkey) and closest_to_crosshair ~= nil

    cvar.cl_draw_only_deathnotices:set_int(state and 1 or 0)

    --transition thingy
    local inc = (100/0.5)*globals.frametime()
    transition_int = clamp(0, 100, state and transition_int + inc or transition_int - inc)
    transition_percent = transition_int/100

    --Get view and eye
    local view_angles = {client.camera_angles()}
    local local_eye_position = eye_position(lp())

    --restore old view
    if old_state ~= ui.get(hotkey) then  
        if ui.get(hotkey) == false then
            client.camera_angles(unpack(old_view))
        end
        old_state = ui.get(hotkey)
    end

    --ya
    if state then
        local target_eye_position = eye_position(closest_to_crosshair)
        local yaw = normalize_yaw(calculate_angle(local_eye_position[1], local_eye_position[2], target_eye_position[1], target_eye_position[2]) + 180)

        --update old
        if view_angles[2] ~= last_view then
            target_view_add = target_view_add + normalize_yaw(view_angles[2] - last_view)
            last_view = view_angles[2]
        end

        --Yee
        local rotate_origin = extrapolate_angle(closest_to_crosshair, target_eye_position, {view_angles[1], normalize_yaw(yaw + 180 + target_view_add)}, ui.get(view_distance))
        local view_origin = {rotate_origin[1], rotate_origin[2], target_eye_position[3]}

        --smooth origin
        local transition_origin = lerp(local_eye_position, view_origin, transition_percent)

        --Apply
        view.x = transition_origin[1]
        view.y = transition_origin[2]
        view.z = transition_origin[3]
        view.yaw = normalize_yaw(yaw + target_view_add)
    else
        --Reset old
        target_view_add = 0
        old_view = view_angles
        last_view = view_angles[2]
    end
end

--Set callbacks
local set_event_callback = function(event, ...)
    local callbacks = {...}

    for i=1, #callbacks do
        client.set_event_callback(event, callbacks[i])
    end
end

set_event_callback("paint_ui", handle_gui, calculate_best)
set_event_callback("override_view", override_view)
