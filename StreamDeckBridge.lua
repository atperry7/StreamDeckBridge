_addon.name = 'StreamDeckBridge'
_addon.author = 'Anthony'
_addon.version = '1.2.0'
_addon.commands = {'sdb','streamdeckbridge'}

local socket = require('socket')
local config = require('config')

local defaults = {
    port = 19769,
    server_character = '',  -- Empty = disabled, otherwise the character name that runs the server
    focus_mode = false,     -- When true, commands are sent to the focused FFXI window via IPC
}

local settings = config.load(defaults)

local server = nil
local clients = {}

local IPC_PREFIX = 'SDB:'  -- Prefix for IPC messages to identify StreamDeckBridge commands

-- Save settings globally so all characters see the same server_character and focus_mode
local function save_global_settings()
    settings:save('all')
end

local function execute_command(command)
    windower.send_command(command)
end

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
            if settings.focus_mode then
                -- Broadcast to all Windower instances via IPC
                -- The focused instance will execute the command
                windower.send_ipc_message(IPC_PREFIX .. data)
            else
                -- Execute directly on this character (original behavior)
                execute_command(data)
            end
        elseif err == 'closed' then
            table.remove(clients, i)
        end
    end
end

local function start_server()
    if server then return end

    local sock = socket.tcp()
    if not sock then
        print('StreamDeckBridge: Failed to create socket')
        return
    end

    sock:setoption('reuseaddr', true)

    local ok, err = sock:bind('127.0.0.1', settings.port)
    if not ok then
        print('StreamDeckBridge: Failed to bind to port ' .. settings.port .. ': ' .. (err or 'unknown error'))
        sock:close()
        return
    end

    ok, err = sock:listen(5)
    if not ok then
        print('StreamDeckBridge: Failed to listen: ' .. (err or 'unknown error'))
        sock:close()
        return
    end

    sock:settimeout(0)
    server = sock

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

    local server_char = settings.server_character or ''
    local is_server_char = server_char ~= '' and server_char:lower() == player.name:lower()
    if not is_server_char then
        if server_char == '' then
            print('StreamDeckBridge: No server character set')
            print('StreamDeckBridge: Use "//sdb enable" to set this character as server')
        elseif settings.focus_mode then
            print('StreamDeckBridge: Listening for commands (focus mode enabled, server: ' .. server_char .. ')')
        else
            print('StreamDeckBridge: Server running on "' .. server_char .. '" (focus mode disabled)')
        end
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

-- IPC handler for focus mode: execute commands only if this window has focus
windower.register_event('ipc message', function(message)
    -- Only process messages with our prefix
    if message:sub(1, #IPC_PREFIX) ~= IPC_PREFIX then return end

    -- Only execute if this window has focus
    if not windower.has_focus() then return end

    -- Extract and execute the command
    local command = message:sub(#IPC_PREFIX + 1)
    execute_command(command)
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
        save_global_settings()
        print('StreamDeckBridge: Server character set to ' .. player.name)
        print('StreamDeckBridge: Reloading addon to start server...')
        windower.send_command('lua r StreamDeckBridge')
    elseif command == 'disable' then
        settings.server_character = ''
        save_global_settings()
        print('StreamDeckBridge: Server disabled')
    elseif command == 'focus' then
        settings.focus_mode = not settings.focus_mode
        save_global_settings()
        local mode_str = settings.focus_mode and 'enabled' or 'disabled'
        print('StreamDeckBridge: Focus mode ' .. mode_str)
        if settings.focus_mode then
            print('StreamDeckBridge: Commands will be sent to the focused FFXI window')
        else
            print('StreamDeckBridge: Commands will execute on the server character only')
        end
    elseif command == 'status' then
        local player = windower.ffxi.get_player()
        local char_name = player and player.name or 'Not logged in'
        local sc = settings.server_character or ''
        local server_char = sc ~= '' and sc or 'not set'
        local server_status = server and 'listening' or 'not started'
        local focus_status = settings.focus_mode and 'enabled' or 'disabled'
        local has_focus = windower.has_focus() and 'yes' or 'no'
        print('StreamDeckBridge: Current character: ' .. char_name)
        print('StreamDeckBridge: Server character: ' .. server_char)
        print('StreamDeckBridge: Port ' .. settings.port .. ', ' .. #clients .. ' client(s), server ' .. server_status)
        print('StreamDeckBridge: Focus mode: ' .. focus_status .. ' (this window has focus: ' .. has_focus .. ')')
    else
        print('StreamDeckBridge commands:')
        print('  //sdb enable   - Set THIS character as the server character')
        print('  //sdb disable  - Clear server character (disable server)')
        print('  //sdb focus    - Toggle focus mode (send commands to focused window)')
        print('  //sdb status   - Show current state')
    end
end)

windower.register_event('unload', function()
    for _, client in ipairs(clients) do
        client:close()
    end
    if server then server:close() end
end)
