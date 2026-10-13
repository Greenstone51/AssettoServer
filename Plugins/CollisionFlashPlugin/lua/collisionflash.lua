-- CollisionFlash: show a red block while your car is in contact with another car,
-- a barrier or any other solid object. Detection always runs; only the drawing
-- can be toggled in-game with the /ui chat command.

local PLUGIN_ID = 'collisionflash'

local cfg = ac.configValues({
  durationSeconds = 0.35,
  opacity = 0.7,
  topLeftX = 0,
  topLeftY = 0,
  bottomRightX = 1,
  bottomRightY = 1,
})

local sim = ac.getSim()
local flashTimer = 0
local uiEnabled = true

-- /ui toggles every plugin UI, "/ui collisionflash" only this one
local toggleUiEvent = ac.OnlineEvent({
  ac.StructItem.key('AS_ToggleUi'),
  target = ac.StructItem.string(16),
}, function(sender, message)
  if sender ~= nil then return end
  local target = tostring(message.target or '')
  if target == '' or target == 'all' or target == PLUGIN_ID then
    uiEnabled = not uiEnabled
    ui.toast(ui.Icons.Info, 'CollisionFlash overlay ' .. (uiEnabled and 'ON' or 'OFF'))
  end
end)

local function trigger(source)
  if flashTimer <= 0 then
    ac.log('CollisionFlash: hit detected (' .. tostring(source) .. ')')
  end
  flashTimer = cfg.durationSeconds
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
  if flashTimer > 0 then
    flashTimer = flashTimer - dt
  end
end

function script.drawUI(dt)
  if not uiEnabled or flashTimer <= 0 then return end

  local screenSize = vec2(sim.windowWidth, sim.windowHeight)
  local p1 = vec2(screenSize.x * cfg.topLeftX, screenSize.y * cfg.topLeftY)
  local p2 = vec2(screenSize.x * cfg.bottomRightX, screenSize.y * cfg.bottomRightY)

  ui.transparentWindow('collisionFlash', vec2(0, 0), screenSize, function()
    ui.drawRectFilled(p1, p2, rgbm(1, 0, 0, cfg.opacity))
  end)
end
