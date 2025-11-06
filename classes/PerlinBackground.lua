-- Pathfinder - Love2D
-- Tile-based puzzle: rotate road tiles to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_sin = math.sin
local math_cos = math.cos
local math_floor = math.floor
local math_random = math.random
local math_randomseed = math.randomseed
local os_time = os.time

local rectangle = love.graphics.rectangle
local setCanvas = love.graphics.setCanvas
local clear = love.graphics.clear
local line = love.graphics.line
local draw = love.graphics.draw
local push = love.graphics.push
local pop = love.graphics.pop

local PerlinBackground = {}
PerlinBackground.__index = PerlinBackground

local SCREEN_WIDTH, SCREEN_HEIGHT

-- Precompute gradient vectors for 2D noise
local GRADIENTS = {
    { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 },
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }
}

function PerlinBackground.new(colors)
    local instance = setmetatable({}, PerlinBackground)

    instance.colors = colors
    instance.time = 0
    instance.noiseScale = 0.02
    instance.speed = 0.5
    instance.cellSize = 4
    instance.canvas = nil
    instance.lastTime = 0
    instance.updateInterval = 0.05 -- Update canvas every 50ms

    -- Generate permutation table
    instance.perm = {}
    math_randomseed(os_time())
    for i = 0, 255 do
        instance.perm[i] = i
    end

    -- Fisher-Yates shuffle
    for i = 255, 1, -1 do
        local j = math_random(0, i)
        instance.perm[i], instance.perm[j] = instance.perm[j], instance.perm[i]
    end

    -- Duplicate for overflow protection
    for i = 0, 255 do
        instance.perm[256 + i] = instance.perm[i]
    end

    return instance
end

local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(t, a, b)
    return a + t * (b - a)
end

local function grad2D(hash, x, y)
    local grad = GRADIENTS[(hash % 8) + 1]
    return grad[1] * x + grad[2] * y
end

local function noise2D(self, x, y)
    local X = math_floor(x) % 255
    local Y = math_floor(y) % 255

    x = x - math_floor(x)
    y = y - math_floor(y)

    local u = fade(x)
    local v = fade(y)

    local A = self.perm[X] + Y
    local AA = self.perm[A]
    local AB = self.perm[A + 1]
    local B = self.perm[X + 1] + Y
    local BA = self.perm[B]
    local BB = self.perm[B + 1]

    return lerp(v, lerp(u,
            grad2D(self.perm[AA], x, y),
            grad2D(self.perm[BA], x - 1, y)),
        lerp(u,
            grad2D(self.perm[AB], x, y - 1),
            grad2D(self.perm[BB], x - 1, y - 1)))
end

local function fractalNoise2D(self, x, y, octaves, persistence)
    local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0

    octaves = octaves or 2
    persistence = persistence or 0.5

    for _ = 0, octaves - 1 do
        total = total + noise2D(self, x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end

    return total / maxValue
end

local function createCanvas(self)
    self.canvas = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    self.canvasWidth = SCREEN_WIDTH
    self.canvasHeight = SCREEN_HEIGHT
end

local function updateCanvas(self)
    if not self.canvas or self.canvasWidth ~= SCREEN_WIDTH or self.canvasHeight ~= SCREEN_HEIGHT then
        createCanvas(self)
    end

    local currentTime = love.timer.getTime()
    -- Skip update if not enough time has passed
    if currentTime - self.lastTime < self.updateInterval then return end

    setCanvas(self.canvas)
    clear(0, 0, 0, 0) -- Clear with transparent

    local cellSize = self.cellSize

    -- Batch draw calls by color to minimize state changes
    for y = 0, SCREEN_HEIGHT, cellSize do
        for x = 0, SCREEN_WIDTH, cellSize do
            local nx = x * self.noiseScale
            local ny = y * self.noiseScale

            local noiseValue = fractalNoise2D(self, nx + self.time, ny, 3, 0.7)
            if noiseValue > 0.8 then
                self.colors:setColor("white", 0.9)
                rectangle("fill", x, y, cellSize, cellSize)
            elseif noiseValue > 0.6 then
                self.colors:setColor("neon_green_glow", 0.8)
                rectangle("fill", x, y, cellSize, cellSize)
            elseif noiseValue > 0.4 then
                self.colors:setColor("lime_green", 0.5)
                rectangle("fill", x, y, cellSize, cellSize)
            elseif noiseValue > 0.2 then
                self.colors:setColor("medium_blue", 0.3)
                rectangle("fill", x, y, cellSize, cellSize)
            elseif noiseValue > -0.1 then
                self.colors:setColor("moonlit_charcoal", 0.4)
                rectangle("fill", x, y, cellSize, cellSize)
            end
        end
    end

    setCanvas()
    self.lastTime = currentTime
end

local function drawLaserGrid(self)
    local pulse = (math_sin(self.time * 3) + 1) * 0.5
    local gridSpacing = 80

    -- Use immediate mode for grid since it's relatively few lines
    push("all")

    -- Vertical lines
    self.colors:setColor("neon_green", 0.1 + pulse * 0.1)
    for x = 0, SCREEN_WIDTH, gridSpacing do
        local offset = math_sin(self.time * 2 + x * 0.01) * 10
        line(x + offset, 0, x + offset, SCREEN_HEIGHT)
    end

    -- Horizontal lines
    for y = 0, SCREEN_HEIGHT, gridSpacing do
        local offset = math_cos(self.time * 2 + y * 0.01) * 10
        line(0, y + offset, SCREEN_WIDTH, y + offset)
    end

    pop()
end

function PerlinBackground:update(dt)
    SCREEN_WIDTH, SCREEN_HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()
    self.time = self.time + dt * self.speed
    updateCanvas(self)
end

function PerlinBackground:draw()
    if self.canvas then draw(self.canvas, 0, 0) end
    drawLaserGrid(self)
end

-- Force recreation on next update
function PerlinBackground:resize() self.canvas = nil end

return PerlinBackground
