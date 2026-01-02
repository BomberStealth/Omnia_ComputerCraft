-- ============================================
-- GIT SYNC - Pull & Push to GitHub
-- ============================================
-- Repo: https://github.com/BomberStealth/Omnia_ComputerCraft

local REPO = "BomberStealth/Omnia_ComputerCraft"
local BRANCH = "main"
local TOKEN = "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"

local RAW_URL = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH .. "/"
local API_URL = "https://api.github.com/repos/" .. REPO .. "/contents/"

-- File da sincronizzare
local FILES = {
    "config.lua",
    "turtle_main.lua",
    "pc_main.lua",
    "gitsync.lua",
    "lib/position.lua",
    "lib/movement.lua",
    "lib/protocol.lua",
    "lib/inventory.lua",
    "lib/builder.lua",
    "lib/blueprints.lua",
    "blueprints/room_10x10.json",
}

-- ============================================
-- UTILITIES
-- ============================================

local function createDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

-- Base64 encoding
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64encode(data)
    return ((data:gsub('.', function(x) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do 
            r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') 
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do 
            c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) 
        end
        return b64chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

-- ============================================
-- PULL (Download da GitHub)
-- ============================================

local function downloadFile(remotePath, localPath)
    local url = RAW_URL .. remotePath
    print("  [PULL] " .. remotePath)
    
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        
        local dir = fs.getDir(localPath)
        if dir ~= "" then createDir(dir) end
        
        local file = fs.open(localPath, "w")
        if file then
            file.write(content)
            file.close()
            return true
        end
    end
    print("    FAILED!")
    return false
end

local function pullAll()
    print("================================")
    print(" GIT PULL - Download da GitHub")
    print("================================")
    
    createDir("lib")
    createDir("blueprints")
    
    local success, failed = 0, 0
    for _, file in ipairs(FILES) do
        if downloadFile(file, file) then
            success = success + 1
        else
            failed = failed + 1
        end
    end
    
    print("")
    print("Done! Success: " .. success .. ", Failed: " .. failed)
end

-- ============================================
-- PUSH (Upload su GitHub) - USA PUT!
-- ============================================

local function getFileSha(remotePath)
    local url = API_URL .. remotePath .. "?ref=" .. BRANCH
    local headers = {
        ["Authorization"] = "token " .. TOKEN,
        ["Accept"] = "application/vnd.github.v3+json",
        ["User-Agent"] = "CC-Tweaked"
    }
    
    local response = http.get(url, headers)
    if response then
        local data = response.readAll()
        response.close()
        local sha = data:match('"sha"%s*:%s*"([^"]+)"')
        return sha
    end
    return nil
end

local function uploadFile(localPath, remotePath)
    print("  [PUSH] " .. remotePath)
    
    if not fs.exists(localPath) then
        print("    File not found!")
        return false
    end
    
    -- Leggi file locale
    local file = fs.open(localPath, "r")
    local content = file.readAll()
    file.close()
    
    -- Ottieni SHA esistente (necessario per update)
    local sha = getFileSha(remotePath)
    
    -- Prepara JSON body
    local encoded = base64encode(content)
    local body = '{"message":"Update ' .. remotePath .. ' from CC","content":"' .. encoded .. '","branch":"' .. BRANCH .. '"'
    if sha then
        body = body .. ',"sha":"' .. sha .. '"'
    end
    body = body .. '}'
    
    -- Headers
    local headers = {
        ["Authorization"] = "token " .. TOKEN,
        ["Accept"] = "application/vnd.github.v3+json",
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "CC-Tweaked"
    }
    
    -- Usa http.request con PUT
    local url = API_URL .. remotePath
    http.request({
        url = url,
        body = body,
        headers = headers,
        method = "PUT"
    })
    
    -- Aspetta risposta
    local timeout = os.startTimer(10)
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "http_success" and param1 == url then
            local response = param2
            local code = response.getResponseCode()
            response.close()
            if code == 200 or code == 201 then
                return true
            else
                print("    HTTP " .. code)
                return false
            end
        elseif event == "http_failure" and param1 == url then
            print("    FAILED: " .. (param2 or "unknown"))
            return false
        elseif event == "timer" and param1 == timeout then
            print("    TIMEOUT!")
            return false
        end
    end
end

local function pushAll()
    print("================================")
    print(" GIT PUSH - Upload su GitHub")
    print("================================")
    
    local success, failed = 0, 0
    for _, file in ipairs(FILES) do
        if fs.exists(file) then
            if uploadFile(file, file) then
                success = success + 1
            else
                failed = failed + 1
            end
        else
            print("  [SKIP] " .. file .. " (not found)")
        end
    end
    
    print("")
    print("Done! Success: " .. success .. ", Failed: " .. failed)
end

local function pushFile(filename)
    print("================================")
    print(" GIT PUSH - " .. filename)
    print("================================")
    
    if uploadFile(filename, filename) then
        print("Success!")
    else
        print("Failed!")
    end
end

-- ============================================
-- MAIN
-- ============================================

local args = {...}
local cmd = args[1] or "help"

if cmd == "pull" then
    pullAll()
elseif cmd == "push" then
    if args[2] then
        pushFile(args[2])
    else
        pushAll()
    end
elseif cmd == "list" then
    print("Files tracked:")
    for _, file in ipairs(FILES) do
        local exists = fs.exists(file) and "[OK]" or "[--]"
        print("  " .. exists .. " " .. file)
    end
else
    print("================================")
    print(" GITSYNC - GitHub Sync Tool")
    print("================================")
    print("")
    print("Commands:")
    print("  gitsync pull       - Download all")
    print("  gitsync push       - Upload all")
    print("  gitsync push file  - Upload one file")
    print("  gitsync list       - List files")
    print("")
    print("Repo: " .. REPO)
end
