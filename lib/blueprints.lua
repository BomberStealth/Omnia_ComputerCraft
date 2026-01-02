-- ============================================
-- BLUEPRINTS - Caricamento e parsing blueprint
-- ============================================

local config = require("config")

local blueprints = {}

-- Cache blueprint caricati
local cache = {}

-- ============================================
-- CARICAMENTO
-- ============================================

-- Carica blueprint da file JSON
function blueprints.load(name)
    -- Check cache
    if cache[name] then
        return cache[name]
    end
    
    -- Costruisci path
    local path = config.PATHS.BLUEPRINTS .. name .. ".json"
    
    if not fs.exists(path) then
        return nil, "Blueprint not found: " .. name
    end
    
    -- Leggi file
    local file = fs.open(path, "r")
    if not file then
        return nil, "Cannot open blueprint: " .. name
    end
    
    local content = file.readAll()
    file.close()
    
    -- Parse JSON
    local blueprint = textutils.unserializeJSON(content)
    if not blueprint then
        return nil, "Invalid blueprint JSON: " .. name
    end
    
    -- Valida
    local valid, err = blueprints.validate(blueprint)
    if not valid then
        return nil, "Invalid blueprint: " .. err
    end
    
    -- Cache
    cache[name] = blueprint
    
    return blueprint
end

-- Salva blueprint su file
function blueprints.save(name, blueprint)
    local path = config.PATHS.BLUEPRINTS .. name .. ".json"
    
    local file = fs.open(path, "w")
    if not file then
        return false, "Cannot create file"
    end
    
    file.write(textutils.serializeJSON(blueprint))
    file.close()
    
    -- Aggiorna cache
    cache[name] = blueprint
    
    return true
end

-- ============================================
-- VALIDAZIONE
-- ============================================

function blueprints.validate(bp)
    if not bp.name then
        return false, "Missing name"
    end
    
    if not bp.type then
        return false, "Missing type"
    end
    
    if not bp.dimensions then
        return false, "Missing dimensions"
    end
    
    if bp.type == "room" then
        if not bp.dimensions.width or not bp.dimensions.depth then
            return false, "Room needs width and depth"
        end
    elseif bp.type == "bus" then
        if not bp.dimensions.length then
            return false, "Bus needs length"
        end
    elseif bp.type == "corridor" then
        if not bp.dimensions.length then
            return false, "Corridor needs length"
        end
    end
    
    return true
end

-- ============================================
-- LISTA BLUEPRINT
-- ============================================

function blueprints.list()
    local list = {}
    local path = config.PATHS.BLUEPRINTS
    
    if fs.exists(path) and fs.isDir(path) then
        local files = fs.list(path)
        for _, file in ipairs(files) do
            if file:match("%.json$") then
                local name = file:gsub("%.json$", "")
                table.insert(list, name)
            end
        end
    end
    
    return list
end

-- ============================================
-- CALCOLI MATERIALI
-- ============================================

-- Calcola materiali necessari per un blueprint
function blueprints.calculateMaterials(bp)
    local materials = {}
    
    if bp.type == "room" then
        local w = bp.dimensions.width
        local d = bp.dimensions.depth
        local h = bp.dimensions.height or (config.STRUCTURE.STANZA + 2)
        
        local outerW = w + 2
        local outerD = d + 2
        
        -- Pavimento
        local floorBlocks = outerW * outerD
        local floorMat = bp.materials and bp.materials.floor or "minecraft:polished_deepslate"
        materials[floorMat] = (materials[floorMat] or 0) + floorBlocks
        
        -- Soffitto  
        local ceilingBlocks = outerW * outerD
        local ceilingMat = bp.materials and bp.materials.ceiling or "minecraft:glass"
        materials[ceilingMat] = (materials[ceilingMat] or 0) + ceilingBlocks
        
        -- Muri (perimetro * altezza - porte)
        local wallBlocks = ((outerW * 2) + (outerD * 2) - 4) * h
        local wallMat = bp.materials and bp.materials.wall or "minecraft:stone_bricks"
        materials[wallMat] = (materials[wallMat] or 0) + wallBlocks
        
        -- Porte
        if bp.doors then
            local doorBlocks = #bp.doors * 4  -- 2x2 per porta
            local doorMat = bp.materials and bp.materials.door or "minecraft:iron_door"
            materials[doorMat] = (materials[doorMat] or 0) + #bp.doors
            materials[wallMat] = materials[wallMat] - doorBlocks
        end
        
    elseif bp.type == "bus" then
        local length = bp.dimensions.length
        local width = bp.dimensions.width or config.DIMENSIONS.BUS_WIDTH
        local height = bp.dimensions.height or config.DIMENSIONS.BUS_HEIGHT
        
        -- Pavimento (vetro)
        local floorMat = bp.materials and bp.materials.floor or "minecraft:glass"
        materials[floorMat] = (materials[floorMat] or 0) + (length * width)
        
        -- Muri laterali
        local wallMat = bp.materials and bp.materials.wall or "minecraft:stone_bricks"
        materials[wallMat] = (materials[wallMat] or 0) + (length * height * 2)
        
        -- Soffitto
        local ceilingMat = bp.materials and bp.materials.ceiling or "minecraft:stone_bricks"
        materials[ceilingMat] = (materials[ceilingMat] or 0) + (length * width)
        
    elseif bp.type == "corridor" then
        local length = bp.dimensions.length
        local width = bp.dimensions.width or config.DIMENSIONS.CORRIDOR_WIDTH
        local height = bp.dimensions.height or config.DIMENSIONS.BUS_HEIGHT
        
        local wallMat = bp.materials and bp.materials.wall or "minecraft:stone_bricks"
        local floorMat = bp.materials and bp.materials.floor or "minecraft:polished_deepslate"
        local ceilingMat = bp.materials and bp.materials.ceiling or "minecraft:glowstone"
        
        materials[floorMat] = length * width
        materials[ceilingMat] = length * width
        materials[wallMat] = length * height * 2
    end
    
    return materials
end

-- ============================================
-- BLUEPRINT PREDEFINITI
-- ============================================

-- Crea blueprint stanza base
function blueprints.createRoom(name, width, depth, materials)
    return {
        name = name or "Custom Room",
        version = "1.0",
        type = "room",
        dimensions = {
            width = width or 10,
            depth = depth or 10,
            height = config.STRUCTURE.STANZA
        },
        materials = materials or {
            wall = "minecraft:stone_bricks",
            floor = "minecraft:polished_deepslate",
            ceiling = "minecraft:glass"
        },
        doors = {
            {side = "north", position = "center"}
        }
    }
end

-- Crea blueprint bus
function blueprints.createBus(name, length, direction)
    return {
        name = name or "Bus Section",
        version = "1.0",
        type = "bus",
        direction = direction or "horizontal",
        dimensions = {
            width = config.DIMENSIONS.BUS_WIDTH,
            length = length or 10,
            height = config.DIMENSIONS.BUS_HEIGHT
        },
        materials = {
            wall = "minecraft:stone_bricks",
            floor = "minecraft:glass"
        }
    }
end

-- Crea blueprint corridoio
function blueprints.createCorridor(name, length)
    return {
        name = name or "Corridor",
        version = "1.0",
        type = "corridor",
        dimensions = {
            width = config.DIMENSIONS.CORRIDOR_WIDTH,
            length = length or 5,
            height = config.DIMENSIONS.BUS_HEIGHT
        },
        materials = {
            wall = "minecraft:stone_bricks",
            floor = "minecraft:polished_deepslate",
            ceiling = "minecraft:glowstone"
        }
    }
end

-- ============================================
-- INIZIALIZZAZIONE
-- ============================================

-- Crea blueprint di default se non esistono
function blueprints.initDefaults()
    local path = config.PATHS.BLUEPRINTS
    
    -- Crea cartella se non esiste
    if not fs.exists(path) then
        fs.makeDir(path)
    end
    
    -- Room 10x10
    if not fs.exists(path .. "room_10x10.json") then
        blueprints.save("room_10x10", blueprints.createRoom("Room 10x10", 10, 10))
    end
    
    -- Room 15x15
    if not fs.exists(path .. "room_15x15.json") then
        blueprints.save("room_15x15", blueprints.createRoom("Room 15x15", 15, 15))
    end
    
    -- Bus horizontal
    if not fs.exists(path .. "bus_horizontal.json") then
        blueprints.save("bus_horizontal", blueprints.createBus("Horizontal Bus", 20, "horizontal"))
    end
    
    -- Corridor
    if not fs.exists(path .. "corridor.json") then
        blueprints.save("corridor", blueprints.createCorridor("Standard Corridor", 8))
    end
end

return blueprints
