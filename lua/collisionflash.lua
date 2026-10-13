local function pctSlider(label, key, lo, hi)
    -- Implementation of pctSlider function
end

local function updateCollisionFlash(sessionId, isInPits)
    local config = ac.getPluginConfig("CollisionFlashPlugin")
    local alwaysOnInPits = config.AlwaysOnInPits

    if alwaysOnInPits and isInPits then
        -- Draw the box always when the client is in Pits
        ac.sendLuaMessage("CollisionFlashPlugin", "drawBox", sessionId, true)
    else
        -- Normal behavior
        ac.sendLuaMessage("CollisionFlashPlugin", "drawBox", sessionId, false)
    end
end

ac.addLuaMessageListener("CollisionFlashPlugin", "updateCollisionFlash", updateCollisionFlash)

-- Placeholder for other Lua code
