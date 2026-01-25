_addon.name = 'StreamDeckBridge'
_addon.author = 'Anthony'
_addon.version = '1.1.0'
_addon.commands = {'sdb','streamdeckbridge'}

local socket = require('socket')
local config = require('config')

local defaults = {
    port = 19769,
    server_character = '',  -- Empty = disabled, otherwise the character name that runs the server
}

local settings = config.load(defaults)

local server = nil
local clients = {}

local function poll()
    if not server then return end

    local client = server:accept()
    if client then
        client:settimeout(0)
        table.insert(clients, client)
    end

    for i = #clients, 1, -1 do
        local data, err = clients[i]:receive('*l')
        if data then
            windower.send_command(data)
        elseif err == 'closed' then
            table.remove(clients, i)
        end
    end
end

local function start_server()
    if server then return end

    server = socket.tcp()
    server:setoption('reuseaddr', true)
    server:bind('127.0.0.1', settings.port)
    server:listen(5)
    server:settimeout(0)

    coroutine.schedule(function()
        while server do
            poll()
            coroutine.sleep(0.1)
        end
    end, 0)

    print('StreamDeckBridge listening on port ' .. settings.port)
end

local function migrate_settings()
    -- Migrate from old main_character to server_character
    if settings.main_character ~= nil and settings.main_character ~= '' then
        settings.server_character = settings.main_character
        settings.main_character = nil
        config.save(settings)
        print('StreamDeckBridge: Migrated server_character = ' .. settings.server_character)
    elseif settings.main_character == '' then
        settings.main_character = nil
        config.save(settings)
    end
    -- Clean up old per-character enabled flags
    if settings.enabled ~= nil then
        settings.enabled = nil
        config.save(settings)
    end
end

local function check_and_start()
    local player = windower.ffxi.get_player()
    if not player then return end

    migrate_settings()

    local is_server_char = settings.server_character:lower() == player.name:lower()
    if not is_server_char then
        print('StreamDeckBridge: Server character is "' .. (settings.server_character ~= '' and settings.server_character or 'not set') .. '"')
        print('StreamDeckBridge: Use "//sdb enable" to set this character as server')
        return
    end

    start_server()
end

windower.register_event('load', function()
    -- If already logged in, check and start
    local player = windower.ffxi.get_player()
    if player then
        check_and_start()
    end
end)

windower.register_event('login', function()
    check_and_start()
end)

windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'status'

    if command == 'enable' then
        local player = windower.ffxi.get_player()
        if not player then
            print('StreamDeckBridge: Must be logged in to enable')
            return
        end
        settings.server_character = player.name
        config.save(settings)
        print('StreamDeckBridge: Server character set to ' .. player.name)
        print('StreamDeckBridge: Reloading addon to start server...')
        windower.send_command('lua r StreamDeckBridge')
    elseif command == 'disable' then
        settings.server_character = ''
        config.save(settings)
        print('StreamDeckBridge: Server disabled')
    elseif command == 'status' then
        local player = windower.ffxi.get_player()
        local char_name = player and player.name or 'Not logged in'
        local server_char = settings.server_character ~= '' and settings.server_character or 'not set'
        local server_status = server and 'listening' or 'not started'
        print('StreamDeckBridge: Current character: ' .. char_name)
        print('StreamDeckBridge: Server character: ' .. server_char)
        print('StreamDeckBridge: Port ' .. settings.port .. ', ' .. #clients .. ' client(s), server ' .. server_status)
    else
        print('StreamDeckBridge commands:')
        print('  //sdb enable   - Set THIS character as the server character')
        print('  //sdb disable  - Clear server character (disable server)')
        print('  //sdb status   - Show current state')
    end
end)

windower.register_event('unload', function()
    for _, client in ipairs(clients) do
        client:close()
    end
    if server then server:close() end
end)
