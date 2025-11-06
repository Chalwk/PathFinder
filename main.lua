-- Pathfinder - Love2D
-- Tile-based puzzle: rotate road tiles to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Grid = require("classes.Grid")
local Game = require("classes.Game")
local Colors = require("classes.Colors")
local SoundManager = require("classes.SoundManager")
local LevelGenerator = require("classes.LevelGenerator")
local PerlinBackground = require("classes.PerlinBackground")

local game, grid, levelGenerator, background

function love.load()
    local soundManager = SoundManager.new()

    levelGenerator = LevelGenerator.new()

    local colors = Colors.new()
    grid = Grid.new(soundManager, colors)
    game = Game.new(levelGenerator, grid, soundManager, colors)

    background = PerlinBackground.new(colors)

    local w, h = love.graphics.getDimensions()

    -- Generate first level first, THEN resize
    game:generateLevel(1)

    game:onResize(w, h)
end

function love.resize(w, h)
    game:onResize(w, h)
    background:resize()
end

function love.update(dt)
    background:update(dt)
    game:update(dt)
end

function love.draw()
    background:draw()
    game:draw()
end

function love.mousepressed(x, y, button)
    game:onMousePressed(x, y, button)
end

function love.keypressed(key)
    game:onKeyPressed(key)
end
