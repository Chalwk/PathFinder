-- Pathfinder - Love2D
-- Tile-based puzzle: rotate road tiles to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

function love.conf(t)
    t.window.title = "PathFinder"
    t.window.width = 800
    t.window.height = 600
    t.window.minwidth = 800
    t.window.minheight = 600
    t.window.fullscreen = false
    t.window.resizable = true
    t.console = true
end
