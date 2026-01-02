-- ============================================
-- MOVEMENT - Movimento turtle con tracking
-- ============================================

local config = require("config")
local position = require("lib.position")

local movement = {}

-- ============================================
-- MOVIMENTO BASE CON TRACKING
-- ============================================

-- Muovi avanti (scava se bloccato)
function movement.forward(dig)
    if dig == nil then dig = true end
    
    -- Se bloccato, scava
    if turtle.detect() and dig then
        if not turtle.dig() then
            return false, "Cannot dig forward"
        end
    end
    
    -- Prova a muovere
    local tries = 3
    while tries > 0 do
        if turtle.forward() then
            position.forward()
            position.save()
            return true
        end
        
        -- Forse c'è un mob o sabbia che cade
        if dig and turtle.detect() then
            turtle.dig()
        end
        
        -- Attacca se c'è qualcosa
        turtle.attack()
        
        tries = tries - 1
        sleep(0.2)
    end
    
    return false, "Cannot move forward"
end

-- Muovi indietro
function movement.back()
    if turtle.back() then
        position.back()
        position.save()
        return true
    end
    return false, "Cannot move back"
end

-- Muovi su (scava se bloccato)
function movement.up(dig)
    if dig == nil then dig = true end
    
    if turtle.detectUp() and dig then
        if not turtle.digUp() then
            return false, "Cannot dig up"
        end
    end
    
    local tries = 3
    while tries > 0 do
        if turtle.up() then
            position.up()
            position.save()
            return true
        end
        
        if dig and turtle.detectUp() then
            turtle.digUp()
        end
        
        turtle.attackUp()
        
        tries = tries - 1
        sleep(0.2)
    end
    
    return false, "Cannot move up"
end

-- Muovi giù (scava se bloccato)
function movement.down(dig)
    if dig == nil then dig = true end
    
    if turtle.detectDown() and dig then
        if not turtle.digDown() then
            return false, "Cannot dig down"
        end
    end
    
    local tries = 3
    while tries > 0 do
        if turtle.down() then
            position.down()
            position.save()
            return true
        end
        
        if dig and turtle.detectDown() then
            turtle.digDown()
        end
        
        turtle.attackDown()
        
        tries = tries - 1
        sleep(0.2)
    end
    
    return false, "Cannot move down"
end

-- Gira a sinistra
function movement.turnLeft()
    if turtle.turnLeft() then
        position.turnLeft()
        position.save()
        return true
    end
    return false
end

-- Gira a destra
function movement.turnRight()
    if turtle.turnRight() then
        position.turnRight()
        position.save()
        return true
    end
    return false
end

-- ============================================
-- ROTAZIONE
-- ============================================

-- Gira verso una direzione specifica
function movement.face(targetFacing)
    local currentFacing = position.getFacing()
    
    if currentFacing == targetFacing then
        return true
    end
    
    -- Calcola la rotazione più breve
    local diff = (targetFacing - currentFacing) % 4
    
    if diff == 1 then
        return movement.turnRight()
    elseif diff == 2 then
        movement.turnRight()
        return movement.turnRight()
    elseif diff == 3 then
        return movement.turnLeft()
    end
    
    return true
end

-- Gira di 180 gradi
function movement.turnAround()
    movement.turnRight()
    return movement.turnRight()
end

-- ============================================
-- MOVIMENTO VERSO COORDINATE
-- ============================================

-- Muovi a una coordinata Y specifica
function movement.goToY(targetY, dig)
    local currentY = position.getY()
    
    while currentY < targetY do
        local ok, err = movement.up(dig)
        if not ok then return false, err end
        currentY = position.getY()
    end
    
    while currentY > targetY do
        local ok, err = movement.down(dig)
        if not ok then return false, err end
        currentY = position.getY()
    end
    
    return true
end

-- Muovi a una coordinata X specifica
function movement.goToX(targetX, dig)
    local currentX = position.getX()
    
    if currentX < targetX then
        movement.face(config.EAST)
        while currentX < targetX do
            local ok, err = movement.forward(dig)
            if not ok then return false, err end
            currentX = position.getX()
        end
    elseif currentX > targetX then
        movement.face(config.WEST)
        while currentX > targetX do
            local ok, err = movement.forward(dig)
            if not ok then return false, err end
            currentX = position.getX()
        end
    end
    
    return true
end

-- Muovi a una coordinata Z specifica
function movement.goToZ(targetZ, dig)
    local currentZ = position.getZ()
    
    if currentZ < targetZ then
        movement.face(config.SOUTH)
        while currentZ < targetZ do
            local ok, err = movement.forward(dig)
            if not ok then return false, err end
            currentZ = position.getZ()
        end
    elseif currentZ > targetZ then
        movement.face(config.NORTH)
        while currentZ > targetZ do
            local ok, err = movement.forward(dig)
            if not ok then return false, err end
            currentZ = position.getZ()
        end
    end
    
    return true
end

-- Muovi a coordinate XYZ (prima Y, poi X, poi Z)
function movement.goTo(targetX, targetY, targetZ, dig, finalFacing)
    if dig == nil then dig = true end
    
    local ok, err
    
    -- Prima muovi in Y
    ok, err = movement.goToY(targetY, dig)
    if not ok then return false, err end
    
    -- Poi muovi in X
    ok, err = movement.goToX(targetX, dig)
    if not ok then return false, err end
    
    -- Poi muovi in Z
    ok, err = movement.goToZ(targetZ, dig)
    if not ok then return false, err end
    
    -- Facing finale se specificato
    if finalFacing then
        movement.face(finalFacing)
    end
    
    return true
end

-- Torna a HOME
function movement.goHome(dig)
    return movement.goTo(
        config.HOME.x,
        config.HOME.y,
        config.HOME.z,
        dig,
        config.HOME.facing
    )
end

-- ============================================
-- UTILITÀ
-- ============================================

-- Muovi avanti di N blocchi
function movement.forwardN(n, dig)
    for i = 1, n do
        local ok, err = movement.forward(dig)
        if not ok then return false, err, i-1 end
    end
    return true
end

-- Muovi su di N blocchi
function movement.upN(n, dig)
    for i = 1, n do
        local ok, err = movement.up(dig)
        if not ok then return false, err, i-1 end
    end
    return true
end

-- Muovi giù di N blocchi
function movement.downN(n, dig)
    for i = 1, n do
        local ok, err = movement.down(dig)
        if not ok then return false, err, i-1 end
    end
    return true
end

-- ============================================
-- FUEL CHECK
-- ============================================

function movement.checkFuel(requiredMoves)
    local fuel = turtle.getFuelLevel()
    
    if fuel == "unlimited" then
        return true
    end
    
    if fuel < (requiredMoves or config.MIN_FUEL) then
        return false, "Insufficient fuel: " .. fuel
    end
    
    return true
end

function movement.getFuel()
    return turtle.getFuelLevel()
end

-- Stima fuel necessario per raggiungere una posizione
function movement.estimateFuel(targetX, targetY, targetZ)
    return position.distanceTo(targetX, targetY, targetZ)
end

return movement
