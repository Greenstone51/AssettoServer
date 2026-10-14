-- AI Traffic Controller (client side). Runs through CSPServerScriptProvider.
-- Struct fields must match AiControlSetPacket / AiControlStatusPacket in Packets/*.cs.

local config = ac.configValues({
    requireAdmin = true
})

local state = {
    enabled = false,
    density = 1.0,
    maxSpeedKph = 80.0,
    playerRadius = 200.0,
    perPlayer = 0,
    maxCount = 0,
    minSpawn = 100,
    maxSpawn = 400,
    minSafety = 20,
    maxSafety = 70,
    activeStates = 0
}

local draft = {}

local function updateDraft()
    for k, v in pairs(state) do
        if k ~= 'activeStates' then draft[k] = v end
    end
end
updateDraft()

-- Client -> server.
local setEvent = ac.OnlineEvent({
    ac.StructItem.key('AS_AiCtrlSet'),
    enabled = ac.StructItem.boolean(),
    density = ac.StructItem.float(),
    maxSpeedKph = ac.StructItem.float(),
    playerRadius = ac.StructItem.float(),
    perPlayer = ac.StructItem.uint16(),
    maxCount = ac.StructItem.uint16(),
    minSpawn = ac.StructItem.uint16(),
    maxSpawn = ac.StructItem.uint16(),
    minSafety = ac.StructItem.uint16(),
    maxSafety = ac.StructItem.uint16(),
})

-- Server -> client.
ac.OnlineEvent({
    ac.StructItem.key('AS_AiCtrlStatus'),
    enabled = ac.StructItem.boolean(),
    density = ac.StructItem.float(),
    maxSpeedKph = ac.StructItem.float(),
    playerRadius = ac.StructItem.float(),
    perPlayer = ac.StructItem.uint16(),
    maxCount = ac.StructItem.uint16(),
    minSpawn = ac.StructItem.uint16(),
    maxSpawn = ac.StructItem.uint16(),
    minSafety = ac.StructItem.uint16(),
    maxSafety = ac.StructItem.uint16(),
    activeStates = ac.StructItem.uint16(),
}, function(sender, message)
    -- Status messages come from the server (sender index 0 / nil), never from another player.
    if sender ~= nil and sender.index ~= 0 then return end
    state.enabled = message.enabled
    state.density = message.density
    state.maxSpeedKph = message.maxSpeedKph
    state.playerRadius = message.playerRadius
    state.perPlayer = message.perPlayer
    state.maxCount = message.maxCount
    state.minSpawn = message.minSpawn
    state.maxSpawn = message.maxSpawn
    state.minSafety = message.minSafety
    state.maxSafety = message.maxSafety
    state.activeStates = message.activeStates
    updateDraft()
end)

local function sendSet()
    setEvent({
        enabled = draft.enabled,
        density = draft.density,
        maxSpeedKph = draft.maxSpeedKph,
        playerRadius = draft.playerRadius,
        perPlayer = math.floor(draft.perPlayer + 0.5),
        maxCount = math.floor(draft.maxCount + 0.5),
        minSpawn = math.floor(draft.minSpawn + 0.5),
        maxSpawn = math.floor(draft.maxSpawn + 0.5),
        minSafety = math.floor(draft.minSafety + 0.5),
        maxSafety = math.floor(draft.maxSafety + 0.5),
    })
end

local function sliderRow(label, id, key, min, max, fmt)
    ui.text(label)
    ui.setNextItemWidth(ui.availableSpaceX())
    local v, changed = ui.slider(id, draft[key], min, max, fmt)
    if changed then draft[key] = v end
end

local function window()
    if config.requireAdmin and not ac.getSim().isAdmin then
        ui.textWrapped('Admins only.')
        return
    end

    if ui.checkbox('Controller enabled (off = server config values)', draft.enabled) then
        draft.enabled = not draft.enabled
    end
    ui.text('Active AI states: ' .. state.activeStates)
    ui.separator()

    sliderRow('Traffic density', '##aitc_density', 'density', 0.05, 2.0, '%.2f')
    sliderRow('AI cars per player (0 = auto)', '##aitc_perPlayer', 'perPlayer', 0, 50, '%.0f')
    sliderRow('Max AI cars (0 = auto)', '##aitc_maxCount', 'maxCount', 0, 500, '%.0f')
    sliderRow('Max speed (km/h)', '##aitc_maxSpeed', 'maxSpeedKph', 5, 300, '%.0f')
    sliderRow('Player radius (m)', '##aitc_radius', 'playerRadius', 50, 2000, '%.0f')
    sliderRow('Min spawn distance (points)', '##aitc_minSpawn', 'minSpawn', 0, 2000, '%.0f')
    sliderRow('Max spawn distance (points)', '##aitc_maxSpawn', 'maxSpawn', 0, 2000, '%.0f')
    sliderRow('Min safety distance (m)', '##aitc_minSafety', 'minSafety', 0, 1000, '%.0f')
    sliderRow('Max safety distance (m)', '##aitc_maxSafety', 'maxSafety', 0, 1000, '%.0f')

    ui.separator()
    ui.textWrapped('Note: TrafficDensity may be overwritten by HourlyTrafficDensity every ~10 in-game minutes.')

    if ui.button('Apply', vec2(100, 30)) then
        sendSet()
        ui.toast(ui.Icons.Confirm, 'AI settings applied')
    end
    ui.sameLine()
    if ui.button('Reset', vec2(100, 30)) then
        updateDraft()
        ui.toast(ui.Icons.Confirm, 'Draft reset to current server values')
    end
end

ui.registerOnlineExtra(ui.Icons.SettingsAlt, 'AI Traffic Controller', function() return true end, window, nil, ui.OnlineExtraFlags.Tool)
