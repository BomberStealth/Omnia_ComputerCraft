-- ============================================
-- ATM10 MODULAR BASE BUILDER - CONFIGURAZIONE
-- ============================================

local config = {}

-- RETE
config.CHANNEL_COMMAND = 100    -- PC -> Turtle
config.CHANNEL_RESPONSE = 101   -- Turtle -> PC
config.CHANNEL_STATUS = 102     -- Status updates
config.PROTOCOL = "MODBASE"     -- Protocollo Rednet

-- TURTLE
config.MIN_FUEL = 500           -- Fuel minimo per operare
config.FUEL_WARNING = 1000      -- Soglia warning fuel
config.HOME = {x = 0, y = 0, z = 0, facing = 0}  -- Posizione HOME

-- DIREZIONI (facing)
config.NORTH = 0
config.EAST = 1
config.SOUTH = 2
config.WEST = 3

-- STRUTTURA VERTICALE (blocchi)
config.STRUCTURE = {
    SOFFITTO = 1,
    STANZA = 5,
    PAVIMENTO_STANZA = 1,
    CABLAGGIO = 4,
    PAVIMENTO_CABLAGGIO = 1,
    TURTLE_PASSAGE = 1,
    PAVIMENTO_FONDO = 1,
    -- Totale per piano
    TOTAL_PIANO = 14,
    -- Piano aggiuntivo (senza pavimento condiviso)
    PIANO_EXTRA = 13
}

-- MISURE ORIZZONTALI
config.DIMENSIONS = {
    HALL_SIZE = 30,
    BUS_WIDTH = 5,
    BUS_HEIGHT = 4,
    CORRIDOR_WIDTH = 5,
    DOOR_SIZE = 2,
    WALL_THICKNESS = 1
}

-- LIVELLI RELATIVI (dentro un piano, da pavimento = 0)
config.LEVELS = {
    PAVIMENTO_FONDO = 0,
    TURTLE_PASSAGE = 1,
    PAVIMENTO_CABLAGGIO = 2,
    CABLAGGIO_START = 3,
    CABLAGGIO_END = 6,
    PAVIMENTO_STANZA = 7,
    STANZA_START = 8,
    STANZA_END = 12,
    SOFFITTO = 13
}

-- SLOT INVENTARIO TURTLE
config.SLOTS = {
    WALLS = {1, 2, 3, 4},
    FLOOR = {5, 6, 7, 8},
    CEILING = {9, 10, 11, 12},
    DOORS = {13},
    SPECIAL = {14, 15},
    FUEL = {16}
}

-- STATI TURTLE
config.STATE = {
    IDLE = "idle",
    MOVING = "moving",
    BUILDING = "building",
    DIGGING = "digging",
    RETURNING = "returning",
    REFUELING = "refueling",
    RESTOCKING = "restocking",
    ERROR = "error"
}

-- COMANDI
config.COMMANDS = {
    PING = "ping",
    STATUS = "status",
    GO_HOME = "go_home",
    REFUEL = "refuel",
    RESTOCK = "restock",
    BUILD_ROOM = "build_room",
    BUILD_BUS = "build_bus",
    BUILD_CORRIDOR = "build_corridor",
    DIG_AREA = "dig_area",
    MOVE_TO = "move_to",
    ABORT = "abort"
}

-- FILE PATHS
config.PATHS = {
    STATE_FILE = "data/base_state.json",
    CONFIG_FILE = "data/config.json",
    BLUEPRINTS = "blueprints/"
}

-- DEBUG
config.DEBUG = true

return config
