local ui = ac.ui
local ac = ac

local state = {
    enabled = false,
    density = 1.0,
    maxSpeedKph = 150.0,
    playerRadius = 500.0,
    perPlayer = 10,
    maxCount = 50,
    minSpawn = 10,
    maxSpawn = 100,
    minSafety = 5,
    maxSafety = 50,
    activeStates = 0
}

local draft = {}

local function updateDraft()
    draft.enabled = state.enabled
    draft.density = state.density
    draft.maxSpeedKph = state.maxSpeedKph
    draft.playerRadius = state.playerRadius
    draft.perPlayer = state.perPlayer
    draft.maxCount = state.maxCount
    draft.minSpawn = state.minSpawn
    draft.maxSpawn = state.maxSpawn
    draft.minSafety = state.minSafety
    draft.maxSafety = state.maxSafety
end

local function sendSetPacket()
    ac.sendLuaMessage({
        key = "AS_AiCtrlSet",
        enabled = draft.enabled,
        density = draft.density,
        maxSpeedKph = draft.maxSpeedKph,
        playerRadius = draft.playerRadius,
        perPlayer = draft.perPlayer,
        maxCount = draft.maxCount,
        minSpawn = draft.minSpawn,
        maxSpawn = draft.maxSpawn,
        minSafety = draft.minSafety,
        maxSafety = draft.maxSafety
    })
end

local function onOnlineExtraStatus(event)
    if event.sender ~= nil then return end
    state.enabled = event.enabled
    state.density = event.density
    state.maxSpeedKph = event.maxSpeedKph
    state.playerRadius = event.playerRadius
    state.perPlayer = event.perPlayer
    state.maxCount = event.maxCount
    state.minSpawn = event.minSpawn
    state.maxSpawn = event.maxSpawn
    state.minSafety = event.minSafety
    state.maxSafety = event.maxSafety
    state.activeStates = event.activeStates
    updateDraft()
end

ac.addLuaMessageListener(function(event)
    if event.key == "AS_AiCtrlStatus" then
        onOnlineExtraStatus(event)
    end
end)

local function window()
    if not ac.getSim().isAdmin then
        ui.textWrapped("Admins only.")
        return
    end

    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())

    local buttonColor = state.enabled and {1.0, 0.2, 0.2, 1.0} or {0.2, 1.0, 0.2, 1.0}
    local buttonText = state.enabled and "OFF" or "ON"

    if ui.button(buttonText, {100, 30}, buttonColor) then
        draft.enabled = not draft.enabled
    end

    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    ui.text("Active AI states: " .. state.activeStates)

    ui.separator()

    ui.text("Traffic Density")
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    if ui.slider("##density", draft.density, 0.0, 2.0, "%.2f") then
        draft.density = math.max(0.0, math.min(2.0, draft.density))
    end

    ui.text("Cars per Player")
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    if ui.slider("##perPlayer", draft.perPlayer, 0, 50, "%d") then
        draft.perPlayer = math.max(0, math.min(50, draft.perPlayer))
    end

    ui.text("Max AI Cars")
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    if ui.slider("##maxCount", draft.maxCount, 0, 500, "%d") then
        draft.maxCount = math.max(0, math.min(500, draft.maxCount))
    end

    ui.text("Max Speed (km/h)")
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    if ui.slider("##maxSpeedKph", draft.maxSpeedKph, 5, 300, "%.0f") then
        draft.maxSpeedKph = math.max(5, math.min(300, draft.maxSpeedKph))
    end

    ui.text("Player Radius (m)")
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    if ui.slider("##playerRadius", draft.playerRadius, 50, 2000, "%.0f") then
        draft.playerRadius = math.max(50, math.min(2000, draft.playerRadius))
    end

    ui.text("Spawn Distance (points)")
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    if ui.slider("##minSpawn", draft.minSpawn, 0, draft.maxSpawn, "%d") then
        draft.minSpawn = math.max(0, math.min(draft.maxSpawn, draft.minSpawn))
    end
    ui.sameLine()
    if ui.slider("##maxSpawn", draft.maxSpawn, draft.minSpawn, 2000, "%d") then
        draft.maxSpawn = math.max(draft.minSpawn, math.min(2000, draft.maxSpawn))
    end

    ui.text("Safety Distance (m)")
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    if ui.slider("##minSafety", draft.minSafety, 0, draft.maxSafety, "%d") then
        draft.minSafety = math.max(0, math.min(draft.maxSafety, draft.minSafety))
    end
    ui.sameLine()
    if ui.slider("##maxSafety", draft.maxSafety, draft.minSafety, 1000, "%d") then
        draft.maxSafety = math.max(draft.minSafety, math.min(1000, draft.maxSafety))
    end

    ui.separator()
    ui.textWrapped("Note: TrafficDensity may be overwritten by HourlyTrafficDensity every ~10 in-game minutes.")

    ui.sameLine()
    if ui.button("Apply", {100, 30}) then
        sendSetPacket()
        ui.toast("AI settings applied", ui.Icons.Confirm)
    end

    ui.sameLine()
    if ui.button("Reload", {100, 30}) then
        updateDraft()
        ui.toast("Settings reloaded", ui.Icons.Confirm)
    end
end

ui.registerOnlineExtra(ui.Icons.SettingsAlt, "AI Traffic Controller", function() return true end, window, nil, ui.OnlineExtraFlags.Tool)
