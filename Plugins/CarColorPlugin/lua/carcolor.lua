-- Car Color Plugin - Client Side
-- CSP 4130 (Preview595) compatible

local config = ac.configValues()
local presets = config.presets or {}
local bodyMaterialNames = config.bodyMaterialNames or {"carpaint", "body", "paint"}
local caliperMaterialNames = config.caliperMaterialNames or {"caliper", "brake", "disc"}
local cooldownSeconds = config.changeCooldownSeconds or 1.0
local maxHistory = config.maxHistory or 10
local maxFavourites = config.maxFavourites or 50

local lastColorChange = 0
local currentColor = nil
local currentMetallic = 0.5
local currentRoughness = 0.5
local currentCaliperColor = nil
local hasCaliper = false
local storageKey = "carColorPlugin"

local history = {}
local favourites = {}

local function hexToRgb(hex)
    hex = hex:gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1,1)..hex:sub(1,1)..hex:sub(2,2)..hex:sub(2,2)..hex:sub(3,3)..hex:sub(3,3)
    end
    if #hex < 6 then
        return 255, 255, 255
    end
    local r = tonumber("0x"..hex:sub(1,2)) or 255
    local g = tonumber("0x"..hex:sub(3,4)) or 255
    local b = tonumber("0x"..hex:sub(5,6)) or 255
    return r, g, b
end

local function rgbToHex(r, g, b)
    return string.format("#%02X%02X%02X", r, g, b)
end

local function getCarColor()
    local car = ac.car()
    if not car then return nil end
    
    local storage = ac.storage()
    local carModel = car.modelName or "unknown"
    local savedColor = storage[storageKey .. "_" .. carModel]
    
    if savedColor then
        return hexToRgb(savedColor)
    end
    
    return 255, 255, 255
end

local function saveCarColor(r, g, b)
    local car = ac.car()
    if not car then return end
    
    local storage = ac.storage()
    local carModel = car.modelName or "unknown"
    local hex = rgbToHex(r, g, b)
    storage[storageKey .. "_" .. carModel] = hex
end

local function applyColorToCar(r, g, b, metallic, roughness)
    local car = ac.car()
    if not car then return end
    
    local nodes = ac.findNodes('carRoot:0')
    if not nodes then return end
    
    for _, node in ipairs(nodes) do
        local mesh = node:findMeshes()
        if not mesh then
            goto continue_node
        end
        
        for _, material in ipairs(mesh) do
            local materialName = material.name:lower()
            
            for _, bodyName in ipairs(bodyMaterialNames) do
                if materialName:find(bodyName, 1, true) then
                    -- UNVERIFIED: material property setter for body color
                    -- This is the most uncertain part - exact property names vary by CSP version
                    if material.setColor then
                        material:setColor(r/255, g/255, b/255, 1.0)
                    end
                    break
                end
            end
        end
        ::continue_node::
    end
end

local function applyCaliperColor(r, g, b)
    local car = ac.car()
    if not car then return end
    
    local nodes = ac.findNodes('carRoot:0')
    if not nodes then return end
    
    for _, node in ipairs(nodes) do
        local mesh = node:findMeshes()
        if not mesh then
            goto continue_node
        end
        
        for _, material in ipairs(mesh) do
            local materialName = material.name:lower()
            
            for _, caliperName in ipairs(caliperMaterialNames) do
                if materialName:find(caliperName, 1, true) then
                    if material.setColor then
                        material:setColor(r/255, g/255, b/255, 1.0)
                    end
                    break
                end
            end
        end
        ::continue_node::
    end
end

local function sendColorChange(r, g, b, metallic, roughness, caliperR, caliperG, caliperB, hasCaliper)
    local now = os.time()
    if now - lastColorChange < cooldownSeconds then return end
    
    lastColorChange = now
    currentColor = {r, g, b}
    currentMetallic = metallic
    currentRoughness = roughness
    currentCaliperColor = {caliperR, caliperG, caliperB}
    hasCaliper = hasCaliper
    
    ac.sendLuaMessage({
        type = "AS_CarColor",
        color = {r, g, b},
        metallic = metallic,
        roughness = roughness,
        caliperColor = {caliperR, caliperG, caliperB},
        hasCaliper = hasCaliper
    })
    
    saveCarColor(r, g, b)
end

local function receiveColorUpdate(data)
    local senderGuid = data.senderGuid
    local r, g, b = data.color[1], data.color[2], data.color[3]
    local metallic = data.metallic or 0.5
    local roughness = data.roughness or 0.5
    local caliperR, caliperG, caliperB = data.caliperColor[1], data.caliperColor[2], data.caliperColor[3]
    local hasCaliper = data.hasCaliper or false
    
    -- Apply to remote car (this would need session/car mapping)
    -- UNVERIFIED: How to identify remote car by senderGuid
end

local function addToHistory(hexColor)
    -- Remove if exists
    for i, color in ipairs(history) do
        if color == hexColor then
            table.remove(history, i)
            break
        end
    end
    
    -- Add to front
    table.insert(history, 1, hexColor)
    
    -- Trim to max
    while #history > maxHistory do
        table.remove(history)
    end
    
    -- Save to storage
    local storage = ac.storage()
    storage[storageKey .. "_history"] = table.concat(history, ",")
end

local function addToFavourites(hexColor)
    -- Check if exists
    for _, color in ipairs(favourites) do
        if color == hexColor then
            return
        end
    end
    
    -- Check max
    if #favourites >= maxFavourites then
        ac.log("Favourites list is full (max " .. maxFavourites .. ")")
        return
    end
    
    -- Add to front
    table.insert(favourites, 1, hexColor)
    
    -- Save to storage
    local storage = ac.storage()
    storage[storageKey .. "_favourites"] = table.concat(favourites, ",")
end

local function loadHistory()
    local storage = ac.storage()
    local historyStr = storage[storageKey .. "_history"]
    if historyStr then
        for color in historyStr:gmatch("[^,]+") do
            table.insert(history, color)
        end
    end
end

local function loadFavourites()
    local storage = ac.storage()
    local favouritesStr = storage[storageKey .. "_favourites"]
    if favouritesStr then
        for color in favouritesStr:gmatch("[^,]+") do
            table.insert(favourites, color)
        end
    end
end

local function onColorPresetSelected(hexColor)
    local r, g, b = hexToRgb(hexColor)
    sendColorChange(r, g, b, currentMetallic, currentRoughness, r, g, b, true)
    addToHistory(hexColor)
end

local function onResetColor()
    local r, g, b = getCarColor()
    sendColorChange(r, g, b, currentMetallic, currentRoughness, r, g, b, true)
    addToHistory(rgbToHex(r, g, b))
end

local function onFavouriteCurrentColor()
    local r, g, b = currentColor[1], currentColor[2], currentColor[3]
    local hex = rgbToHex(r, g, b)
    addToFavourites(hex)
end

local function onMatte()
    currentRoughness = 1.0
    currentMetallic = 0.0
    sendColorChange(currentColor[1], currentColor[2], currentColor[3], currentMetallic, currentRoughness, currentCaliperColor[1], currentCaliperColor[2], currentCaliperColor[3], hasCaliper)
end

local function onMetallic()
    currentMetallic = 1.0
    currentRoughness = 0.0
    sendColorChange(currentColor[1], currentColor[2], currentColor[3], currentMetallic, currentRoughness, currentCaliperColor[1], currentCaliperColor[2], currentCaliperColor[3], hasCaliper)
end

local function onGloss()
    currentMetallic = 1.0
    currentRoughness = 0.0
    sendColorChange(currentColor[1], currentColor[2], currentColor[3], currentMetallic, currentRoughness, currentCaliperColor[1], currentCaliperColor[2], currentCaliperColor[3], hasCaliper)
end

local function onCaliperColorPresetSelected(hexColor)
    local r, g, b = hexToRgb(hexColor)
    sendColorChange(currentColor[1], currentColor[2], currentColor[3], currentMetallic, currentRoughness, r, g, b, true)
end

local function onResetCaliperColor()
    local r, g, b = currentCaliperColor[1], currentCaliperColor[2], currentCaliperColor[3]
    sendColorChange(currentColor[1], currentColor[2], currentColor[3], currentMetallic, currentRoughness, r, g, b, true)
end

local function drawColorPicker()
    local windowSize = ac.getUI().windowSize
    local width, height = 400, 600
    
    local x = (windowSize[1] - width) / 2
    local y = (windowSize[2] - height) / 2
    
    local ui = ac.getUI()
    local transparentWindow = ui.transparentWindow
    
    transparentWindow:drawRectFilled(x, y, width, height, 0, 0, 0, 200)
    
    -- Title
    ui:drawText(x + 10, y + 10, "Car Color", 16, 255, 255, 255, 255)
    
    -- Preset colors
    local startX = x + 10
    local startY = y + 40
    local swatchSize = 30
    local cols = 4
    
    for i, hexColor in ipairs(presets) do
        local col = ((i - 1) % cols) + 1
        local row = math.floor((i - 1) / cols) + 1
        
        local px = startX + (col - 1) * (swatchSize + 5)
        local py = startY + (row - 1) * (swatchSize + 5)
        
        local r, g, b = hexToRgb(hexColor)
        ui:drawRectFilled(px, py, swatchSize, swatchSize, r, g, b, 255)
        
        if ui.isMouseOver and ui.isMouseOver(px, py, swatchSize, swatchSize) and ui.isMousePressed and ui.isMousePressed() then
            onColorPresetSelected(hexColor)
        end
    end
    
    -- History
    ui:drawText(x + 10, y + 200, "History", 14, 255, 255, 255, 255)
    local historyStartY = y + 220
    for i, hexColor in ipairs(history) do
        if i > 10 then break end
        local r, g, b = hexToRgb(hexColor)
        local px = x + 10 + ((i - 1) % 10) * (swatchSize + 5)
        local py = historyStartY + math.floor((i - 1) / 10) * (swatchSize + 5)
        ui:drawRectFilled(px, py, swatchSize, swatchSize, r, g, b, 255)
    end
    
    -- Favourites
    ui:drawText(x + 10, y + 350, "Favourites", 14, 255, 255, 255, 255)
    local favStartY = y + 370
    for i, hexColor in ipairs(favourites) do
        if i > 10 then break end
        local r, g, b = hexToRgb(hexColor)
        local px = x + 10 + ((i - 1) % 10) * (swatchSize + 5)
        local py = favStartY + math.floor((i - 1) / 10) * (swatchSize + 5)
        ui:drawRectFilled(px, py, swatchSize, swatchSize, r, g, b, 255)
    end
    
    -- Finish controls
    ui:drawText(x + 10, y + 500, "Finish", 14, 255, 255, 255, 255)
    
    -- Matte button
    local matteX = x + 10
    local matteY = y + 520
    local matteWidth = 120
    local matteHeight = 30
    ui:drawRectFilled(matteX, matteY, matteWidth, matteHeight, 100, 100, 100, 255)
    ui:drawText(matteX + 10, matteY + 10, "Matte", 12, 255, 255, 255, 255)
    
    -- Metallic button
    local metallicX = x + 140
    local metallicY = y + 520
    local metallicWidth = 120
    local metallicHeight = 30
    ui:drawRectFilled(metallicX, metallicY, metallicWidth, metallicHeight, 100, 100, 100, 255)
    ui:drawText(metallicX + 10, metallicY + 10, "Metallic", 12, 255, 255, 255, 255)
    
    -- Gloss button
    local glossX = x + 270
    local glossY = y + 520
    local glossWidth = 120
    local glossHeight = 30
    ui:drawRectFilled(glossX, glossY, glossWidth, glossHeight, 100, 100, 100, 255)
    ui:drawText(glossX + 10, glossY + 10, "Gloss", 12, 255, 255, 255, 255)
    
    -- Caliper color
    ui:drawText(x + 10, y + 560, "Caliper", 14, 255, 255, 255, 255)
    local caliperStartY = y + 580
    for i, hexColor in ipairs(presets) do
        if i > 5 then break end
        local r, g, b = hexToRgb(hexColor)
        local px = x + 10 + ((i - 1) % 5) * (swatchSize + 5)
        local py = caliperStartY
        ui:drawRectFilled(px, py, swatchSize, swatchSize, r, g, b, 255)
    end
    
    -- Reset caliper button
    local resetCaliperX = x + 10
    local resetCaliperY = y + 600
    local resetCaliperWidth = 120
    local resetCaliperHeight = 30
    ui:drawRectFilled(resetCaliperX, resetCaliperY, resetCaliperWidth, resetCaliperHeight, 100, 100, 100, 255)
    ui:drawText(resetCaliperX + 10, resetCaliperY + 10, "Reset Caliper", 12, 255, 255, 255, 255)
    
    -- Favourite button
    local favX = x + 140
    local favY = y + 600
    local favWidth = 120
    local favHeight = 30
    ui:drawRectFilled(favX, favY, favWidth, favHeight, 100, 100, 100, 255)
    ui:drawText(favX + 10, favY + 10, "Favourite", 12, 255, 255, 255, 255)
end

-- Register the settings window
ac.registerOnlineExtra("CarColor", drawColorPicker)

-- Listen for color updates from server
ac.addLuaMessageListener(function(msg)
    if msg.type == "AS_CarColorUpdate" then
        receiveColorUpdate(msg)
    end
end)

-- Apply color on car spawn
ac.onCarSpawned(function()
    local r, g, b = getCarColor()
    applyColorToCar(r, g, b, currentMetallic, currentRoughness)
    if hasCaliper and currentCaliperColor then
        applyCaliperColor(currentCaliperColor[1], currentCaliperColor[2], currentCaliperColor[3])
    end
end)

-- Load history and favourites
loadHistory()
loadFavourites()
