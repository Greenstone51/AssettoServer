-- Car Color Plugin - client side (target: CSP 4130 / Preview595).
-- Config comes from CarColorPlugin.cs through ac.configValues; keys must match that file.
-- Networking: we send "AS_CarColor" to the server, the server relays "AS_CarColorUpdate" to other players.

local cfg = ac.configValues({
    presets = "",
    bodyMaterialNames = "",
    caliperMaterialNames = "",
    changeCooldownSeconds = 1.0,
    maxHistory = 10,
    maxFavourites = 50,
})

local cooldown = tonumber(cfg.changeCooldownSeconds) or 1.0
local maxHistory = math.floor(tonumber(cfg.maxHistory) or 10)
local maxFavourites = math.floor(tonumber(cfg.maxFavourites) or 50)

-- ---------- helpers ----------

local function normHex(s)
    s = tostring(s or '')
    s = s:gsub('[#%s]', '')
    if #s == 3 then
        s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2)
    end
    if #s ~= 6 or s:find('[^%x]') then return nil end
    return s:upper()
end

local function hexToRgbm(hex)
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return rgbm(r / 255, g / 255, b / 255, 1)
end

local function splitList(s)
    local out = {}
    for item in tostring(s or ''):gmatch('[^,]+') do
        local trimmed = item:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then out[#out + 1] = trimmed end
    end
    return out
end

local function parseHexList(s)
    local out = {}
    for _, item in ipairs(splitList(s)) do
        local hex = normHex(item)
        if hex then out[#out + 1] = hex end
    end
    return out
end

local presets = parseHexList(cfg.presets)
if #presets == 0 then
    presets = { 'FF0000', '00FF00', '0000FF', 'FFFF00', 'FF00FF', '00FFFF', 'FFA500', '800080', '008000', '000080', '808080', 'FFFFFF' }
end

local bodyNames = splitList(cfg.bodyMaterialNames)
if #bodyNames == 0 then bodyNames = { 'carpaint', 'body', 'paint' } end
local caliperNames = splitList(cfg.caliperMaterialNames)
if #caliperNames == 0 then caliperNames = { 'caliper', 'brake', 'disc' } end

-- Same filter style as TagModePlugin; material names are matched case sensitively, so add variants.
local function nameFilter(names)
    local parts = {}
    for _, n in ipairs(names) do
        local lower = n:lower()
        local cap = lower:sub(1, 1):upper() .. lower:sub(2)
        for _, v in ipairs({ lower, cap, lower:upper() }) do
            parts[#parts + 1] = 'material:?' .. v .. '?'
        end
    end
    return table.concat(parts, ' | ')
end

local bodyFilter = '{ shader:smCarPaint | ' .. nameFilter(bodyNames) .. ' }'
local caliperFilter = '{ ' .. nameFilter(caliperNames) .. ' }'

-- ---------- persistent per-player settings ----------

local store = ac.storage({
    body = '',
    caliper = 'FF0000',
    useCaliper = false,
    finishSet = false,
    metallic = 0.5,
    roughness = 0.5,
    history = '',
    favourites = '',
})

local history = parseHexList(store.history)
local favourites = parseHexList(store.favourites)

local function saveLists()
    store.history = table.concat(history, ',')
    store.favourites = table.concat(favourites, ',')
end

local function indexOf(list, hex)
    for i, v in ipairs(list) do
        if v == hex then return i end
    end
    return nil
end

local function pushHistory(hex)
    local i = indexOf(history, hex)
    if i then table.remove(history, i) end
    table.insert(history, 1, hex)
    while #history > maxHistory do table.remove(history) end
    saveLists()
end

local function addFavourite(hex)
    if indexOf(favourites, hex) then return end
    if #favourites >= maxFavourites then
        ui.toast(ui.Icons.Ban, 'Favourites list is full (max ' .. maxFavourites .. ')')
        return
    end
    table.insert(favourites, 1, hex)
    saveLists()
end

local function removeFavourite(hex)
    local i = indexOf(favourites, hex)
    if i then
        table.remove(favourites, i)
        saveLists()
    end
end

-- ---------- applying colors to car nodes ----------

local finishSupported = true

-- st: { body = rgbm?, caliper = rgbm?, metallic = number?, roughness = number? }
local function applyToCar(index, st)
    local ok = pcall(function()
        local root = ac.findNodes('carRoot:' .. index)
        root:resetSkin()

        if st.body then
            local bodyMeshes = root:findMeshes(bodyFilter)
            bodyMeshes:setMaterialTexture('txDiffuse', st.body)

            if st.metallic and st.roughness then
                -- ASSUMED: setMaterialProperty and the smCarPaint property names exist in CSP 4130.
                local finishOk = pcall(function()
                    bodyMeshes:setMaterialProperty('ksSpecular', st.metallic)
                    bodyMeshes:setMaterialProperty('ksSpecularEXP', 1 + (1 - st.roughness) * 299)
                end)
                if not finishOk then finishSupported = false end
            end
        end

        if st.caliper then
            root:findMeshes(caliperFilter):setMaterialTexture('txDiffuse', st.caliper)
        end

        ac.refreshCarColor(index)
    end)
    if not ok then ac.log('CarColor: failed to apply colors to car ' .. tostring(index)) end
end

local function ownRenderState()
    local st = {}
    local body = normHex(store.body)
    if body then
        st.body = hexToRgbm(body)
        if store.finishSet then
            st.metallic = store.metallic
            st.roughness = store.roughness
        end
    end
    if store.useCaliper then
        local c = normHex(store.caliper)
        if c then st.caliper = hexToRgbm(c) end
    end
    return st
end

local function applyOwn()
    applyToCar(0, ownRenderState())
end

-- ---------- networking ----------

-- Client -> server. Field names/types must match CarColorChangePacket in CarColorPlugin.cs.
local colorEvent = ac.OnlineEvent({
    ac.StructItem.key('AS_CarColor'),
    hasBody = ac.StructItem.boolean(),
    color = ac.StructItem.rgbm(),
    hasCaliper = ac.StructItem.boolean(),
    caliperColor = ac.StructItem.rgbm(),
    metallic = ac.StructItem.float(),
    roughness = ac.StructItem.float(),
})

-- Server -> clients. Field names/types must match CarColorUpdatePacket in CarColorPlugin.cs.
-- The car is identified by the sender of the message.
local colorUpdateEvent = ac.OnlineEvent({
    ac.StructItem.key('AS_CarColorUpdate'),
    hasBody = ac.StructItem.boolean(),
    color = ac.StructItem.rgbm(),
    hasCaliper = ac.StructItem.boolean(),
    caliperColor = ac.StructItem.rgbm(),
    metallic = ac.StructItem.float(),
    roughness = ac.StructItem.float(),
}, function(sender, message)
    if sender == nil or sender.index == 0 then return end

    local st = {}
    if message.hasBody then
        st.body = message.color
        if message.metallic >= 0 and message.roughness >= 0 then
            st.metallic = message.metallic
            st.roughness = message.roughness
        end
    end
    if message.hasCaliper then st.caliper = message.caliperColor end
    applyToCar(sender.index, st)
end)

local pendingSendAt = nil
local lastSentAt = -1000

local function queueSend(delay)
    pendingSendAt = os.clock() + (delay or 0)
end

local function sendState()
    local st = ownRenderState()
    colorEvent({
        hasBody = st.body ~= nil,
        color = st.body or rgbm(1, 1, 1, 1),
        hasCaliper = st.caliper ~= nil,
        caliperColor = st.caliper or rgbm(1, 1, 1, 1),
        metallic = st.metallic or -1,
        roughness = st.roughness or -1,
    })
end

-- Throttled so the server-side cooldown does not drop changes (e.g. while dragging sliders).
function script.update(dt)
    if pendingSendAt ~= nil then
        local now = os.clock()
        if now >= pendingSendAt and now - lastSentAt >= cooldown + 0.25 then
            pendingSendAt = nil
            lastSentAt = now
            sendState()
        end
    end
end

-- ---------- actions ----------

local function setBody(hex)
    hex = normHex(hex)
    if not hex then return end
    store.body = hex
    pushHistory(hex)
    applyOwn()
    queueSend(0)
end

local function setCaliper(hex)
    hex = normHex(hex)
    if not hex then return end
    store.caliper = hex
    store.useCaliper = true
    applyOwn()
    queueSend(0)
end

local function setFinish(metallic, roughness, delay)
    store.metallic = metallic
    store.roughness = roughness
    store.finishSet = true
    applyOwn()
    queueSend(delay or 0)
end

local function resetAll()
    store.body = ''
    store.useCaliper = false
    store.finishSet = false
    applyOwn()
    queueSend(0)
end

-- ---------- UI ----------

local hexInput = ''
local removeMode = false

local function swatch(id, hex, size)
    local c = hexToRgbm(hex)
    ui.pushStyleColor(ui.StyleColor.Button, c)
    ui.pushStyleColor(ui.StyleColor.ButtonHovered, c)
    ui.pushStyleColor(ui.StyleColor.ButtonActive, c)
    local clicked = ui.button('##cc_' .. id, vec2(size, size))
    ui.popStyleColor(3)
    if ui.itemHovered() then ui.setTooltip('#' .. hex) end
    return clicked
end

-- Returns the hex of the clicked swatch (or nil); callers act after the loop so lists are not modified mid-iteration.
local function swatchRow(prefix, list)
    local clicked = nil
    for i, hex in ipairs(list) do
        if (i - 1) % 8 ~= 0 then ui.sameLine(0, 4) end
        if swatch(prefix .. i, hex, 26) then clicked = hex end
    end
    return clicked
end

local function window()
    ui.pushFont(ui.Font.Title)
    ui.text('CAR COLOR')
    ui.popFont()
    ui.separator()

    -- Body color
    ui.text('Body color')
    local picked = swatchRow('p', presets)
    if picked then setBody(picked) end

    ui.text('Custom hex (e.g. FF8800)')
    hexInput = ui.inputText('##cc_hex', hexInput)
    if ui.button('Set body') then setBody(hexInput) end
    ui.sameLine()
    if ui.button('Set caliper') then setCaliper(hexInput) end

    -- Finish
    ui.separator()
    ui.text('Finish')
    if not normHex(store.body) then
        ui.textWrapped('Pick a body color first to change the finish.')
    else
        if ui.button('Matte') then setFinish(0.0, 1.0) end
        ui.sameLine()
        if ui.button('Gloss') then setFinish(0.3, 0.0) end
        ui.sameLine()
        if ui.button('Metallic') then setFinish(1.0, 0.2) end

        local m, mChanged = ui.slider('##cc_metal', store.metallic * 100, 0, 100, 'Metallic: %.0f%%')
        if mChanged then setFinish(m / 100, store.roughness, 0.4) end
        local r, rChanged = ui.slider('##cc_rough', store.roughness * 100, 0, 100, 'Roughness: %.0f%%')
        if rChanged then setFinish(store.metallic, r / 100, 0.4) end

        if not finishSupported then
            ui.textWrapped('Finish is not supported by this CSP build; only the color is applied.')
        end
    end

    -- Caliper
    ui.separator()
    ui.text('Caliper color')
    local caliperPicked = swatchRow('c', presets)
    if caliperPicked then setCaliper(caliperPicked) end
    if ui.checkbox('Paint calipers', store.useCaliper) then
        store.useCaliper = not store.useCaliper
        applyOwn()
        queueSend(0)
    end

    -- Favourites
    ui.separator()
    ui.text('Favourites (' .. #favourites .. '/' .. maxFavourites .. ')')
    local body = normHex(store.body)
    if body and ui.button('Add current color') then addFavourite(body) end
    if ui.checkbox('Click a favourite to remove it', removeMode) then removeMode = not removeMode end
    local favPicked = swatchRow('f', favourites)
    if favPicked then
        if removeMode then removeFavourite(favPicked) else setBody(favPicked) end
    end

    -- History
    ui.separator()
    ui.text('History')
    local histPicked = swatchRow('h', history)
    if histPicked then setBody(histPicked) end
    if #history > 0 and ui.button('Clear history') then
        history = {}
        saveLists()
    end

    ui.separator()
    if ui.button('Reset to stock') then resetAll() end
end

ui.registerOnlineExtra(ui.Icons.SettingsAlt, 'Car Color', function() return true end, window, nil, ui.OnlineExtraFlags.Tool)

-- Apply the saved look to our own car after load and tell the server about it.
setTimeout(function()
    local st = ownRenderState()
    if st.body or st.caliper then
        applyOwn()
        queueSend(0)
    end
end, 2)