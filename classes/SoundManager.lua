-- Pathfinder - Love2D
-- Tile-based puzzle: rotate road tiles to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new()
    local instance = setmetatable({
        sounds = {
            rotate = love.audio.newSource("assets/sounds/rotate.mp3", "static"),
            connect = love.audio.newSource("assets/sounds/connect.mp3", "static"),
            background = love.audio.newSource("assets/sounds/background.mp3", "stream")
        }
    }, SoundManager)

    instance:setVolume(instance.sounds.background, 0.5)
    instance:setVolume(instance.sounds.rotate, 1)
    instance:setVolume(instance.sounds.connect, 1)

    instance:play("background", true)

    return instance
end

function SoundManager:play(soundName, loop)
    if loop then self.sounds[soundName]:setLooping(true) end

    -- nil check for sound:
    if not self.sounds[soundName] then return end

    self.sounds[soundName]:stop()
    self.sounds[soundName]:play()
end

function SoundManager:setVolume(sound, volume)
    sound:setVolume(volume)
end

return SoundManager
