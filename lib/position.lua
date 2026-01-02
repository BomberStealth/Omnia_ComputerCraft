-- ============================================
-- POSITION TRACKING - Gestione posizione turtle
-- ============================================

local config = require("config")

local position = {}

-- Stato corrente
local pos = {
    x = 0,
    y = 0,
    z = 0,
    facing = 0  -- 0=North, 1=East, 2=South, 3=West
}

-- Nomi direzioni per debug
local facingNames = {"North", "East", "South", "West"}

-- Delta movimento per ogni direzione
local delta = {
    [0] = {x = 0, z = -1},   -- North
    [1] = {x = 1, z = 0},    -- East
    [2] = {x = 0, z = 1},    -- South
    [3] = {x = -1, z = 0}    -- West
}

-- ============================================
-- GETTERS
-- ============================================

function position.get()
    return {
        x = pos.x,
        y = pos.y,
        z = pos.z,
        facing = pos.facing
    }
end

function position.getX()
    return pos.x
end

function position.getY()
    return pos.y
end

function position.getZ()
    return pos.z
end

function position.getFacing()
    return pos.facing
end

function position.getFacingName()
    return facingNames[pos.facing + 1]
end

-- ============================================
-- SETTERS
-- ============================================

function position.set(x, y, z, facing)
    pos.x = x or pos.x
    pos.y = y or pos.y
    pos.z = z or pos.z
    pos.facing = facing or pos.facing
end

function position.setHome()
    pos.x = config.HOME.x
    pos.y = config.HOME.y
    pos.z = config.HOME.z
    pos.facing = config.HOME.facing
end

-- ============================================
-- AGGIORNAMENTO POSIZIONE
-- ============================================

-- Chiamare dopo turtle.forward() riuscito
function position.forward()
    local d = delta[pos.facing]
    pos.x = pos.x + d.x
    pos.z = pos.z + d.z
end

-- Chiamare dopo turtle.back() riuscito
function position.back()
    local d = delta[pos.facing]
    pos.x = pos.x - d.x
    pos.z = pos.z - d.z
end

-- Chiamare dopo turtle.up() riuscito
function position.up()
    pos.y = pos.y + 1
end

-- Chiamare dopo turtle.down() riuscito
function position.down()
    pos.y = pos.y - 1
end

-- Chiamare dopo turtle.turnLeft() riuscito
function position.turnLeft()
    pos.facing = (pos.facing - 1) % 4
end

-- Chiamare dopo turtle.turnRight() riuscito
function position.turnRight()
    pos.facing = (pos.facing + 1) % 4
end

-- ============================================
-- CALCOLI
-- ============================================

-- Calcola distanza Manhattan da posizione corrente a target
function position.distanceTo(targetX, targetY, targetZ)
    return math.abs(targetX - pos.x) + 
           math.abs(targetY - pos.y) + 
           math.abs(targetZ - pos.z)
end

-- Calcola direzione da girare per andare verso target
function position.facingTo(targetX, targetZ)
    local dx = targetX - pos.x
    local dz = targetZ - pos.z
    
    if math.abs(dx) > math.abs(dz) then
        if dx > 0 then
            return config.EAST
        else
            return config.WEST
        end
    else
        if dz > 0 then
            return config.SOUTH
        else
            return config.NORTH
        end
    end
end

-- Verifica se siamo a HOME
function position.isHome()
    return pos.x == config.HOME.x and
           pos.y == config.HOME.y and
           pos.z == config.HOME.z
end

-- ============================================
-- PERSISTENZA
-- ============================================

function position.save()
    local file = fs.open("data/position.dat", "w")
    if file then
        file.write(textutils.serialize(pos))
        file.close()
        return true
    end
    return false
end

function position.load()
    if fs.exists("data/position.dat") then
        local file = fs.open("data/position.dat", "r")
        if file then
            local data = textutils.unserialize(file.readAll())
            file.close()
            if data then
                pos.x = data.x or 0
                pos.y = data.y or 0
                pos.z = data.z or 0
                pos.facing = data.facing or 0
                return true
            end
        end
    end
    return false
end

-- ============================================
-- DEBUG
-- ============================================

function position.toString()
    return string.format("X:%d Y:%d Z:%d F:%s", 
        pos.x, pos.y, pos.z, position.getFacingName())
end

function position.print()
    print(position.toString())
end

return position
