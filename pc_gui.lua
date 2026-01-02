-- ============================================
-- ATM10 MODULAR BASE BUILDER
-- Advanced GUI Command Center v2.0
-- ============================================

-- Richiedi le librerie
local protocol = require("lib.protocol")
local config = require("config")

-- ============================================
-- COLORI TEMA
-- ============================================
local theme = {
    bg = colors.black,
    headerBg = colors.blue,
    headerText = colors.white,
    panelBg = colors.gray,
    panelBorder = colors.lightGray,
    buttonBg = colors.cyan,
    buttonText = colors.white,
    buttonActiveBg = colors.lime,
    statusOk = colors.lime,
    statusError = colors.red,
    statusWarning = colors.orange,
    textPrimary = colors.white,
    textSecondary = colors.lightGray,
    textMuted = colors.gray,
    accent = colors.cyan,
    fuelLow = colors.red,
    fuelMed = colors.orange,
    fuelHigh = colors.lime,
}

-- ============================================
-- VARIABILI GLOBALI
-- ============================================
local W, H = term.getSize()
local running = true
local turtleStatus = {
    connected = false,
    id = nil,
    label = "Unknown",
    fuel = 0,
    maxFuel = 100000,
    position = {x = 0, y = 0, z = 0},
    facing = 0,
    state = "offline",
    lastUpdate = 0
}
local logs = {}
local selectedButton = 1
local currentPage = "main"

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function addLog(msg, level)
    level = level or "info"
    table.insert(logs, 1, {
        time = os.time(),
        msg = msg,
        level = level
    })
    if #logs > 50 then
        table.remove(logs, #logs)
    end
end

local function formatFuel(fuel)
    if fuel >= 1000 then
        return string.format("%.1fk", fuel / 1000)
    end
    return tostring(fuel)
end

local function getFacingName(facing)
    local names = {"North", "East", "South", "West"}
    return names[(facing % 4) + 1] or "?"
end

local function centerText(text, width)
    local pad = math.floor((width - #text) / 2)
    return string.rep(" ", pad) .. text .. string.rep(" ", width - #text - pad)
end

-- ============================================
-- DRAWING FUNCTIONS
-- ============================================

local function drawBox(x, y, w, h, bgColor, borderColor)
    -- Fill background
    term.setBackgroundColor(bgColor)
    for i = 0, h - 1 do
        term.setCursorPos(x, y + i)
        term.write(string.rep(" ", w))
    end

    -- Draw border if specified
    if borderColor then
        term.setTextColor(borderColor)
        term.setBackgroundColor(bgColor)

        -- Top and bottom
        term.setCursorPos(x, y)
        term.write("\x9C" .. string.rep("\x8C", w - 2) .. "\x93")
        term.setCursorPos(x, y + h - 1)
        term.write("\x8D" .. string.rep("\x8C", w - 2) .. "\x8E")

        -- Sides
        for i = 1, h - 2 do
            term.setCursorPos(x, y + i)
            term.write("\x95")
            term.setCursorPos(x + w - 1, y + i)
            term.write("\x95")
        end
    end
end

local function drawHeader()
    term.setBackgroundColor(theme.headerBg)
    term.setTextColor(theme.headerText)

    for i = 1, 3 do
        term.setCursorPos(1, i)
        term.write(string.rep(" ", W))
    end

    -- Logo/Title
    term.setCursorPos(2, 2)
    term.write("\x04 ATM10 MODULAR BASE BUILDER")

    -- Version
    term.setCursorPos(W - 5, 2)
    term.write("v2.0")

    -- Connection status
    term.setCursorPos(W - 15, 2)
    if turtleStatus.connected then
        term.setTextColor(theme.statusOk)
        term.write("\x07 ONLINE ")
    else
        term.setTextColor(theme.statusError)
        term.write("\x07 OFFLINE")
    end
end

local function drawStatusPanel()
    local px, py = 2, 5
    local pw, ph = math.floor(W / 2) - 2, 10

    -- Panel background
    term.setBackgroundColor(theme.panelBg)
    for i = 0, ph - 1 do
        term.setCursorPos(px, py + i)
        term.write(string.rep(" ", pw))
    end

    -- Title
    term.setBackgroundColor(theme.accent)
    term.setTextColor(theme.headerText)
    term.setCursorPos(px, py)
    term.write(centerText(" TURTLE STATUS ", pw))

    term.setBackgroundColor(theme.panelBg)

    -- Turtle ID & Label
    term.setCursorPos(px + 1, py + 2)
    term.setTextColor(theme.textSecondary)
    term.write("ID: ")
    term.setTextColor(theme.textPrimary)
    term.write(tostring(turtleStatus.id or "--"))

    term.setCursorPos(px + 10, py + 2)
    term.setTextColor(theme.textSecondary)
    term.write("Label: ")
    term.setTextColor(theme.textPrimary)
    term.write(tostring(turtleStatus.label or "None"):sub(1, 10))

    -- Position
    term.setCursorPos(px + 1, py + 4)
    term.setTextColor(theme.textSecondary)
    term.write("Position: ")
    term.setTextColor(theme.accent)
    term.write(string.format("X:%d Y:%d Z:%d",
        turtleStatus.position.x,
        turtleStatus.position.y,
        turtleStatus.position.z))

    -- Facing
    term.setCursorPos(px + 1, py + 5)
    term.setTextColor(theme.textSecondary)
    term.write("Facing: ")
    term.setTextColor(theme.textPrimary)
    term.write(getFacingName(turtleStatus.facing))

    -- Fuel Bar
    term.setCursorPos(px + 1, py + 7)
    term.setTextColor(theme.textSecondary)
    term.write("Fuel: ")

    local fuelPercent = turtleStatus.fuel / turtleStatus.maxFuel
    local barWidth = pw - 14
    local filledWidth = math.floor(fuelPercent * barWidth)

    -- Fuel color based on level
    local fuelColor = theme.fuelHigh
    if fuelPercent < 0.2 then
        fuelColor = theme.fuelLow
    elseif fuelPercent < 0.5 then
        fuelColor = theme.fuelMed
    end

    term.setBackgroundColor(colors.black)
    term.write(string.rep(" ", barWidth))
    term.setCursorPos(px + 7, py + 7)
    term.setBackgroundColor(fuelColor)
    term.write(string.rep(" ", filledWidth))

    term.setBackgroundColor(theme.panelBg)
    term.setTextColor(fuelColor)
    term.setCursorPos(px + 8 + barWidth, py + 7)
    term.write(" " .. formatFuel(turtleStatus.fuel))

    -- State
    term.setCursorPos(px + 1, py + 8)
    term.setTextColor(theme.textSecondary)
    term.write("State: ")
    local stateColor = theme.statusOk
    if turtleStatus.state == "error" then
        stateColor = theme.statusError
    elseif turtleStatus.state == "offline" then
        stateColor = theme.textMuted
    elseif turtleStatus.state == "moving" or turtleStatus.state == "building" then
        stateColor = theme.statusWarning
    end
    term.setTextColor(stateColor)
    term.write(turtleStatus.state:upper())
end

local function drawControlPanel()
    local px = math.floor(W / 2) + 1
    local py = 5
    local pw = math.floor(W / 2) - 2
    local ph = 10

    -- Panel background
    term.setBackgroundColor(theme.panelBg)
    for i = 0, ph - 1 do
        term.setCursorPos(px, py + i)
        term.write(string.rep(" ", pw))
    end

    -- Title
    term.setBackgroundColor(theme.accent)
    term.setTextColor(theme.headerText)
    term.setCursorPos(px, py)
    term.write(centerText(" CONTROLS ", pw))

    -- Buttons
    local buttons = {
        {label = "[P] Ping", key = "p"},
        {label = "[S] Status", key = "s"},
        {label = "[H] Home", key = "h"},
        {label = "[R] Refuel", key = "r"},
        {label = "[M] Move", key = "m"},
        {label = "[D] Dig", key = "d"},
        {label = "[B] Build", key = "b"},
        {label = "[Q] Quit", key = "q"},
    }

    local col1x = px + 2
    local col2x = px + pw/2 + 1

    for i, btn in ipairs(buttons) do
        local bx = (i % 2 == 1) and col1x or col2x
        local by = py + 2 + math.floor((i - 1) / 2)

        term.setCursorPos(bx, by)

        if selectedButton == i then
            term.setBackgroundColor(theme.buttonActiveBg)
            term.setTextColor(colors.black)
        else
            term.setBackgroundColor(theme.buttonBg)
            term.setTextColor(theme.buttonText)
        end

        local padded = " " .. btn.label .. string.rep(" ", 12 - #btn.label)
        term.write(padded)
    end

    term.setBackgroundColor(theme.panelBg)
end

local function drawLogPanel()
    local px, py = 2, 16
    local pw, ph = W - 3, H - 16

    -- Panel background
    term.setBackgroundColor(theme.panelBg)
    for i = 0, ph - 1 do
        term.setCursorPos(px, py + i)
        term.write(string.rep(" ", pw))
    end

    -- Title
    term.setBackgroundColor(theme.accent)
    term.setTextColor(theme.headerText)
    term.setCursorPos(px, py)
    term.write(centerText(" ACTIVITY LOG ", pw))

    -- Logs
    term.setBackgroundColor(theme.panelBg)
    for i = 1, math.min(#logs, ph - 2) do
        local log = logs[i]
        term.setCursorPos(px + 1, py + i)

        -- Time
        term.setTextColor(theme.textMuted)
        term.write(string.format("[%02d:%02d] ", math.floor(log.time), math.floor((log.time % 1) * 60)))

        -- Level color
        if log.level == "error" then
            term.setTextColor(theme.statusError)
        elseif log.level == "success" then
            term.setTextColor(theme.statusOk)
        elseif log.level == "warning" then
            term.setTextColor(theme.statusWarning)
        else
            term.setTextColor(theme.textSecondary)
        end

        term.write(log.msg:sub(1, pw - 10))
    end
end

local function drawInputDialog(title, prompt)
    local dw, dh = 40, 7
    local dx = math.floor((W - dw) / 2)
    local dy = math.floor((H - dh) / 2)

    -- Shadow
    term.setBackgroundColor(colors.black)
    for i = 1, dh do
        term.setCursorPos(dx + 2, dy + i)
        term.write(string.rep(" ", dw))
    end

    -- Dialog box
    term.setBackgroundColor(theme.panelBg)
    for i = 0, dh - 1 do
        term.setCursorPos(dx, dy + i)
        term.write(string.rep(" ", dw))
    end

    -- Title bar
    term.setBackgroundColor(theme.headerBg)
    term.setTextColor(theme.headerText)
    term.setCursorPos(dx, dy)
    term.write(centerText(" " .. title .. " ", dw))

    -- Prompt
    term.setBackgroundColor(theme.panelBg)
    term.setTextColor(theme.textPrimary)
    term.setCursorPos(dx + 2, dy + 2)
    term.write(prompt)

    -- Input field
    term.setBackgroundColor(colors.black)
    term.setCursorPos(dx + 2, dy + 4)
    term.write(string.rep(" ", dw - 4))
    term.setCursorPos(dx + 2, dy + 4)
    term.setTextColor(theme.accent)

    return read()
end

local function drawScreen()
    -- Clear
    term.setBackgroundColor(theme.bg)
    term.clear()

    -- Draw components
    drawHeader()
    drawStatusPanel()
    drawControlPanel()
    drawLogPanel()
end

-- ============================================
-- COMMAND FUNCTIONS
-- ============================================

local function cmdPing()
    addLog("Pinging turtle...", "info")
    drawScreen()

    local ok, response = protocol.sendCommand("PING", {})
    if ok then
        turtleStatus.connected = true
        turtleStatus.id = response.id
        turtleStatus.label = response.label or "Turtle"
        turtleStatus.fuel = response.fuel or 0
        if response.position then
            turtleStatus.position = response.position
        end
        turtleStatus.state = "idle"
        addLog("Turtle #" .. turtleStatus.id .. " connected!", "success")
    else
        turtleStatus.connected = false
        turtleStatus.state = "offline"
        addLog("No response from turtle", "error")
    end
end

local function cmdStatus()
    addLog("Requesting status...", "info")
    drawScreen()

    local ok, response = protocol.sendCommand("STATUS", {})
    if ok then
        turtleStatus.connected = true
        turtleStatus.fuel = response.fuel or turtleStatus.fuel
        turtleStatus.state = response.state or "idle"
        if response.position then
            turtleStatus.position = response.position
            turtleStatus.facing = response.position.facing or 0
        end
        addLog("Status updated", "success")
    else
        addLog("Failed to get status", "error")
    end
end

local function cmdHome()
    addLog("Sending turtle home...", "info")
    drawScreen()

    local ok = protocol.sendCommand("GO_HOME", {})
    if ok then
        turtleStatus.state = "moving"
        addLog("Turtle returning home", "success")
    else
        addLog("Failed to send home command", "error")
    end
end

local function cmdRefuel()
    addLog("Refueling turtle...", "info")
    drawScreen()

    local ok, response = protocol.sendCommand("REFUEL", {})
    if ok then
        if response.fuel then
            turtleStatus.fuel = response.fuel
        end
        addLog("Refuel complete: " .. formatFuel(turtleStatus.fuel), "success")
    else
        addLog("Refuel failed", "error")
    end
end

local function cmdMove()
    local input = drawInputDialog("MOVE TO", "Enter X Y Z (e.g. 10 5 -3):")

    if input and input ~= "" then
        local x, y, z = input:match("([%-]?%d+)%s+([%-]?%d+)%s+([%-]?%d+)")
        if x and y and z then
            addLog("Moving to " .. x .. "," .. y .. "," .. z, "info")
            local ok = protocol.sendCommand("MOVE_TO", {
                x = tonumber(x),
                y = tonumber(y),
                z = tonumber(z)
            })
            if ok then
                turtleStatus.state = "moving"
                addLog("Turtle moving...", "success")
            else
                addLog("Move command failed", "error")
            end
        else
            addLog("Invalid coordinates", "error")
        end
    end
end

local function cmdDig()
    local input = drawInputDialog("DIG AREA", "Enter W H D (e.g. 5 3 5):")

    if input and input ~= "" then
        local w, h, d = input:match("(%d+)%s+(%d+)%s+(%d+)")
        if w and h and d then
            addLog("Digging " .. w .. "x" .. h .. "x" .. d, "info")
            local ok = protocol.sendCommand("DIG_AREA", {
                width = tonumber(w),
                height = tonumber(h),
                depth = tonumber(d)
            })
            if ok then
                turtleStatus.state = "digging"
                addLog("Turtle digging...", "success")
            else
                addLog("Dig command failed", "error")
            end
        else
            addLog("Invalid dimensions", "error")
        end
    end
end

local function cmdBuild()
    addLog("Build feature coming soon!", "warning")
end

-- ============================================
-- MAIN LOOP
-- ============================================

local function handleInput()
    while running do
        local event, key = os.pullEvent("key")

        if key == keys.q then
            running = false
        elseif key == keys.p then
            cmdPing()
        elseif key == keys.s then
            cmdStatus()
        elseif key == keys.h then
            cmdHome()
        elseif key == keys.r then
            cmdRefuel()
        elseif key == keys.m then
            cmdMove()
        elseif key == keys.d then
            cmdDig()
        elseif key == keys.b then
            cmdBuild()
        end

        drawScreen()
    end
end

local function statusUpdater()
    while running do
        sleep(5)
        if turtleStatus.connected then
            local ok, response = protocol.sendCommand("STATUS", {}, 2)
            if ok then
                turtleStatus.fuel = response.fuel or turtleStatus.fuel
                turtleStatus.state = response.state or turtleStatus.state
                if response.position then
                    turtleStatus.position = response.position
                    turtleStatus.facing = response.position.facing or 0
                end
            else
                turtleStatus.connected = false
                turtleStatus.state = "offline"
            end
            drawScreen()
        end
    end
end

-- ============================================
-- INIT
-- ============================================

local function init()
    -- Init modem
    local modemSide = protocol.init()
    if not modemSide then
        print("ERROR: No wireless modem found!")
        print("Attach a wireless modem and try again.")
        return false
    end

    addLog("System initialized", "info")
    addLog("Modem ready", "success")
    addLog("Press P to ping turtle", "info")

    return true
end

local function main()
    if not init() then
        return
    end

    drawScreen()

    parallel.waitForAny(handleInput, statusUpdater)

    -- Cleanup
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    print("GUI closed. Run 'pc_gui' to restart.")
end

main()
