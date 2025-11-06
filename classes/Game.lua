-- Pathfinder - Love2D
-- Tile-based puzzle: rotate road tiles to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local HEADER_TEXT = "Level: %d"
local TIMER_TEXT = "Time: %02d:%02d"
local WIN_TEXT = "ALL TARGETS SOLVED! Press N for next level. Time: %02d:%02d"
local SIDE_TEXT = "Targets: %d/%d"
local FOOTER_TEXT = "PathFinder - Copyright (c) 2025 Jericho Crosby (Chalwk)"

local math_sin = math.sin
local math_floor = math.floor
local string_format = string.format

local getTime = love.timer.getTime
local setFont = love.graphics.setFont
local love_print = love.graphics.print
local love_printf = love.graphics.printf
local rectangle = love.graphics.rectangle
local setLineWidth = love.graphics.setLineWidth

local Game = {}
Game.__index = Game

function Game.new(levelGenerator, grid, soundManager, colors)
    local instance = setmetatable({}, Game)

    instance.levelGenerator = levelGenerator
    instance.grid = grid
    instance.currentLevel = 1
    instance.selected = { x = nil, y = nil }
    instance.font = love.graphics.newFont(16)
    instance.smallFont = love.graphics.newFont(14)
    instance.sounds = soundManager
    instance.colors = colors
    instance.winningState = false

    instance.levelStartTime = 0
    instance.currentTime = 0
    instance.levelBestTime = nil
    instance.timerRunning = false

    return instance
end

function Game:generateLevel(levelIndex)
    self.currentLevel = levelIndex or self.currentLevel
    local levelData = self.levelGenerator:generateLevel(self.currentLevel)
    self.grid:loadLevel(levelData)
    self.selected = { x = nil, y = nil }
    self.winningState = false

    -- Reset and start timer
    self.levelStartTime = love.timer.getTime()
    self.currentTime = 0
    self.timerRunning = true
end

function Game:onResize(w, h)
    self.grid:calculateTileSize(w, h)
end

function Game:draw()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    self.grid:draw()

    setFont(self.font)
    self.colors:setColor("white")

    love_printf(string_format(HEADER_TEXT, self.currentLevel), 8, 6, screenWidth - 16, "center")

    -- Display timer in top-right corner
    local minutes = math_floor(self.currentTime / 60)
    local seconds = math_floor(self.currentTime % 60)
    local timerText = string_format(TIMER_TEXT, minutes, seconds)

    setFont(self.smallFont)
    love_print(timerText, screenWidth - 100, 6)

    -- Display best time if available
    if self.levelBestTime then
        local bestMinutes = math_floor(self.levelBestTime / 60)
        local bestSeconds = math_floor(self.levelBestTime % 60)
        local bestTimeText = string_format("Best: %02d:%02d", bestMinutes, bestSeconds)
        love_print(bestTimeText, screenWidth - 100, 24)
    end

    local hitCount, totalTargets = self.grid:getTargetProgress()

    setFont(self.smallFont)
    love_print(string_format(SIDE_TEXT, hitCount, totalTargets), 8, 32)

    -- Update winning state based on current progress
    if totalTargets > 0 and hitCount == totalTargets then
        self.winningState = true
    else
        self.winningState = false
    end

    if self.winningState then
        setFont(self.font)
        self.colors:setColor("neon_green_glow")
        local winMinutes = math_floor(self.currentTime / 60)
        local winSeconds = math_floor(self.currentTime % 60)
        local winText = string_format(WIN_TEXT, winMinutes, winSeconds)
        love_printf(winText, 0, 48, screenWidth, "center")
    end

    -- Draw controls help
    setFont(self.smallFont)
    self.colors:setColor("white", 0.7)
    love_print("Controls:", 8, screenHeight - 65)
    love_print("Left/Right click: Rotate tile", 8, screenHeight - 50)
    love_print("Q/E: Rotate selected tile", 8, screenHeight - 35)

    self.colors:setColor("white", 0.7)
    love_print("R: Restart level | N: Next level", 8, screenHeight - 20)

    self.colors:setColor("white", 0.7)
    love_print(FOOTER_TEXT, screenWidth / 2 - 5, screenHeight - 20)

    -- Draw selection indicator
    if self.selected.x and self.selected.y then
        local sx = self.grid.gridOffsetX + (self.selected.x - 1) * self.grid.tileSize
        local sy = self.grid.gridOffsetY + (self.selected.y - 1) * self.grid.tileSize

        self.colors:setColor("selection_glow", 0.8 + 0.2 * math_sin(getTime() * 6))
        setLineWidth(3)
        rectangle("line", sx, sy, self.grid.tileSize - 1, self.grid.tileSize - 1)
        setLineWidth(1)
    end
end

function Game:update(dt)
    self.grid:update(dt)

    -- Update timer if running and not won
    if self.timerRunning and not self.winningState then
        self.currentTime = love.timer.getTime() - self.levelStartTime
    end

    -- Check for win condition each frame
    local hitCount, totalTargets = self.grid:getTargetProgress()
    if totalTargets > 0 and hitCount == totalTargets and not self.winningState then
        self.winningState = true
        self.timerRunning = false -- Stop timer when level is completed
        self.sounds:play("win")

        -- Check for best time
        if not self.levelBestTime or self.currentTime < self.levelBestTime then
            self.levelBestTime = self.currentTime
        end
    end
end

function Game:onMousePressed(x, y, button)
    local gx, gy = self.grid:screenToGrid(x, y)
    if not gx then
        self.selected.x, self.selected.y = nil, nil
        return
    end

    if button == 1 then
        -- Left click: select and rotate clockwise
        self.selected.x, self.selected.y = gx, gy
        self.grid:rotateTile(gx, gy, 1)
        self.winningState = false
    elseif button == 2 then
        -- Right click: select and rotate counter-clockwise
        self.selected.x, self.selected.y = gx, gy
        self.grid:rotateTile(gx, gy, -1)
        self.winningState = false
    end
end

function Game:onKeyPressed(key)
    if key == 'r' then
        -- Restart current level - timer will reset in generateLevel
        self:generateLevel(self.currentLevel)
        self.winningState = false
        self.sounds:play("restart")
    elseif key == 'n' then
        -- Next level - timer will reset in generateLevel
        local nextLevel = self.currentLevel + 1
        self:generateLevel(nextLevel)
        self.winningState = false
        self.sounds:play("level_change")
    elseif key == 'p' then -- todo: fix this
        -- Previous level
        local prevLevel = self.currentLevel - 1
        self:generateLevel(prevLevel)
        self.winningState = false
        self.sounds:play("level_change")
    elseif key == 'escape' then
        love.event.quit()
    elseif key == 'q' or key == 'e' then
        -- Rotate selected tile with Q/E keys
        if self.selected.x and self.selected.y then
            local delta = (key == 'e') and 1 or -1
            self.grid:rotateTile(self.selected.x, self.selected.y, delta)
            self.winningState = false
        end
    elseif key == '1' then
        -- Jump to level 1
        self:generateLevel(1)
        self.winningState = false
        self.sounds:play("level_change")
    elseif key == '2' then
        -- Jump to level 5
        self:generateLevel(5)
        self.winningState = false
        self.sounds:play("level_change")
    elseif key == '3' then
        -- Jump to level 10
        self:generateLevel(10)
        self.winningState = false
        self.sounds:play("level_change")
    end
end

return Game
