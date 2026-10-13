-- CollisionFlash: show a full-screen red block while your car is in contact with
-- another car, a barrier or any other solid object.
-- Settings come from the server plugin config (durationSeconds, opacity).

local cfg = ac.configValues({
  durationSeconds = 0.35,
  opacity = 0.7,
})

local flashTimer = 0

local function trigger()
  flashTimer = cfg.durationSeconds
end

-- Event based detection (guarded: if this CSP build lacks it, polling below still works)
pcall(function()
  ac.onCarCollision(0, trigger)
end)

local fullScreen = vec2(0, 0)

function script.update(dt)
  local car = ac.getCar(0)

  -- Polling fallback: collisionDepth is above zero while the car is touching something
  if car ~= nil and (car.collisionDepth or 0) > 0 then
    trigger()
  end

  if flashTimer > 0 then
    flashTimer = flashTimer - dt

    local size = ui.windowSize()
    ui.transparentWindow('collisionFlash', fullScreen, size, function()
      ui.drawRectFilled(fullScreen, size, rgbm(1, 0, 0, cfg.opacity))
    end)
  end
end
