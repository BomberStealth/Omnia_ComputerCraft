-- ============================================
-- ATM10 MODULAR BASE BUILDER - TURTLE MAIN
-- ============================================
-- Programma principale per la Turtle Builder

local config = require("config")
local position = require("lib.position")
local movement = require("lib.movement")
local protocol = require("lib.protocol")

-- ============================================
-- STATO TURTLE
-- ============================================

local state = {
    current = config.STATE.IDLE,
    currentTask = nil,
    currentCommandId = nil,
    progress = 0,
    abortRequested = false
}

-- ============================================
-- INIZIALIZZAZIONE
-- ============================================

local function init()
    print("================================")
    print(" ATM10 Modular Base Builder")
    print(" TURTLE v1.0")
    print("================================")
    print("")
    
    -- Crea cartella data se non esiste
    if not fs.exists("data") then
        fs.makeDir("data")
    end
    
    -- Carica posizione salvata o imposta HOME
    if not position.load() then
        print("[Init] Setting HOME position")
        position.setHome()
        position.save()
    end
    
    print("[Init] Position: " .. position.toString())
    
    -- Inizializza comunicazione
    local ok, err = protocol.init()
    if not ok then
        print("[ERROR] " .. (err or "Failed to init modem"))
        print("Continuing in offline mode...")
    else
        print("[Init] Modem ready on " .. protocol.getModemSide())
    end
    
    -- Check fuel
    local fuel = movement.getFuel()
    if fuel ~= "unlimited" then
        print("[Init] Fuel: " .. fuel)
        if fuel < config.FUEL_WARNING then
            print("[WARNING] Low fuel!")
        end
    end
    
    print("")
    print("Ready. Waiting for commands...")
    print("")
end

-- ============================================
-- HANDLERS COMANDI
-- ============================================

local handlers = {}

-- PING
handlers[config.COMMANDS.PING] = function(params, cmdId)
    protocol.sendResponse(cmdId, "success", "pong", {
        id = os.getComputerID(),
        label = os.getComputerLabel() or "Turtle",
        fuel = movement.getFuel(),
        position = position.get()
    })
end

-- STATUS
handlers[config.COMMANDS.STATUS] = function(params, cmdId)
    protocol.sendResponse(cmdId, "success", "status", {
        state = state.current,
        task = state.currentTask,
        progress = state.progress,
        fuel = movement.getFuel(),
        position = position.get()
    })
end

-- GO HOME
handlers[config.COMMANDS.GO_HOME] = function(params, cmdId)
    state.current = config.STATE.RETURNING
    state.currentTask = "Returning home"
    state.currentCommandId = cmdId
    
    protocol.sendResponse(cmdId, "in_progress", "Going home...")
    
    local ok, err = movement.goHome(true)
    
    if ok then
        state.current = config.STATE.IDLE
        state.currentTask = nil
        protocol.sendResponse(cmdId, "success", "Arrived home", {
            position = position.get()
        })
    else
        state.current = config.STATE.ERROR
        protocol.sendResponse(cmdId, "error", err or "Failed to go home")
    end
end

-- MOVE TO
handlers[config.COMMANDS.MOVE_TO] = function(params, cmdId)
    local x = params.x
    local y = params.y
    local z = params.z
    local facing = params.facing
    
    if not x or not y or not z then
        protocol.sendResponse(cmdId, "error", "Missing coordinates")
        return
    end
    
    state.current = config.STATE.MOVING
    state.currentTask = string.format("Moving to %d,%d,%d", x, y, z)
    state.currentCommandId = cmdId
    
    protocol.sendResponse(cmdId, "in_progress", "Moving...")
    
    local ok, err = movement.goTo(x, y, z, true, facing)
    
    if ok then
        state.current = config.STATE.IDLE
        state.currentTask = nil
        protocol.sendResponse(cmdId, "success", "Arrived", {
            position = position.get()
        })
    else
        state.current = config.STATE.ERROR
        protocol.sendResponse(cmdId, "error", err or "Failed to move")
    end
end

-- REFUEL
handlers[config.COMMANDS.REFUEL] = function(params, cmdId)
    state.current = config.STATE.REFUELING
    state.currentTask = "Refueling"
    
    -- Cerca fuel nell'inventario
    local refueled = 0
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then  -- Test se è fuel
            local count = turtle.getItemCount(slot)
            if turtle.refuel(count) then
                refueled = refueled + count
            end
        end
    end
    
    turtle.select(1)
    state.current = config.STATE.IDLE
    state.currentTask = nil
    
    if refueled > 0 then
        protocol.sendResponse(cmdId, "success", "Refueled", {
            itemsUsed = refueled,
            currentFuel = movement.getFuel()
        })
    else
        protocol.sendResponse(cmdId, "error", "No fuel found in inventory")
    end
end

-- ABORT
handlers[config.COMMANDS.ABORT] = function(params, cmdId)
    state.abortRequested = true
    state.current = config.STATE.IDLE
    state.currentTask = nil
    protocol.sendResponse(cmdId, "success", "Aborted")
end

-- DIG AREA (scava un'area)
handlers[config.COMMANDS.DIG_AREA] = function(params, cmdId)
    local width = params.width or 3
    local height = params.height or 3
    local depth = params.depth or 3
    
    state.current = config.STATE.DIGGING
    state.currentTask = string.format("Digging %dx%dx%d", width, height, depth)
    state.currentCommandId = cmdId
    state.progress = 0
    state.abortRequested = false
    
    protocol.sendResponse(cmdId, "in_progress", "Digging area...")
    
    local totalBlocks = width * height * depth
    local blocksDug = 0
    
    -- Scava layer per layer
    for y = 1, height do
        if state.abortRequested then break end
        
        -- Muovi su se necessario
        if y > 1 then
            movement.up(true)
        end
        
        -- Scava il layer corrente (serpentina)
        local reverse = false
        for z = 1, depth do
            if state.abortRequested then break end
            
            for x = 1, width do
                if state.abortRequested then break end
                
                -- Scava davanti
                turtle.dig()
                blocksDug = blocksDug + 1
                
                -- Muovi avanti (tranne ultimo blocco della riga)
                if x < width then
                    movement.forward(true)
                end
                
                -- Update progress
                state.progress = math.floor((blocksDug / totalBlocks) * 100)
            end
            
            -- Gira per la prossima riga (tranne ultima)
            if z < depth then
                if reverse then
                    movement.turnLeft()
                    movement.forward(true)
                    movement.turnLeft()
                else
                    movement.turnRight()
                    movement.forward(true)
                    movement.turnRight()
                end
                reverse = not reverse
            end
        end
    end
    
    state.current = config.STATE.IDLE
    state.currentTask = nil
    
    if state.abortRequested then
        protocol.sendResponse(cmdId, "error", "Aborted by user", {
            blocksDug = blocksDug
        })
    else
        protocol.sendResponse(cmdId, "success", "Dig complete", {
            blocksDug = blocksDug,
            position = position.get()
        })
    end
end

-- ============================================
-- COMMAND HANDLER DEFAULT
-- ============================================

local function handleCommand(action, params, cmdId)
    print(string.format("[CMD] %s (id: %s)", action, cmdId or "?"))
    
    local handler = handlers[action]
    if handler then
        handler(params, cmdId)
    else
        print("[ERROR] Unknown command: " .. action)
        protocol.sendResponse(cmdId, "error", "Unknown command: " .. action)
    end
end

-- ============================================
-- STATUS BROADCAST
-- ============================================

local function broadcastStatus()
    protocol.sendStatus(state.current, state.progress, {
        position = position.get(),
        task = state.currentTask
    })
end

-- ============================================
-- MAIN LOOP
-- ============================================

local function mainLoop()
    local statusTimer = os.startTimer(5)  -- Broadcast status ogni 5 secondi
    
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            
            -- Verifica messaggio valido
            if type(message) == "table" and 
               message.protocol == config.PROTOCOL and
               message.type == "command" then
                
                local action = message.data.action
                local params = message.data.params
                local cmdId = message.id
                
                handleCommand(action, params, cmdId)
            end
            
        elseif event == "timer" and p1 == statusTimer then
            -- Broadcast status periodico
            if protocol.isConnected() then
                broadcastStatus()
            end
            statusTimer = os.startTimer(5)
            
        elseif event == "key" then
            local key = p1
            
            -- ESC per uscire
            if key == keys.q then
                print("Shutting down...")
                break
            end
            
            -- Comandi manuali per debug
            if key == keys.h then
                print("Going home...")
                handleCommand(config.COMMANDS.GO_HOME, {}, "manual")
            elseif key == keys.s then
                print("Status: " .. position.toString())
                print("State: " .. state.current)
                print("Fuel: " .. movement.getFuel())
            elseif key == keys.p then
                print("Sending ping...")
                protocol.ping()
            end
        end
    end
end

-- ============================================
-- ENTRY POINT
-- ============================================

local function main()
    init()
    
    -- Mostra help
    print("Keys: [H]ome [S]tatus [P]ing [Q]uit")
    print("")
    
    -- Run main loop
    local ok, err = pcall(mainLoop)
    
    if not ok then
        print("[ERROR] " .. tostring(err))
    end
    
    -- Cleanup
    protocol.close()
    print("Goodbye!")
end

-- Run
main()
