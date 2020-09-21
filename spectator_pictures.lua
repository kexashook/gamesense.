local images = require "gamesense/images" or error("Missing sapphyrus' image library!\nGet it here at: https://gamesense.pub/forums/viewtopic.php?pid=287683#p287683")

local screen = {client.screen_size()}

local function lp()
    local real_lp = entity.get_local_player()
    if entity.is_alive(real_lp) then
        return real_lp
    else
        local obvserver = entity.get_prop(real_lp, "m_hObserverTarget")
        return obvserver ~= nil and obvserver <= 64 and obvserver or nil
    end
end

local function spectators(index)
    local specs = {}

    for i=0, 64 do
        local obvserver = entity.get_prop(i, "m_hObserverTarget") 
        if obvserver == index and entity.is_alive(i) == false then
            table.insert(specs, i)
        end
    end

    return specs
end

local function paint()
    if lp() == nil or entity.is_alive(lp()) == false then
        return
    end

    --Collect spectators
    local active_spectators = spectators(lp())

    local offset = 0

    for i=1, #active_spectators do
        local index = active_spectators[i]
        local steamid3 = entity.get_steam64(index)

        --Name
        local name = entity.get_player_name(index)
        local size = {renderer.measure_text("", name)}
        renderer.text(screen[1] - size[1] - 5, 5 + offset, 255, 255, 255, 255, "", 0, name)

        --Picture
        local profile_picture = images.get_steam_avatar(steamid3 ~= 0 and steamid3 or entity.get_steam64(lp()), 0)
        profile_picture:draw(screen[1] - size[1] - 25, 4 + offset, 15, 15, 255, 255, 255, 255, true, "f")
    
        --Offset
        offset = offset + size[2] + 10
    end
end

client.set_event_callback("paint", paint)
