-- ============================================
-- ATM10 MODULAR BASE BUILDER - PC MAIN
-- ============================================
-- Programma principale per il Computer Centrale

local config = require("config")
local protocol = require("lib.protocol")

-- ============================================
-- STATO
-- ============================================

local state = {
    turtleConnected = false,
    turtleId = nil,
    turtleStatus = nil,
    lastPing = 0
}

-- ============================================
-- INIZIALIZZAZIONE
-- ============================================

local function init()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("================================")
    print(" ATM10 Modular Base Builder")
    print(" COMMAND CENTER v1.0")
    print("================================")
    print("")
    
    -- Inizializza modem
    local ok, err = protocol.init()
    if not ok then
        print("[ERROR] " .. (err or "Failed to init modem"))
        return false
    end
    
    print("[Init] Modem ready on " .. protocol.getModemSide())
    print("")
    
    return true
end

-- ============================================
-- COMUNICAZIONE TURTLE
-- ============================================

local function pingTurtle()
    print("Pinging turtle...")
    protocol.ping()
    
    -- Attendi risposta
    local status, message, data = protocol.waitForResponse(nil, 3000)
    
    if status == "success" then
        state.turtleConnected = true
        state.turtleId = data.id
        state.turtleStatus = data
        state.lastPing = os.epoch("utc")
        
        print("[OK] Turtle connected!")
        print("  ID: " .. data.id)
        print("  Label: " .. (data.label or "none"))
        print("  Fuel: " .. data.fuel)
        print("  Position: " .. string.format("X:%d Y:%d Z:%d", 
            data.position.x, data.position.y, data.position.z))
        return true
    else
        state.turtleConnected = false
        print("[ERROR] No response from turtle")
        return false
    end
end

local function sendCommand(action, params)
    if not state.turtleConnected then
        print("[ERROR] Turtle not connected. Try 'ping' first.")
        return false
    end
    
    print("Sending command: " .. action)
    protocol.sendCommand(action, params)
    
    -- Attendi risposta
    local status, message, data = protocol.waitForResponse(nil, 60000)
    
    if status then
        print("[" .. status:upper() .. "] " .. (message or ""))
        if data then
            for k, v in pairs(data) do
                if type(v) == "table" then
                    print("  " .. k .. ": " .. textutils.serialize(v))
                else
                    print("  " .. k .. ": " .. tostring(v))
                end
            end
        end
        return status == "success"
    else
        print("[ERROR] " .. (message or "No response"))
        return false
    end
end

-- ============================================
-- COMANDI INTERATTIVI
-- ============================================

local commands = {}

commands.help = function()
    print("")
    print("Available commands:")
    print("  ping        - Check turtle connection")
    print("  status      - Get turtle status")
    print("  home        - Send turtle home")
    print("  move x y z  - Move turtle to coordinates")
    print("  dig w h d   - Dig area (width height depth)")
    print("  refuel      - Refuel turtle from inventory")
    print("  abort       - Abort current operation")
    print("  clear       - Clear screen")
    print("  quit        - Exit program")
    print("")
end

commands.ping = function()
    pingTurtle()
end

commands.status = function()
    sendCommand(config.COMMANDS.STATUS, {})
end

commands.home = function()
    sendCommand(config.COMMANDS.GO_HOME, {})
end

commands.move = function(args)
    if #args < 3 then
        print("Usage: move <x> <y> <z> [facing]")
        return
    end
    
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])
    local facing = tonumber(args[4])
    
    if not x or not y or not z then
        print("Invalid coordinates")
        return
    end
    
    sendCommand(config.COMMANDS.MOVE_TO, {
        x = x, y = y, z = z, facing = facing
    })
end

commands.dig = function(args)
    local width = tonumber(args[1]) or 3
    local height = tonumber(args[2]) or 3
    local depth = tonumber(args[3]) or 3
    
    print(string.format("Digging %dx%dx%d area", width, height, depth))
    
    sendCommand(config.COMMANDS.DIG_AREA, {
        width = width,
        height = height,
        depth = depth
    })
end

commands.refuel = function()
    sendCommand(config.COMMANDS.REFUEL, {})
end

commands.abort = function()
    sendCommand(config.COMMANDS.ABORT, {})
end

commands.clear = function()
    term.clear()
    term.setCursorPos(1, 1)
end

commands.quit = function()
    return "quit"
end

-- ============================================
-- PARSER COMANDI
-- ============================================

local function parseCommand(input)
    local parts = {}
    for part in input:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then
        return nil, {}
    end
    
    local cmd = parts[1]:lower()
    local args = {}
    for i = 2, #parts do
        table.insert(args, parts[i])
    end
    
    return cmd, args
end

-- ============================================
-- LISTENER STATUS (background)
-- ============================================

local function statusListener()
    while true do
        local msg, channel = protocol.receive(1, config.CHANNEL_STATUS)
        
        if msg and msg.type == "status" then
            state.turtleStatus = msg.data
            state.turtleConnected = true
            state.lastPing = os.epoch("utc")
            
            -- Mostra status update se in corso operazione
            if msg.data.state ~= "idle" then
                local statusLine = string.format(
                    "[Turtle] %s: %s (%d%%)",
                    msg.data.state,
                    msg.data.currentTask or "",
                    msg.data.progress or 0
                )
                print(statusLine)
            end
        end
    end
end

-- ============================================
-- INPUT LOOP
-- ============================================

local function inputLoop()
    while true do
        -- Prompt
        term.setTextColor(colors.yellow)
        write("> ")
        term.setTextColor(colors.white)
        
        -- Leggi input
        local input = read()
        local cmd, args = parseCommand(input)
        
        if cmd then
            if commands[cmd] then
                local result = commands[cmd](args)
                if result == "quit" then
                    return
                end
            else
                print("Unknown command: " .. cmd)
                print("Type 'help' for available commands")
            end
        end
    end
end

-- ============================================
-- MAIN
-- ============================================

local function main()
    if not init() then
        print("Initialization failed. Press any key to exit.")
        os.pullEvent("key")
        return
    end
    
    print("Type 'help' for available commands")
    print("Type 'ping' to connect to turtle")
    print("")
    
    -- Run input loop e status listener in parallelo
    parallel.waitForAny(inputLoop, statusListener)
    
    -- Cleanup
    protocol.close()
    print("")
    print("Goodbye!")
end

-- Run
main()
