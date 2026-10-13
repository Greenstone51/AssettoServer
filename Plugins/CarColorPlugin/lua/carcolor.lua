-- Car Color Plugin - Client Side
-- No-Hesi inspired car color change menu

local config = ac.configValues()
local presets = config.presets or {}
local bodyMaterialNames = config.bodyMaterialNames or {"carpaint", "body", "paint"}
local cooldownSeconds = config.changeCooldownSeconds or 1.0

local lastColorChange = 0
local currentColor = nil
local storageKey = "carColorPlugin"

local function hexToRgb(hex)
    hex = hex:gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1,1)..hex:sub(1,1)..hex:sub(2,2)..hex:sub(2,2)..hex:sub(3,3)..hex:sub(3,3)
    end
    return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:5,6)
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

local function applyColorToCar(r, g, b)
    local car = ac.car()
    if not car then return end
    
    local nodes = ac.findNodes()
    if not nodes then return end
    
    for _, node in ipairs(nodes) do
        local mesh = node:findMeshes()
        if not mesh then continue end
        
        for _, material in ipairs(mesh) do
            local materialName = material.name:lower()
            
            for _, bodyName in ipairs(bodyMaterialNames) do
                if materialName:find(bodyName, 1, true) then
                    -- UNVERIFIED: material property setter for body color
                    -- This is the most uncertain part - exact property names vary by CSP version
                    material:setColor(r/255, g/255, b/255, 1.0)
                    break
                end
            end
        end
    end
end

local function sendColorChange(r, g, b)
    local now = os.time()
    if now - lastColorChange < cooldownSeconds then return end
    
    lastColorChange = now
    currentColor = {r, g, b}
    
    ac.sendLuaMessage({
        type = "AS_CarColor",
        color = {r, g, b}
    })
    
    saveCarColor(r, g, b)
end

local function receiveColorUpdate(data)
    local senderGuid = data.senderGuid
    local r, g, b = data.color[1], data.color[2], data.color[3]
    
    -- Apply to remote car (this would need session/car mapping)
    -- UNVERIFIED: How to identify remote car by senderGuid
end

local function onColorPresetSelected(hexColor)
    local r, g, b = hexToRgb(hexColor)
    sendColorChange(r, g, b)
end

local function onResetColor()
    local r, g, b = getCarColor()
    sendColorChange(r, g, b)
end

local function drawColorPicker()
    local windowSize = ac.getUI().windowSize
    local width, height = 300, 400
    
    local x = (windowSize[1] - width) / 2
    local y = (windowSize[2] - height) / 2
    
    ac.drawUI()
    
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
        
        if ac.getUI():isMouseOver(px, py, swatchSize, swatchSize) and ac.getUI():isMousePressed() then
            onColorPresetSelected(hexColor)
        end
    end
    
    -- Reset button
    local resetX = x + 10
    local resetY = y + 300
    local resetWidth = 280
    local resetHeight = 40
    
    ui:drawRectFilled(resetX, resetY, resetWidth, resetHeight, 100, 100, 100, 255)
    ui:drawText(resetX + 10, resetY + 10, "Reset to Default", 14, 255, 255, 255, 255)
    
    if ac.getUI():isMouseOver(resetX, resetY, resetWidth, resetHeight) and ac.getUI():isMousePressed() then
        onResetColor()
    end
    
    -- Brightness slider (UNVERIFIED: if API supports it)
    -- This may need adjustment based on actual CSP API
    
    -- Metallic slider (UNVERIFIED: if API supports it)
    -- This may need adjustment based on actual CSP API
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
    applyColorToCar(r, g, b)
end)
