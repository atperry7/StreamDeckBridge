_addon.name = 'StreamDeckBridge'
_addon.author = 'Anthony'
_addon.version = '1.4.1'
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
local buffers = {}  -- Per-client partial-line buffers (receive('*l') discards partials on timeout)

local IPC_PREFIX = 'SDB:'  -- Prefix for focus-mode IPC messages
local IPC_TARGET_PREFIX = 'SDBT:'  -- Prefix for targeted IPC messages

-- Save settings globally so all characters see the same server_character
local function save_global_settings()
    settings:save('all')
end

local function execute_command(command)
    windower.send_command(command)
end

local function route_command(target, command)
    local player = windower.ffxi.get_player()
    local player_name = player and player.name:lower() or ''

    if target == '@main' or target == player_name then
        execute_command(command)
    elseif target == '@focus' then
        windower.send_ipc_message(IPC_PREFIX .. command)
        if windower.has_focus() then
            execute_command(command)
        end
    elseif target == '@all' then
        execute_command(command)
        windower.send_ipc_message(IPC_TARGET_PREFIX .. '@all:' .. command)
    else
        -- Specific character name — send via IPC to that character
        windower.send_ipc_message(IPC_TARGET_PREFIX .. target .. ':' .. command)
    end
end

local function handle_line(data)
    local pipe_pos = data:find('|', 1, true)
    if pipe_pos then
        local target = data:sub(1, pipe_pos - 1):lower():match('^%s*(.-)%s*$')
        local command = data:sub(pipe_pos + 1)
        route_command(target, command)
    else
        -- Legacy: no target prefix → execute on server
        execute_command(data)
    end
end

local function poll()
    if not server then return end

    while true do
        local client = server:accept()
        if not client then break end
        client:settimeout(0)
        table.insert(clients, client)
        buffers[client] = ''
    end

    for i = #clients, 1, -1 do
        local client = clients[i]
        while true do
            local data, err, partial = client:receive('*l')
            if data then
                handle_line(buffers[client] .. data)
                buffers[client] = ''
            elseif err == 'timeout' then
                if partial and partial ~= '' then
                    buffers[client] = buffers[client] .. partial
                end
                break
            else
                client:close()
                buffers[client] = nil
                table.remove(clients, i)
                break
            end
        end
    end
end

windower.register_event('prerender', poll)

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

    print('StreamDeckBridge listening on port ' .. settings.port)
end

local function stop_server()
    for _, client in ipairs(clients) do
        client:close()
    end
    clients = {}
    buffers = {}
    if server then
        server:close()
        server = nil
    end
end

local function check_and_start()
    local player = windower.ffxi.get_player()
    if not player then return end

    local server_char = settings.server_character or ''
    local is_server_char = server_char ~= '' and server_char:lower() == player.name:lower()
    if not is_server_char then
        -- Switching characters on this instance must not leave a previous
        -- character's server running under the wrong name
        stop_server()
        if server_char == '' then
            print('StreamDeckBridge: No server character set')
            print('StreamDeckBridge: Use "//sdb enable" to set this character as server')
        else
            print('StreamDeckBridge: Listening for IPC commands (server: ' .. server_char .. ')')
        end
        return
    end

    start_server()
end

windower.register_event('load', 'login', check_and_start)

-- IPC handler for both focus-mode and targeted messages
windower.register_event('ipc message', function(message)
    -- Targeted messages: SDBT:<target>:<command>
    if message:sub(1, #IPC_TARGET_PREFIX) == IPC_TARGET_PREFIX then
        local rest = message:sub(#IPC_TARGET_PREFIX + 1)
        local colon_pos = rest:find(':')
        if colon_pos then
            local target = rest:sub(1, colon_pos - 1):lower()
            local command = rest:sub(colon_pos + 1)
            local player = windower.ffxi.get_player()
            if player then
                local name = player.name:lower()
                if target == name or target == '@all' then
                    execute_command(command)
                end
            end
        end
        return
    end

    -- Focus messages: SDB:<command> (execute if focused)
    -- Server character already handles focus commands in route_command, skip to avoid double-execution
    if message:sub(1, #IPC_PREFIX) ~= IPC_PREFIX then return end
    if server then return end
    if not windower.has_focus() then return end
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
        start_server()
    elseif command == 'disable' then
        settings.server_character = ''
        save_global_settings()
        stop_server()
        print('StreamDeckBridge: Server disabled')
    elseif command == 'status' then
        local player = windower.ffxi.get_player()
        local char_name = player and player.name or 'Not logged in'
        local sc = settings.server_character or ''
        local server_char = sc ~= '' and sc or 'not set'
        local server_status = server and 'listening' or 'not started'
        local has_focus = windower.has_focus() and 'yes' or 'no'
        print('StreamDeckBridge: Current character: ' .. char_name)
        print('StreamDeckBridge: Server character: ' .. server_char)
        print('StreamDeckBridge: Port ' .. settings.port .. ', ' .. #clients .. ' client(s), server ' .. server_status)
        print('StreamDeckBridge: Window has focus: ' .. has_focus)
    else
        print('StreamDeckBridge commands:')
        print('  //sdb enable   - Set THIS character as the server character')
        print('  //sdb disable  - Clear server character (disable server)')
        print('  //sdb status   - Show current state')
    end
end)

windower.register_event('unload', stop_server)
