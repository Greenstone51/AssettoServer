-- CollisionFlash: show a full-screen red block while your car is in contact with
-- another car, a barrier or any other solid object.
-- Settings come from the server plugin config (durationSeconds, opacity).
--
-- Detection runs in script.update, drawing runs in script.drawUI
-- (UI calls only render from drawUI, same as the FastTravel script).
-- Hits are written to the CSP log as "CollisionFlash: ..." to help with debugging.

local cfg = ac.configValues({
  durationSeconds = 0.35,
  opacity = 0.7,
})

local sim = ac.getSim()
local flashTimer = 0

local function trigger(source)
  if flashTimer <= 0 then
    ac.log('CollisionFlash: hit detected (' .. tostring(source) .. ')')
  end
  flashTimer = cfg.durationSeconds
end

-- Event based detection (guarded: if this CSP build lacks it, polling below still works)
local eventOk = pcall(function()
  ac.onCarCollision(0, function() trigger('event') end)
end)
ac.log('CollisionFlash: loaded, onCarCollision available = ' .. tostring(eventOk))

function script.update(dt)
  local car = ac.getCar(0)

  -- Polling: collisionDepth is above zero while the car is touching something
  if car ~= nil and (car.collisionDepth or 0) > 0 then
    trigger('collisionDepth')
  end

  if flashTimer > 0 then
    flashTimer = flashTimer - dt
  end
end

function script.drawUI(dt)
  if flashTimer <= 0 then return end

  local screenSize = vec2(sim.windowWidth, sim.windowHeight)
  ui.transparentWindow('collisionFlash', vec2(0, 0), screenSize, function()
    ui.drawRectFilled(vec2(0, 0), screenSize, rgbm(1, 0, 0, cfg.opacity))
  end)
end
