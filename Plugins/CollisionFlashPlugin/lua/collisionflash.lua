-- CollisionFlash: collision indicator plus configurable proximity warning for REAL online players.
-- Drawing/settings obey /ui (all UIs) and /ui collisionflash (this UI).

local PLUGIN_ID = 'collisionflash'
local cfg = ac.configValues({
  durationSeconds = 0.35, opacity = 0.7, showInPits = false,
  keepVisibleUnderSpeed = false, speedLimitKph = 30,
  proximityEnabled = false, proximityDistance = 15,
  proximityPlayers = '', proximityReverse = false,
})
local store = ac.storage({
  tlx = 0.42, tly = 0.42, brx = 0.58, bry = 0.58,
  opacity = cfg.opacity, duration = cfg.durationSeconds,
  showInPits = cfg.showInPits, keepVisibleUnderSpeed = cfg.keepVisibleUnderSpeed,
  speedLimitKph = cfg.speedLimitKph,
  proximityEnabled = cfg.proximityEnabled, proximityDistance = cfg.proximityDistance,
  proximityPlayers = cfg.proximityPlayers, proximityReverse = cfg.proximityReverse,
})
local flashTimer, testTimer = 0, 0
local allOn, selfOn = true, true
local proximityActive = false
local proximityReverseShow = false
local resizeEdge = nil
local resizeWasDown = false
local MIN_BOX = 0.02

local function visible() return allOn and selfOn end
local toggleUiEvent = ac.OnlineEvent({
  ac.StructItem.key('AS_ToggleUi'), target = ac.StructItem.string(16),
}, function(sender, message)
  if sender ~= nil then return end
  local target = tostring(message.target or '')
  if target == '' or target == 'all' then allOn = not allOn
  elseif target == PLUGIN_ID then selfOn = not selfOn end
end)

local function trigger(source)
  flashTimer = math.max(flashTimer, store.duration)
end
pcall(function() ac.onCarCollision(0, function() trigger('event') end) end)

local function isInPits(car)
  return car ~= nil and (car.isInPit or car.isInPitlane or false) == true
end

local function allowedPlayer(name)
  local filter = tostring(store.proximityPlayers or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
  if filter == '' or filter == '*' then return true end
  name = tostring(name or ''):lower()
  for token in filter:gmatch('[^,;]+') do
    token = token:gsub('^%s+', ''):gsub('%s+$', '')
    if token ~= '' and name == token then return true end
  end
  return false
end

-- Iterate actual cars and reject AI-controlled cars explicitly. Distance is squared to avoid sqrt.
local function nearbyRealPlayer(myCar)
  if not store.proximityEnabled or myCar == nil or myCar.position == nil then return false end
  local limit2 = math.max(0, store.proximityDistance) ^ 2
  local sim = ac.getSim()
  local count = sim and sim.carsCount or 0
  for i = 1, count - 1 do
    local other = ac.getCar(i)
    if other ~= nil and other.position ~= nil and other.isAIControlled ~= true then
      local name = other.driverName or other.name or ''
      if allowedPlayer(name) then
        local dx = myCar.position.x - other.position.x
        local dy = myCar.position.y - other.position.y
        local dz = myCar.position.z - other.position.z
        if dx * dx + dy * dy + dz * dz <= limit2 then return true end
      end
    end
  end
  return false
end

function script.update(dt)
  local car = ac.getCar(0)
  if car ~= nil and (car.collisionDepth or 0) > 0 then trigger('collisionDepth') end
  local nearby = nearbyRealPlayer(car)
  if nearby and not proximityActive and not store.proximityReverse then trigger('player proximity') end
  proximityActive = nearby
  -- Reverse mode is a continuous state: keep the indicator visible whenever no
  -- eligible real player is inside the configured radius (not a one-shot flash).
  proximityReverseShow = store.proximityEnabled and store.proximityReverse and car ~= nil and not nearby
  flashTimer = math.max(0, flashTimer - dt)
  testTimer = math.max(0, testTimer - dt)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function drawIndicator(screenSize)
  local p1 = vec2(screenSize.x * store.tlx, screenSize.y * store.tly)
  local p2 = vec2(screenSize.x * store.brx, screenSize.y * store.bry)
  ui.drawRectFilled(p1, p2, rgbm(1, 0, 0, store.opacity))

  -- Drag any edge of the rectangle to resize. Edges are screen-relative and remain draggable
  -- even while the indicator is flashing; hold the left mouse button on an edge.
  local mouse = ui.mousePos()
  local down = ui.mouseDown(ui.MouseButton.Left)
  local scale = math.max(8, math.min(screenSize.x, screenSize.y) * 0.012)
  if down and not resizeWasDown then
    local left = math.abs(mouse.x - p1.x) <= scale and mouse.y >= p1.y - scale and mouse.y <= p2.y + scale
    local right = math.abs(mouse.x - p2.x) <= scale and mouse.y >= p1.y - scale and mouse.y <= p2.y + scale
    local top = math.abs(mouse.y - p1.y) <= scale and mouse.x >= p1.x - scale and mouse.x <= p2.x + scale
    local bottom = math.abs(mouse.y - p2.y) <= scale and mouse.x >= p1.x - scale and mouse.x <= p2.x + scale
    if left then resizeEdge = 'left'
    elseif right then resizeEdge = 'right'
    elseif top then resizeEdge = 'top'
    elseif bottom then resizeEdge = 'bottom' end
  elseif not down then
    resizeEdge = nil
  end
  if down and resizeEdge ~= nil then
    local x, y = clamp(mouse.x / screenSize.x, 0, 1), clamp(mouse.y / screenSize.y, 0, 1)
    if resizeEdge == 'left' then store.tlx = math.min(x, store.brx - MIN_BOX)
    elseif resizeEdge == 'right' then store.brx = math.max(x, store.tlx + MIN_BOX)
    elseif resizeEdge == 'top' then store.tly = math.min(y, store.bry - MIN_BOX)
    elseif resizeEdge == 'bottom' then store.bry = math.max(y, store.tly + MIN_BOX) end
    store.tlx, store.tly = clamp(store.tlx, 0, 1 - MIN_BOX), clamp(store.tly, 0, 1 - MIN_BOX)
    store.brx, store.bry = clamp(store.brx, store.tlx + MIN_BOX, 1), clamp(store.bry, store.tly + MIN_BOX, 1)
  end
  resizeWasDown = down
end

function script.drawUI(dt)
  if not visible() then return end
  local car = ac.getCar(0)
  local inPits = isInPits(car)
  local show = inPits and store.showInPits or (not inPits and flashTimer > 0)
  if store.keepVisibleUnderSpeed and not inPits and car ~= nil and (car.speedKmh or 0) <= store.speedLimitKph then show = true end
  if testTimer > 0 or proximityReverseShow then show = true end
  if not show then return end
  local screenSize = ac.getUI().windowSize
  ui.transparentWindow('collisionFlash', vec2(0, 0), screenSize, function()
    drawIndicator(screenSize)
  end)
end

local styleSpec = {
  { 'Text', rgbm(0.92, 0.92, 0.92, 1) }, { 'FrameBg', rgbm(0.12, 0.12, 0.14, 0.95) },
  { 'FrameBgHovered', rgbm(0.2, 0.12, 0.12, 0.95) }, { 'FrameBgActive', rgbm(0.28, 0.12, 0.12, 0.95) },
  { 'SliderGrab', rgbm(0.9, 0.15, 0.15, 1) }, { 'SliderGrabActive', rgbm(1, 0.3, 0.3, 1) },
  { 'Button', rgbm(0.6, 0.1, 0.1, 0.9) }, { 'ButtonHovered', rgbm(0.85, 0.15, 0.15, 1) },
  { 'ButtonActive', rgbm(1, 0.25, 0.25, 1) },
}
local function pushStyle()
  local n = 0
  for _, s in ipairs(styleSpec) do
    local key = ui.StyleColor[s[1]]
    if key ~= nil then ui.pushStyleColor(key, s[2]); n = n + 1 end
  end
  return n
end
local function pctSlider(label, key, lo, hi)
  local v, changed = ui.slider('##cf_' .. key, store[key] * 100, lo, hi, label .. ': %.0f%%')
  if changed then store[key] = v / 100 end
end
local function settingsWindow()
  if not visible() then ui.textWrapped('UI hidden. Type /ui to show it again.'); return end
  local pushed = pushStyle()
  ui.pushFont(ui.Font.Title); ui.textColored('COLLISION FLASH', rgbm(0.95, 0.2, 0.2, 1)); ui.popFont()
  ui.separator()
  ui.textWrapped('Resize: show the indicator, then drag its top, bottom, left or right edge with the mouse.')
  ui.text('Box position / size (screen %)')
  pctSlider('Left', 'tlx', 0, 98); pctSlider('Top', 'tly', 0, 98)
  pctSlider('Right', 'brx', 2, 100); pctSlider('Bottom', 'bry', 2, 100)
  if store.brx < store.tlx + MIN_BOX then store.brx = math.min(1, store.tlx + MIN_BOX) end
  if store.bry < store.tly + MIN_BOX then store.bry = math.min(1, store.tly + MIN_BOX) end
  ui.separator(); ui.text('Look')
  pctSlider('Opacity', 'opacity', 0, 100)
  local d, dc = ui.slider('##cf_duration', store.duration, 0.05, 3, 'Duration: %.2f s')
  if dc then store.duration = d end
  ui.separator(); ui.text('Pits')
  if ui.checkbox('Show in pits', store.showInPits) then store.showInPits = not store.showInPits end
  ui.separator(); ui.text('Speed limit')
  if ui.checkbox('Keep visible under speed limit', store.keepVisibleUnderSpeed) then store.keepVisibleUnderSpeed = not store.keepVisibleUnderSpeed end
  local s, sc = ui.slider('##cf_speedlimit', store.speedLimitKph, 0, 300, 'Speed limit: %.0f km/h')
  if sc then store.speedLimitKph = s end
  ui.separator(); ui.text('Real-player proximity warning')
  if ui.checkbox('Enable proximity warning', store.proximityEnabled) then store.proximityEnabled = not store.proximityEnabled end
  local dist, distChanged = ui.slider('##cf_proximity_distance', store.proximityDistance, 1, 500, 'Distance: %.0f m')
  if distChanged then store.proximityDistance = dist end
  local names, namesChanged = ui.inputText('##cf_proximity_players', tostring(store.proximityPlayers or ''), 256)
  if namesChanged then store.proximityPlayers = names end
  ui.textWrapped('Player filter: blank or * = everyone; otherwise enter exact driver names separated by commas. AI traffic is ignored.')
  if ui.checkbox('Reverse: show continuously when NO matching player is nearby', store.proximityReverse) then
    store.proximityReverse = not store.proximityReverse
    proximityActive = false
  end
  ui.textWrapped('Reverse off: flash when a matching player enters the radius. Reverse on: stay visible while no matching real player is within range.')
  if ui.button('Test flash') then testTimer = 1.5 end
  ui.sameLine()
  if ui.button('Reset') then
    store.tlx, store.tly, store.brx, store.bry = 0.42, 0.42, 0.58, 0.58
    store.opacity, store.duration = cfg.opacity, cfg.durationSeconds
    store.showInPits, store.keepVisibleUnderSpeed, store.speedLimitKph = cfg.showInPits, cfg.keepVisibleUnderSpeed, cfg.speedLimitKph
    store.proximityEnabled, store.proximityDistance, store.proximityPlayers, store.proximityReverse = cfg.proximityEnabled, cfg.proximityDistance, cfg.proximityPlayers, cfg.proximityReverse
    proximityActive, proximityReverseShow = false, false
  end
  ui.textWrapped('/ui hides every plugin UI, /ui collisionflash only this one.')
  if pushed > 0 then ui.popStyleColor(pushed) end
end
ui.registerOnlineExtra(ui.Icons.SettingsAlt, 'CollisionFlash', function() return true end, settingsWindow, nil, ui.OnlineExtraFlags.Tool)
