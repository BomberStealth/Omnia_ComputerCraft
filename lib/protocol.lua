-- ============================================
-- REDNET PROTOCOL - Comunicazione PC <-> Turtle
-- ============================================

local config = require("config")

local protocol = {}

-- Stato modem
local modem = nil
local modemSide = nil

-- ============================================
-- INIZIALIZZAZIONE
-- ============================================

-- Trova e apri il modem
function protocol.init()
    -- Cerca modem wireless
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            local m = peripheral.wrap(side)
            if m.isWireless() then
                modem = m
                modemSide = side
                
                -- Apri canali
                modem.open(config.CHANNEL_COMMAND)
                modem.open(config.CHANNEL_RESPONSE)
                modem.open(config.CHANNEL_STATUS)
                
                if config.DEBUG then
                    print("[Protocol] Modem found on " .. side)
                end
                
                return true
            end
        end
    end
    
    -- Prova con rednet.open se disponibile
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            rednet.open(side)
            modemSide = side
            if config.DEBUG then
                print("[Protocol] Rednet opened on " .. side)
            end
            return true
        end
    end
    
    return false, "No wireless modem found"
end

-- Chiudi modem
function protocol.close()
    if modem then
        modem.close(config.CHANNEL_COMMAND)
        modem.close(config.CHANNEL_RESPONSE)
        modem.close(config.CHANNEL_STATUS)
        modem = nil
    end
    
    if modemSide then
        pcall(function() rednet.close(modemSide) end)
        modemSide = nil
    end
end

-- ============================================
-- INVIO MESSAGGI
-- ============================================

-- Crea messaggio base
local function createMessage(msgType, data)
    return {
        protocol = config.PROTOCOL,
        type = msgType,
        id = tostring(os.epoch("utc")),
        timestamp = os.epoch("utc"),
        sender = os.getComputerID(),
        data = data
    }
end

-- Invia messaggio raw
local function send(channel, message)
    if modem then
        modem.transmit(channel, config.CHANNEL_RESPONSE, message)
        return true
    else
        return false, "Modem not initialized"
    end
end

-- Invia comando (PC -> Turtle)
function protocol.sendCommand(action, params)
    local msg = createMessage("command", {
        action = action,
        params = params or {}
    })
    return send(config.CHANNEL_COMMAND, msg)
end

-- Invia risposta (Turtle -> PC)
function protocol.sendResponse(commandId, status, message, data)
    local msg = createMessage("response", {
        commandId = commandId,
        status = status,  -- "success", "error", "in_progress"
        message = message,
        result = data or {}
    })
    return send(config.CHANNEL_RESPONSE, msg)
end

-- Invia status update (Turtle -> PC)
function protocol.sendStatus(state, progress, extra)
    local msg = createMessage("status", {
        state = state,
        progress = progress or 0,
        fuel = turtle and turtle.getFuelLevel() or 0,
        position = extra and extra.position or nil,
        currentTask = extra and extra.task or nil
    })
    return send(config.CHANNEL_STATUS, msg)
end

-- ============================================
-- RICEZIONE MESSAGGI
-- ============================================

-- Attendi messaggio su un canale specifico
function protocol.receive(timeout, expectedChannel)
    local timer = nil
    if timeout then
        timer = os.startTimer(timeout)
    end
    
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            
            -- Verifica protocollo
            if type(message) == "table" and message.protocol == config.PROTOCOL then
                -- Verifica canale se specificato
                if not expectedChannel or channel == expectedChannel then
                    return message, channel, distance
                end
            end
            
        elseif event == "timer" and p1 == timer then
            return nil, "timeout"
        end
    end
end

-- Attendi comando (per Turtle)
function protocol.waitForCommand(timeout)
    local msg, channel = protocol.receive(timeout, config.CHANNEL_COMMAND)
    
    if msg and msg.type == "command" then
        return msg.data.action, msg.data.params, msg.id
    end
    
    return nil, channel  -- channel contiene "timeout" se scaduto
end

-- Attendi risposta (per PC)
function protocol.waitForResponse(commandId, timeout)
    local startTime = os.epoch("utc")
    timeout = timeout or 30000  -- 30 secondi default
    
    while (os.epoch("utc") - startTime) < timeout do
        local msg, channel = protocol.receive(1, config.CHANNEL_RESPONSE)
        
        if msg and msg.type == "response" then
            if not commandId or msg.data.commandId == commandId then
                return msg.data.status, msg.data.message, msg.data.result
            end
        end
    end
    
    return nil, "timeout"
end

-- ============================================
-- COMANDI PREDEFINITI
-- ============================================

-- Ping (verifica connessione)
function protocol.ping()
    return protocol.sendCommand(config.COMMANDS.PING, {})
end

-- Richiedi status
function protocol.requestStatus()
    return protocol.sendCommand(config.COMMANDS.STATUS, {})
end

-- Comando go home
function protocol.commandGoHome()
    return protocol.sendCommand(config.COMMANDS.GO_HOME, {})
end

-- Comando move to
function protocol.commandMoveTo(x, y, z, facing)
    return protocol.sendCommand(config.COMMANDS.MOVE_TO, {
        x = x, y = y, z = z, facing = facing
    })
end

-- Comando build room
function protocol.commandBuildRoom(blueprint, position, floor, materials)
    return protocol.sendCommand(config.COMMANDS.BUILD_ROOM, {
        blueprint = blueprint,
        position = position,
        floor = floor,
        materials = materials
    })
end

-- Comando abort
function protocol.commandAbort()
    return protocol.sendCommand(config.COMMANDS.ABORT, {})
end

-- ============================================
-- UTILITÀ
-- ============================================

function protocol.isConnected()
    return modem ~= nil or modemSide ~= nil
end

function protocol.getModemSide()
    return modemSide
end

return protocol
