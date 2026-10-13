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

local function to255(v)
    return math.max(0, math.min(255, math.floor(v * 255 + 0.5)))
end

local function colorToHex(c)
    return string.format('%02X%02X%02X', to255(c.r), to255(c.g), to255(c.b))
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

-- ---------- draft (what the picker is currently editing) ----------

local draft = {
    body = '',
    caliper = 'FF0000',
    useCaliper = false,
    finishSet = false,
    metallic = 0.5,
    roughness = 0.5,
}
local target = 'body' -- 'body' or 'caliper'
local wheelColor = rgbm(1, 1, 1, 1)
local hexInput = ''
local removeMode = false
local previewDirty = false
local lastPreviewAt = -1000

local function loadDraft()
    draft.body = normHex(store.body) or ''
    draft.caliper = normHex(store.caliper) or 'FF0000'
    draft.useCaliper = store.useCaliper
    draft.finishSet = store.finishSet
    draft.metallic = store.metallic
    draft.roughness = store.roughness
end

local function draftRenderState()
    local st = {}
    if draft.body ~= '' then
        st.body = hexToRgbm(draft.body)
        if draft.finishSet then
            st.metallic = draft.metallic
            st.roughness = draft.roughness
        end
    end
    if draft.useCaliper then
        st.caliper = hexToRgbm(draft.caliper)
    end
    return st
end

local function currentHex()
    if target == 'body' then
        return draft.body ~= '' and draft.body or 'FFFFFF'
    end
    return draft.caliper
end

local function syncPickerFromDraft()
    local hex = currentHex()
    wheelColor = hexToRgbm(hex)
    hexInput = '#' .. hex
end

-- source: 'wheel' keeps the wheel untouched, 'typing' keeps the text box untouched, nil refreshes both
local function setDraftColor(hex, source)
    hex = normHex(hex)
    if not hex then return end

    if target == 'body' then
        draft.body = hex
    else
        draft.caliper = hex
        draft.useCaliper = true
    end

    if source ~= 'wheel' then wheelColor = hexToRgbm(hex) end
    if source ~= 'typing' then hexInput = '#' .. hex end
    previewDirty = true
end

local function setTarget(newTarget)
    target = newTarget
    syncPickerFromDraft()
end

local function applyDraft()
    store.body = draft.body
    if draft.body ~= '' then pushHistory(draft.body) end
    store.caliper = draft.caliper
    store.useCaliper = draft.useCaliper
    store.finishSet = draft.finishSet and draft.body ~= ''
    store.metallic = draft.metallic
    store.roughness = draft.roughness
    previewDirty = false
    applyOwn()
    return true
end

local function cancelDraft()
    loadDraft()
    syncPickerFromDraft()
    previewDirty = false
    applyOwn()
end

local function resetAll()
    store.body = ''
    store.useCaliper = false
    store.finishSet = false
    previewDirty = false
    loadDraft()
    syncPickerFromDraft()
    applyOwn()
end

loadDraft()
syncPickerFromDraft()

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

-- Throttled so the server-side cooldown does not drop changes.
-- Also throttles the live local preview while dragging the wheel.
function script.update(dt)
    if previewDirty then
        local now = os.clock()
        if now - lastPreviewAt >= 0.1 then
            previewDirty = false
            lastPreviewAt = now
            applyToCar(0, draftRenderState())
        end
    end

    if pendingSendAt ~= nil then
        local now = os.clock()
        if now >= pendingSendAt and now - lastSentAt >= cooldown + 0.25 then
            pendingSendAt = nil
            lastSentAt = now
            sendState()
        end
    end
end

-- ---------- UI ----------

-- ASSUMED: ui.colorPicker and ui.ColorPickerFlags.* exist in CSP 4130. Missing flags are skipped,
-- and a missing ui.colorPicker falls back to RGB sliders.
local wheelFlags = 0
pcall(function()
    local flags = ui.ColorPickerFlags
    if flags then
        for _, name in ipairs({ 'PickerHueWheel', 'NoAlpha', 'NoInputs', 'NoSidePreview', 'NoLabel', 'NoSmallPreview' }) do
            if flags[name] then wheelFlags = bit.bor(wheelFlags, flags[name]) end
        end
    end
end)

local function swatch(id, hex, w, h)
    local c = hexToRgbm(hex)
    ui.pushStyleColor(ui.StyleColor.Button, c)
    ui.pushStyleColor(ui.StyleColor.ButtonHovered, c)
    ui.pushStyleColor(ui.StyleColor.ButtonActive, c)
    local clicked = ui.button('##cc_' .. id, vec2(w, h or w))
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

local function coloredButton(label, size, color)
    ui.pushStyleColor(ui.StyleColor.Button, color)
    ui.pushStyleColor(ui.StyleColor.ButtonHovered, rgbm(math.min(1, color.r + 0.12), math.min(1, color.g + 0.12), math.min(1, color.b + 0.12), 1))
    ui.pushStyleColor(ui.StyleColor.ButtonActive, rgbm(math.min(1, color.r + 0.2), math.min(1, color.g + 0.2), math.min(1, color.b + 0.2), 1))
    local clicked = ui.button(label, size)
    ui.popStyleColor(3)
    return clicked
end

-- ---------- live car preview ----------
-- Renders the real car (carRoot:0) with a GeometryShot, so wheels, suspension and lights follow the live car.
-- The camera orbits around the car relative to its heading; drag with the left mouse button to rotate.

local preview = {
    shot = nil,
    failed = false,
    yaw = math.rad(35),
    pitch = math.rad(12),
    dragging = false,
    size = vec2(1024, 768), -- render resolution; the on-screen shape is 4:3
    zoom = 1.0,             -- 1 = default distance, smaller = closer
}

local function ensurePreviewShot()
    if preview.shot or preview.failed then return preview.shot end

    local ok, shot = pcall(function()
        local s = ac.GeometryShot(ac.findNodes('carRoot:0'), preview.size, 1, false)
        s:setClippingPlanes(0.1, 200)

        -- ASSUMED: a "full" shaders type exists so lights/paint render properly. Falls back to Simplified (used in FastTravelPlugin).
        local types = render and render.ShadersType
        if types then
            local t = types.Main or types.Default or types.Original or types.Simplified
            if t then s:setShadersType(t) end
        end
        return s
    end)

    if ok and shot then
        preview.shot = shot
    else
        preview.failed = true
        ac.log('CarColor: live preview unavailable, using swatch strip')
    end
    return preview.shot
end

-- Returns true if the preview was drawn, false if the caller should show the fallback.
local function drawCarPreview()
    local shot = ensurePreviewShot()
    if not shot then return false end

    local car = ac.getCar(0)
    if not car then return false end

    local pos = car.position
    local heading = 0
    local ok = pcall(function()
        local look = car.look -- ASSUMED to exist; heading stays 0 if not
        if look then heading = math.atan2(look.x, look.z) end
    end)
    if not ok then heading = 0 end

    local length = 4.5
    pcall(function()
        if car.aabbSize and car.aabbSize.z > 1 then length = car.aabbSize.z end
    end)
    local dist = length * 1.55 * preview.zoom

    local a = heading + preview.yaw
    local horizontal = math.cos(preview.pitch) * dist
    local target = vec3(pos.x, pos.y + 0.5, pos.z)
    local camPos = vec3(
        target.x + math.sin(a) * horizontal,
        target.y + math.sin(preview.pitch) * dist,
        target.z + math.cos(a) * horizontal)
    local look = (target - camPos):normalize()

    local width = ui.availableSpaceX()
    local height = width * preview.size.y / preview.size.x

    local drawn = pcall(function()
        shot:update(camPos, look, vec3(0, 1, 0), 40)

        -- Draw the image, then move the cursor back so the hit area sits exactly on top of it.
        local start = nil
        if ui.getCursor and ui.setCursor then start = ui.getCursor():clone() end
        ui.image(shot, vec2(width, height))
        if start then
            ui.setCursor(start)
        else
            ui.offsetCursorY(-(height + 4)) -- approximate item spacing
        end
    end)
    if not drawn then
        preview.failed = true
        preview.shot = nil
        return false
    end

    -- Invisible hit area over the image. Because it is a real item, dragging on it no longer moves the window.
    pcall(function()
        if ui.invisibleButton then
            ui.invisibleButton('##cc_prev_hit', vec2(width, height))
        else
            local clear = rgbm(0, 0, 0, 0)
            ui.pushStyleColor(ui.StyleColor.Button, clear)
            ui.pushStyleColor(ui.StyleColor.ButtonHovered, clear)
            ui.pushStyleColor(ui.StyleColor.ButtonActive, clear)
            ui.button('##cc_prev_hit', vec2(width, height))
            ui.popStyleColor(3)
        end
    end)
    local hovered = ui.itemHovered() -- must directly follow the hit area item

    pcall(function()
        -- Click-and-hold + move to rotate (ASSUMED: ui.mouseDown / ui.mouseDelta exist)
        if hovered and ui.mouseClicked(ui.MouseButton.Left) then
            preview.dragging = true
        end
        if preview.dragging then
            if ui.mouseDown(ui.MouseButton.Left) then
                local d = ui.mouseDelta()
                preview.yaw = preview.yaw - d.x * 0.01
                preview.pitch = math.max(-0.1, math.min(0.8, preview.pitch + d.y * 0.005))
            else
                preview.dragging = false
            end
        end

        -- Scroll wheel zoom: scroll up = closer
        if hovered then
            local mw = ui.mouseWheel()
            if mw ~= 0 then
                preview.zoom = math.max(0.3, math.min(2.0, preview.zoom * (1 - mw * 0.1)))
            end
        end
    end)

    if hovered then ui.setTooltip('Hold left mouse button and move to rotate, scroll to zoom') end
    return true
end

local function drawPreviewStrip()
    local avail = ui.availableSpaceX()
    local half = (avail - 6) / 2

    ui.text('Body')
    ui.sameLine(half + 6)
    ui.text('Calipers')

    if draft.body ~= '' then
        swatch('pv_body', draft.body, half, 34)
    else
        ui.button('Stock paint##cc_pv_body', vec2(half, 34))
    end
    ui.sameLine(0, 6)
    if draft.useCaliper then
        swatch('pv_cal', draft.caliper, half, 34)
    else
        ui.button('Stock##cc_pv_cal', vec2(half, 34))
    end
end

local function drawTargetCombo()
    ui.setNextItemWidth(ui.availableSpaceX())
    local label = target == 'body' and 'Car paint' or 'Calipers'
    if ui.beginCombo('##cc_target', label) then
        if ui.selectable('Car paint', target == 'body') then setTarget('body') end
        if ui.selectable('Calipers', target == 'caliper') then setTarget('caliper') end
        ui.endCombo()
    end
end

local function drawWheel()
    if ui.colorPicker ~= nil then
        ui.setNextItemWidth(ui.availableSpaceX())
        local before = colorToHex(wheelColor)
        local ok, res = pcall(ui.colorPicker, '##cc_wheel', wheelColor, wheelFlags)
        if ok and res ~= nil and type(res) ~= 'boolean' and type(res) ~= 'number' then
            wheelColor = res
        end
        if ok then
            local after = colorToHex(wheelColor)
            if after ~= before then setDraftColor(after, 'wheel') end
            return
        end
    end

    -- Fallback: plain RGB sliders
    local r, rChanged = ui.slider('##cc_fr', wheelColor.r * 255, 0, 255, 'R: %.0f')
    local g, gChanged = ui.slider('##cc_fg', wheelColor.g * 255, 0, 255, 'G: %.0f')
    local b, bChanged = ui.slider('##cc_fb', wheelColor.b * 255, 0, 255, 'B: %.0f')
    if rChanged or gChanged or bChanged then
        wheelColor = rgbm(r / 255, g / 255, b / 255, 1)
        setDraftColor(colorToHex(wheelColor), 'wheel')
    end
end

local function drawRgbRow()
    local hex = currentHex()
    local c = hexToRgbm(hex)
    local avail = ui.availableSpaceX()
    local boxW = (avail - 32 - 12) / 3
    local disabled = ui.ButtonFlags.Disabled
    ui.button('R: ' .. to255(c.r) .. '##cc_r', vec2(boxW, 26), disabled)
    ui.sameLine(0, 4)
    ui.button('G: ' .. to255(c.g) .. '##cc_g', vec2(boxW, 26), disabled)
    ui.sameLine(0, 4)
    ui.button('B: ' .. to255(c.b) .. '##cc_b', vec2(boxW, 26), disabled)
    ui.sameLine(0, 4)
    swatch('rgb_sw', hex, 28, 26)
end

local function drawHexRow()
    local avail = ui.availableSpaceX()
    ui.setNextItemWidth(avail - 32)
    local text = ui.inputText('##cc_hex', hexInput)
    if text ~= nil and text ~= hexInput then
        hexInput = text
        local n = normHex(text)
        if n then setDraftColor(n, 'typing') end
    end
    ui.sameLine(0, 4)
    swatch('hex_sw', currentHex(), 28, 26)
end

local function drawFinish()
    if draft.body == '' then
        ui.textWrapped('Pick a body color first to change the finish.')
        return
    end

    local function setFinish(metallic, roughness)
        draft.metallic = metallic
        draft.roughness = roughness
        draft.finishSet = true
        previewDirty = true
    end

    if ui.button('Matte') then setFinish(0.0, 1.0) end
    ui.sameLine()
    if ui.button('Gloss') then setFinish(0.3, 0.0) end
    ui.sameLine()
    if ui.button('Metallic') then setFinish(1.0, 0.2) end

    local m, mChanged = ui.slider('##cc_metal', draft.metallic * 100, 0, 100, 'Metallic: %.0f%%')
    if mChanged then setFinish(m / 100, draft.roughness) end
    local r, rChanged = ui.slider('##cc_rough', draft.roughness * 100, 0, 100, 'Roughness: %.0f%%')
    if rChanged then setFinish(draft.metallic, r / 100) end

    if draft.finishSet and ui.button('Clear finish') then
        draft.finishSet = false
        previewDirty = true
    end

    if not finishSupported then
        ui.textWrapped('Finish is not supported by this CSP build; only the color is applied.')
    end
end

local function window()
    ui.pushFont(ui.Font.Title)
    ui.text('Pick a new color')
    ui.popFont()
    ui.separator()
    
    if not drawCarPreview() then drawPreviewStrip() end
    ui.offsetCursorY(6)

    drawTargetCombo()
    if target == 'caliper' then
        if ui.checkbox('Paint calipers', draft.useCaliper) then
            draft.useCaliper = not draft.useCaliper
            previewDirty = true
        end
    end
    ui.offsetCursorY(4)

    drawWheel()
    ui.offsetCursorY(4)

    drawRgbRow()
    drawHexRow()

    if ui.button('Randomize', vec2(ui.availableSpaceX(), 26)) then
        setDraftColor(string.format('%02X%02X%02X', math.random(0, 255), math.random(0, 255), math.random(0, 255)))
    end

    ui.offsetCursorY(4)
    ui.text('Presets')
    local presetPicked = swatchRow('p', presets)
    if presetPicked then setDraftColor(presetPicked) end

    if target == 'body' then
        ui.treeNode('Finish', nil, drawFinish)
    end

    ui.treeNode('Favourites (' .. #favourites .. '/' .. maxFavourites .. ')', nil, function()
        if ui.button('Add current color') then addFavourite(currentHex()) end
        if ui.checkbox('Click a favourite to remove it', removeMode) then removeMode = not removeMode end
        local favPicked = swatchRow('f', favourites)
        if favPicked then
            if removeMode then removeFavourite(favPicked) else setDraftColor(favPicked) end
        end
    end)

    ui.treeNode('History', nil, function()
        local histPicked = swatchRow('h', history)
        if histPicked then setDraftColor(histPicked) end
        if #history > 0 and ui.button('Clear history') then
            history = {}
            saveLists()
        end
    end)

    ui.separator()
    local avail = ui.availableSpaceX()
    local bw = (avail - 8) / 3
    local size = vec2(bw, 30)

    if coloredButton('Apply', size, rgbm(0.15, 0.5, 0.2, 1)) then
        if applyDraft() then queueSend(0) end
    end
    ui.sameLine(0, 4)
    if coloredButton('Reset', size, rgbm(0.25, 0.3, 0.35, 1)) then
        resetAll()
        queueSend(0)
    end
    ui.sameLine(0, 4)
    if coloredButton('Cancel', size, rgbm(0.55, 0.15, 0.15, 1)) then
        cancelDraft()
    end
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
