-- CollisionFlash: red block while your car touches another car, a barrier or any solid object.
-- Detection always runs. Drawing and the settings UI obey /ui (all UIs) and /ui collisionflash (this one).

local PLUGIN_ID = 'collisionflash'

local cfg = ac.configValues({
  durationSeconds = 0.35,
  opacity = 0.7,
})

-- Per-player settings, saved on the player's PC
local store = ac.storage({
  tlx = 0, tly = 0, brx = 1, bry = 1,
  opacity = cfg.opacity,
  duration = cfg.durationSeconds,
})

local sim = ac.getSim()
local flashTimer = 0
local testTimer = 0
local allOn = true   -- toggled by "/ui"
local selfOn = true  -- toggled by "/ui collisionflash"

local function visible() return allOn and selfOn end

local toggleUiEvent = ac.OnlineEvent({
  ac.StructItem.key('AS_ToggleUi'),
  target = ac.StructItem.string(16),
}, function(sender, message)
  if sender ~= nil then return end
  local target = tostring(message.target or '')
  if target == '' or target == 'all' then
    allOn = not allOn
  elseif target == PLUGIN_ID then
    selfOn = not selfOn
  end
  ac.log('CollisionFlash: UI visible = ' .. tostring(visible()))
end)

local function trigger(source)
  if flashTimer <= 0 then
    ac.log('CollisionFlash: hit detected (' .. tostring(source) .. ')')
  end
  flashTimer = store.duration
end

local eventOk = pcall(function()
  ac.onCarCollision(0, function() trigger('event') end)
end)
ac.log('CollisionFlash: loaded, onCarCollision available = ' .. tostring(eventOk))

function script.update(dt)
  local car = ac.getCar(0)
  if car ~= nil and (car.collisionDepth or 0) > 0 then
    trigger('collisionDepth')
  end
  if flashTimer > 0 then flashTimer = flashTimer - dt end
  if testTimer > 0 then testTimer = testTimer - dt end
end

function script.drawUI(dt)
  if not visible() or (flashTimer <= 0 and testTimer <= 0) then return end

  local screenSize = vec2(sim.windowWidth, sim.windowHeight)
  local p1 = vec2(screenSize.x * store.tlx, screenSize.y * store.tly)
  local p2 = vec2(screenSize.x * store.brx, screenSize.y * store.bry)

  ui.transparentWindow('collisionFlash', vec2(0, 0), screenSize, function()
    ui.drawRectFilled(p1, p2, rgbm(1, 0, 0, store.opacity))
  end)
end

-- ---------- Settings UI (dark panel, red accent) ----------

local styleSpec = {
  { 'Text', rgbm(0.92, 0.92, 0.92, 1) },
  { 'FrameBg', rgbm(0.12, 0.12, 0.14, 0.95) },
  { 'FrameBgHovered', rgbm(0.2, 0.12, 0.12, 0.95) },
  { 'FrameBgActive', rgbm(0.28, 0.12, 0.12, 0.95) },
  { 'SliderGrab', rgbm(0.9, 0.15, 0.15, 1) },
  { 'SliderGrabActive', rgbm(1, 0.3, 0.3, 1) },
  { 'Button', rgbm(0.6, 0.1, 0.1, 0.9) },
  { 'ButtonHovered', rgbm(0.85, 0.15, 0.15, 1) },
  { 'ButtonActive', rgbm(1, 0.25, 0.25, 1) },
}

local function pushStyle()
  local n = 0
  for _, s in ipairs(styleSpec) do
    local key = ui.StyleColor[s[1]]
    if key ~= nil then
      ui.pushStyleColor(key, s[2])
      n = n + 1
    end
  end
  return n
end

local function pctSlider(label, key, lo, hi)
  local v, changed = ui.slider('##cf_' .. key, store[key] * 100, lo, hi, label .. ': %.0f%%')
  if changed then store[key] = v / 100 end
end

local function settingsWindow()
  if not visible() then
    ui.textWrapped('UI hidden. Type /ui to show it again.')
    return
  end

  local pushed = pushStyle()

  ui.pushFont(ui.Font.Title)
  ui.textColored('COLLISION FLASH', rgbm(0.95, 0.2, 0.2, 1))
  ui.popFont()
  ui.separator()

  ui.text('Box position (screen %)')
  pctSlider('Top-left X', 'tlx', 0, 98)
  pctSlider('Top-left Y', 'tly', 0, 98)
  pctSlider('Bottom-right X', 'brx', 2, 100)
  pctSlider('Bottom-right Y', 'bry', 2, 100)

  -- keep the second point below/right of the first
  if store.brx < store.tlx + 0.02 then store.brx = math.min(1, store.tlx + 0.02) end
  if store.bry < store.tly + 0.02 then store.bry = math.min(1, store.tly + 0.02) end

  ui.separator()
  ui.text('Look')
  pctSlider('Opacity', 'opacity', 0, 100)
  local d, dChanged = ui.slider('##cf_duration', store.duration, 0.05, 3, 'Duration: %.2f s')
  if dChanged then store.duration = d end

  ui.separator()
  if ui.button('Test flash') then testTimer = 1.5 end
  ui.sameLine()
  if ui.button('Reset') then
    store.tlx, store.tly, store.brx, store.bry = 0, 0, 1, 1
    store.opacity, store.duration = cfg.opacity, cfg.durationSeconds
  end

  ui.textWrapped('/ui hides every plugin UI, /ui collisionflash only this one.')

  if pushed > 0 then ui.popStyleColor(pushed) end
end

ui.registerOnlineExtra(ui.Icons.SettingsAlt, 'CollisionFlash', function() return true end, settingsWindow, nil, ui.OnlineExtraFlags.Tool)
