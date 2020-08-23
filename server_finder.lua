--Menu pos!!
local menu = {"Config", "Presets"}

--Add the servers you want here!!
local servers = {
    ["Lucky"] = "192.223.26.36:27015",
    ["Olof"] = "192.223.30.224:27015",
    ["Divinity"] = "74.91.122.19:27015",
    ["Deathmatch"] = "51.81.48.27:27061"
    --["name"] = "ip",
}

--Do not edit below this point unless f%*kin gay

--Collect server names for the combobox
local server_names = {}

for k, v in pairs(servers) do
    table.insert(server_names, k)
end

--Server combobox
local current_server = ui.new_combobox(menu[1], menu[2], "Server", server_names)

--Connect to server function
local function connect_to_server(name, ip)
    print("Connecting to " .. name .. " [" .. ip .. "]")
    client.exec("connect", " " .. ip)
end

--Connect to server button
local connect_button = ui.new_button(menu[1], menu[2], "Connect", function()
    for k, v in pairs(servers) do
        if k == ui.get(current_server) then
            connect_to_server(k, v)
            break
        end
    end
end)

--Console connect shit
local function console(text)
    --Check for the dot in the console command
    if string.match(text, ".connect") then
        --Get ride of .connect from the command
        local new_text = string.lower(string.sub(text, 10))
        for k, v in pairs(servers) do
            if string.lower(k) == new_text then
                connect_to_server(new_text, v)
                break
            end
        end
    end
end

client.set_event_callback("console_input", console)
