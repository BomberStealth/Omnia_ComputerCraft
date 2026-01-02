-- ============================================
-- BUILDER - Funzioni di costruzione
-- ============================================

local config = require("config")
local position = require("lib.position")
local movement = require("lib.movement")
local inventory = require("lib.inventory")

local builder = {}

-- Stato costruzione
local buildState = {
    abortRequested = false,
    blocksPlaced = 0,
    blocksDug = 0,
    progress = 0
}

-- ============================================
-- UTILITÀ BASE
-- ============================================

-- Piazza blocco davanti
function builder.place()
    if turtle.detect() then
        turtle.dig()
    end
    return turtle.place()
end

-- Piazza blocco sopra
function builder.placeUp()
    if turtle.detectUp() then
        turtle.digUp()
    end
    return turtle.placeUp()
end

-- Piazza blocco sotto
function builder.placeDown()
    if turtle.detectDown() then
        turtle.digDown()
    end
    return turtle.placeDown()
end

-- Piazza blocco specifico
function builder.placeBlock(itemName, direction)
    direction = direction or "front"
    
    -- Seleziona il blocco
    if not inventory.select(itemName) then
        return false, "Item not found: " .. itemName
    end
    
    -- Piazza
    if direction == "up" then
        return builder.placeUp()
    elseif direction == "down" then
        return builder.placeDown()
    else
        return builder.place()
    end
end

-- ============================================
-- COSTRUZIONE LINEE
-- ============================================

-- Costruisci linea orizzontale (piazzando sotto mentre si muove)
function builder.lineFloor(length, itemName)
    local placed = 0
    
    for i = 1, length do
        if buildState.abortRequested then
            return false, "Aborted", placed
        end
        
        -- Seleziona materiale
        if itemName then
            if not inventory.select(itemName) then
                return false, "Out of materials", placed
            end
        end
        
        -- Piazza sotto
        if builder.placeDown() then
            placed = placed + 1
        end
        
        -- Muovi avanti (tranne ultimo blocco)
        if i < length then
            local ok, err = movement.forward(true)
            if not ok then
                return false, err, placed
            end
        end
    end
    
    return true, nil, placed
end

-- Costruisci linea verticale (muro)
function builder.lineWall(height, itemName)
    local placed = 0
    
    for i = 1, height do
        if buildState.abortRequested then
            return false, "Aborted", placed
        end
        
        if itemName then
            if not inventory.select(itemName) then
                return false, "Out of materials", placed
            end
        end
        
        if builder.place() then
            placed = placed + 1
        end
        
        -- Muovi su (tranne ultimo blocco)
        if i < height then
            local ok, err = movement.up(true)
            if not ok then
                return false, err, placed
            end
        end
    end
    
    return true, nil, placed
end

-- ============================================
-- COSTRUZIONE SUPERFICI
-- ============================================

-- Costruisci pavimento (rettangolo orizzontale)
function builder.floor(width, depth, itemName)
    local placed = 0
    local reverse = false
    
    for z = 1, depth do
        if buildState.abortRequested then
            return false, "Aborted", placed
        end
        
        -- Costruisci riga
        for x = 1, width do
            if buildState.abortRequested then break end
            
            if itemName then
                if not inventory.select(itemName) then
                    return false, "Out of materials", placed
                end
            end
            
            if builder.placeDown() then
                placed = placed + 1
            end
            
            -- Muovi (tranne ultimo della riga)
            if x < width then
                movement.forward(true)
            end
        end
        
        -- Gira per prossima riga (tranne ultima)
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
    
    return true, nil, placed
end

-- Costruisci soffitto (come floor ma piazzando sopra)
function builder.ceiling(width, depth, itemName)
    local placed = 0
    local reverse = false
    
    for z = 1, depth do
        if buildState.abortRequested then
            return false, "Aborted", placed
        end
        
        for x = 1, width do
            if buildState.abortRequested then break end
            
            if itemName then
                if not inventory.select(itemName) then
                    return false, "Out of materials", placed
                end
            end
            
            if builder.placeUp() then
                placed = placed + 1
            end
            
            if x < width then
                movement.forward(true)
            end
        end
        
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
    
    return true, nil, placed
end

-- ============================================
-- COSTRUZIONE MURI
-- ============================================

-- Costruisci muro singolo (verticale)
function builder.wall(width, height, itemName)
    local placed = 0
    local goingUp = true
    
    for x = 1, width do
        if buildState.abortRequested then
            return false, "Aborted", placed
        end
        
        -- Costruisci colonna
        for y = 1, height do
            if buildState.abortRequested then break end
            
            if itemName then
                if not inventory.select(itemName) then
                    return false, "Out of materials", placed
                end
            end
            
            if builder.place() then
                placed = placed + 1
            end
            
            -- Muovi verticalmente (tranne ultimo)
            if y < height then
                if goingUp then
                    movement.up(true)
                else
                    movement.down(true)
                end
            end
        end
        
        -- Muovi alla prossima colonna (tranne ultima)
        if x < width then
            movement.turnRight()
            movement.forward(true)
            movement.turnLeft()
            goingUp = not goingUp
        end
    end
    
    return true, nil, placed
end

-- Costruisci perimetro (4 muri)
function builder.perimeter(width, depth, height, itemName)
    local placed = 0
    local startFacing = position.getFacing()
    
    -- 4 lati
    for side = 1, 4 do
        if buildState.abortRequested then
            return false, "Aborted", placed
        end
        
        local length = (side % 2 == 1) and width or depth
        
        -- Costruisci muro
        local ok, err, p = builder.wall(length, height, itemName)
        placed = placed + p
        
        if not ok then
            return false, err, placed
        end
        
        -- Gira per prossimo lato (tranne ultimo)
        if side < 4 then
            movement.turnRight()
        end
    end
    
    -- Torna a facing iniziale
    movement.face(startFacing)
    
    return true, nil, placed
end

-- ============================================
-- SCAVO
-- ============================================

-- Scava area (volume)
function builder.digArea(width, height, depth)
    local dug = 0
    
    for y = 1, height do
        if buildState.abortRequested then
            return false, "Aborted", dug
        end
        
        -- Scava layer
        local reverse = false
        for z = 1, depth do
            if buildState.abortRequested then break end
            
            for x = 1, width do
                if buildState.abortRequested then break end
                
                -- Scava davanti
                if turtle.detect() then
                    if turtle.dig() then
                        dug = dug + 1
                    end
                end
                
                -- Muovi (tranne ultimo)
                if x < width then
                    movement.forward(true)
                end
            end
            
            -- Gira per prossima riga
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
        
        -- Vai al prossimo layer (su)
        if y < height then
            movement.up(true)
            movement.turnAround()
        end
    end
    
    return true, nil, dug
end

-- Scava tunnel
function builder.digTunnel(length, width, height)
    local dug = 0
    
    for l = 1, length do
        if buildState.abortRequested then
            return false, "Aborted", dug
        end
        
        -- Scava sezione
        local startY = position.getY()
        
        for h = 1, height do
            for w = 1, width do
                if turtle.detect() then
                    if turtle.dig() then
                        dug = dug + 1
                    end
                end
                
                if w < width then
                    movement.turnRight()
                    movement.forward(true)
                    movement.turnLeft()
                end
            end
            
            -- Torna all'inizio della riga
            if width > 1 then
                movement.turnLeft()
                for i = 1, width - 1 do
                    movement.forward(false)
                end
                movement.turnRight()
            end
            
            if h < height then
                movement.up(true)
            end
        end
        
        -- Torna giù
        movement.goToY(startY, false)
        
        -- Avanza
        if l < length then
            movement.forward(true)
        end
    end
    
    return true, nil, dug
end

-- ============================================
-- COSTRUZIONE STANZA COMPLETA
-- ============================================

-- Costruisci stanza base (scatola vuota)
function builder.room(innerWidth, innerDepth, innerHeight, materials)
    materials = materials or {}
    local wallMat = materials.wall or "minecraft:stone_bricks"
    local floorMat = materials.floor or "minecraft:polished_deepslate"
    local ceilingMat = materials.ceiling or "minecraft:glass"
    
    local totalBlocks = 0
    local ok, err, placed
    
    -- Dimensioni esterne
    local outerWidth = innerWidth + 2
    local outerDepth = innerDepth + 2
    local outerHeight = innerHeight + 2
    
    print("Building room " .. innerWidth .. "x" .. innerDepth .. "x" .. innerHeight)
    
    -- 1. Pavimento
    print("  Building floor...")
    ok, err, placed = builder.floor(outerWidth, outerDepth, floorMat)
    totalBlocks = totalBlocks + placed
    if not ok then return false, err, totalBlocks end
    
    -- Torna all'angolo e sali
    -- (assumendo siamo nell'angolo opposto dopo il floor)
    movement.up(true)
    
    -- 2. Muri (perimetro per ogni livello)
    print("  Building walls...")
    for h = 1, innerHeight do
        ok, err, placed = builder.perimeter(outerWidth, outerDepth, 1, wallMat)
        totalBlocks = totalBlocks + placed
        if not ok then return false, err, totalBlocks end
        
        if h < innerHeight then
            movement.up(true)
        end
    end
    
    -- 3. Soffitto
    print("  Building ceiling...")
    movement.up(true)
    ok, err, placed = builder.ceiling(outerWidth, outerDepth, ceilingMat)
    totalBlocks = totalBlocks + placed
    if not ok then return false, err, totalBlocks end
    
    print("Room complete! Blocks placed: " .. totalBlocks)
    return true, nil, totalBlocks
end

-- ============================================
-- COSTRUZIONE BUS
-- ============================================

-- Costruisci sezione bus
function builder.bus(length, materials)
    materials = materials or {}
    local wallMat = materials.wall or "minecraft:stone_bricks"
    local floorMat = materials.floor or "minecraft:glass"
    
    local totalBlocks = 0
    local busWidth = config.DIMENSIONS.BUS_WIDTH
    local busHeight = config.DIMENSIONS.BUS_HEIGHT
    
    print("Building bus section, length: " .. length)
    
    -- Costruisci tunnel con muri
    for l = 1, length do
        if buildState.abortRequested then
            return false, "Aborted", totalBlocks
        end
        
        -- Pavimento (vetro)
        inventory.select(floorMat)
        builder.placeDown()
        totalBlocks = totalBlocks + 1
        
        -- Muri laterali
        movement.turnLeft()
        for h = 1, busHeight do
            inventory.select(wallMat)
            builder.place()
            totalBlocks = totalBlocks + 1
            if h < busHeight then movement.up(true) end
        end
        
        -- Soffitto
        builder.placeUp()
        totalBlocks = totalBlocks + 1
        
        -- Altro lato
        movement.turnAround()
        for i = 1, busWidth - 1 do
            movement.forward(true)
        end
        
        for h = 1, busHeight do
            inventory.select(wallMat)
            builder.place()
            totalBlocks = totalBlocks + 1
            if h > 1 then movement.down(true) end
        end
        
        -- Torna al centro e avanza
        movement.turnLeft()
        for i = 1, (busWidth - 1) / 2 do
            movement.forward(true)
        end
        
        if l < length then
            movement.forward(true)
        end
    end
    
    return true, nil, totalBlocks
end

-- ============================================
-- CONTROLLO COSTRUZIONE
-- ============================================

function builder.abort()
    buildState.abortRequested = true
end

function builder.resetAbort()
    buildState.abortRequested = false
end

function builder.getState()
    return {
        abortRequested = buildState.abortRequested,
        blocksPlaced = buildState.blocksPlaced,
        blocksDug = buildState.blocksDug,
        progress = buildState.progress
    }
end

function builder.resetState()
    buildState.abortRequested = false
    buildState.blocksPlaced = 0
    buildState.blocksDug = 0
    buildState.progress = 0
end

return builder
