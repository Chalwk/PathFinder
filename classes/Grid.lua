-- Pathfinder - Love2D
-- Tile-based puzzle: rotate road tiles to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_floor = math.floor
local math_sin = math.sin
local math_min = math.min
local math_max = math.max

local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove

local setLineWidth = love.graphics.setLineWidth
local rectangle = love.graphics.rectangle
local circle = love.graphics.circle
local line = love.graphics.line
local polygon = love.graphics.polygon

local Grid = {}
Grid.__index = Grid

local DIRS = { 0, 1, 2, 3 }

function Grid.new(soundManager, colors)
    local instance = setmetatable({}, Grid)

    instance.grid = {}
    instance.beams = {}
    instance.targetsHit = {}
    instance.lasers = {}

    instance.gw, instance.gh = 9, 9
    instance.tileSize = 48
    instance.gridOffsetX, instance.gridOffsetY = 40, 40

    instance.sounds = soundManager
    instance.colors = colors

    instance.previouslyHit = {}

    -- Multiple beam tracking
    instance.activeBeamPaths = {}
    instance.beamProgress = {}  -- Progress for each beam
    instance.previouslyHit = {} -- Track hit state for each target

    -- For gradual beam propagation
    instance.beamProgress = 0
    instance.beamSpeed = 7.2 -- tiles per second
    instance.activeBeamPath = {}
    instance.targetX, instance.targetY = nil, nil

    -- Directions: 0=up, 1=right, 2=down, 3=left
    instance.dirVecsX = { 0, 1, 0, -1 }
    instance.dirVecsY = { -1, 0, 1, 0 }

    -- Road tile connection patterns (for each rotation 0-3)
    instance.roadTileTypes = {
        straight = {
            { up = true,  right = false, down = true,  left = false }, -- rotation 0: vertical
            { up = false, right = true,  down = false, left = true },  -- rotation 1: horizontal
            { up = true,  right = false, down = true,  left = false }, -- rotation 2: vertical (same as 0)
            { up = false, right = true,  down = false, left = true }   -- rotation 3: horizontal (same as 1)
        },
        curve = {
            { up = true,  right = true,  down = false, left = false }, -- rotation 0: up-right
            { up = false, right = true,  down = true,  left = false }, -- rotation 1: right-down
            { up = false, right = false, down = true,  left = true },  -- rotation 2: down-left
            { up = true,  right = false, down = false, left = true }   -- rotation 3: left-up
        },
        t_junction = {
            { up = true,  right = true,  down = true,  left = false }, -- rotation 0: missing left
            { up = true,  right = true,  down = false, left = true },  -- rotation 1: missing down
            { up = false, right = true,  down = true,  left = true },  -- rotation 2: missing up
            { up = true,  right = false, down = true,  left = true }   -- rotation 3: missing right
        },
        cross = {
            { up = true, right = true, down = true, left = true }, -- rotation 0-3: all directions
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true }
        },
        dead_end = {
            -- Dead-end: can only enter and exit through the open end (same direction)
            { up = true,  right = false, down = false, left = false }, -- rotation 0: up only
            { up = false, right = true,  down = false, left = false }, -- rotation 1: right only
            { up = false, right = false, down = true,  left = false }, -- rotation 2: down only
            { up = false, right = false, down = false, left = true }   -- rotation 3: left only
        },
        laser = {                                                      -- Laser acts as a dead_end that emits light
            { up = true,  right = false, down = false, left = false },
            { up = false, right = true,  down = false, left = false },
            { up = false, right = false, down = true,  left = false },
            { up = false, right = false, down = false, left = true }
        },
        target = { -- Target receives light from any direction
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true }
        }
    }

    return instance
end

local function inBounds(self, x, y)
    return x >= 1 and x <= self.gw and y >= 1 and y <= self.gh
end

local function tileAt(self, x, y)
    if not inBounds(self, x, y) then return nil end
    return self.grid[y][x]
end

local function getTileCenter(self, x, y)
    return self.gridOffsetX + (x - 1) * self.tileSize + self.tileSize / 2,
        self.gridOffsetY + (y - 1) * self.tileSize + self.tileSize / 2
end

local function canBeamTravelThroughTile(self, tile, incomingDir, outgoingDir)
    if not tile or tile.type == "empty" then return false end

    local connections = self.roadTileTypes[tile.type][tile.rotation + 1]

    -- Check if we can enter from incoming direction
    local canEnter = false
    if incomingDir == 0 then canEnter = connections.up end
    if incomingDir == 1 then canEnter = connections.right end
    if incomingDir == 2 then canEnter = connections.down end
    if incomingDir == 3 then canEnter = connections.left end

    if not canEnter then return false end

    -- Check if we can exit through outgoing direction (if specified)
    if outgoingDir then
        local canExit = false
        if outgoingDir == 0 then canExit = connections.up end
        if outgoingDir == 1 then canExit = connections.right end
        if outgoingDir == 2 then canExit = connections.down end
        if outgoingDir == 3 then canExit = connections.left end

        return canExit
    end

    return true
end

local function findShortestPath(self, startX, startY, targetColor)
    local queue = {}
    local visited = {}

    -- Initialize with laser starting point
    local startKey = startY * (self.gw * 5) + startX * 5 + 4 -- 4 for no incoming direction
    visited[startKey] = true

    table_insert(queue, {
        x = startX,
        y = startY,
        incomingDir = nil,
        path = { { x = startX, y = startY, incomingDir = nil, color = targetColor } }
    })

    while #queue > 0 do
        local current = table_remove(queue, 1)
        local x, y, incomingDir, path = current.x, current.y, current.incomingDir, current.path

        local tile = tileAt(self, x, y)
        if not tile or tile.type == "empty" then goto continue end

        -- Handle laser tile specially
        if tile.type == "laser" then
            -- If we're coming from somewhere else into a laser, that's invalid
            if incomingDir ~= nil then goto continue end

            -- Laser emits in its rotation direction
            local laserDir = tile.rotation
            local newX = x + self.dirVecsX[laserDir + 1]
            local newY = y + self.dirVecsY[laserDir + 1]
            local nextIncomingDir = (laserDir + 2) % 4

            local newKey = newY * (self.gw * 5) + newX * 5 + nextIncomingDir
            if not visited[newKey] and inBounds(self, newX, newY) then
                visited[newKey] = true
                local newPath = {}
                for _, seg in ipairs(path) do table_insert(newPath, seg) end
                table_insert(newPath, { x = newX, y = newY, incomingDir = nextIncomingDir })
                table_insert(queue, {
                    x = newX,
                    y = newY,
                    incomingDir = nextIncomingDir,
                    path = newPath
                })
            end
            goto continue
        end

        -- Check if we reached a target of the correct color
        if tile.type == "target" and tile.targetColor == targetColor then return path end

        -- For regular tiles, validate that beam can enter from incoming direction
        if not canBeamTravelThroughTile(self, tile, incomingDir, nil) then goto continue end

        -- Explore connected directions (excluding the incoming direction)
        local dirVecsX, dirVecsY = self.dirVecsX, self.dirVecsY
        for _, dir in ipairs(DIRS) do
            if dir ~= incomingDir then
                -- Validate that beam can exit through this direction
                if canBeamTravelThroughTile(self, tile, incomingDir, dir) then
                    local newX = x + dirVecsX[dir + 1]
                    local newY = y + dirVecsY[dir + 1]
                    local nextIncomingDir = (dir + 2) % 4
                    local newKey = newY * (self.gw * 5) + newX * 5 + nextIncomingDir
                    if not visited[newKey] and inBounds(self, newX, newY) then
                        visited[newKey] = true
                        local newPath = {}
                        for _, seg in ipairs(path) do table_insert(newPath, seg) end
                        table_insert(newPath, { x = newX, y = newY, incomingDir = nextIncomingDir })
                        table_insert(queue, {
                            x = newX,
                            y = newY,
                            incomingDir = nextIncomingDir,
                            path = newPath
                        })
                    end
                end
            end
        end

        ::continue::
    end

    return nil -- No path found
end

-- Breadth-First Search algorithm
local function computeBeamPaths(self)
    self.activeBeamPaths = {}
    self.targetsHit = {}
    self.beamProgress = {}
    self.previouslyHit = {}

    for _, laser in ipairs(self.lasers) do
        local shortestPath = findShortestPath(self, laser.x, laser.y, laser.color)

        if shortestPath then
            self.activeBeamPaths[laser.color] = shortestPath
            self.beamProgress[laser.color] = 0
            self.previouslyHit[laser.color] = false

            -- Mark the target as hit (the last segment in the path)
            local lastSegment = shortestPath[#shortestPath]
            if lastSegment then
                self.targetsHit[lastSegment.x .. "," .. lastSegment.y] = true
            end
        else
            self.activeBeamPaths[laser.color] = {}
        end
    end
end

-- Draw
local function drawGrid(self, sx, sy)
    local colors = self.colors
    local tileSize = self.tileSize

    -- Base tile
    colors:setColor("moonlit_charcoal", 1)
    rectangle("fill", sx, sy, tileSize - 1, tileSize - 1)

    -- Subtle grid pattern
    colors:setColor("neutral_grey", 0.1)
    local thirdSize = tileSize / 3
    for i = 1, 3 do
        for j = 1, 3 do
            local px = sx + (i - 1) * thirdSize
            local py = sy + (j - 1) * thirdSize
            if (i + j) % 2 == 0 then
                rectangle("fill", px, py, thirdSize - 1, thirdSize - 1)
            end
        end
    end

    colors:setColor("white", 0.2)
    rectangle("line", sx, sy, tileSize - 1, tileSize - 1)
end

-- Draw road arm connection (extends to tile edge)
local function drawRoadConnection(dir, cx, cy, half, roadWidth)
    if dir == "up" then
        love.graphics.rectangle("fill", cx - roadWidth / 2, cy - half, roadWidth, half)
    elseif dir == "down" then
        love.graphics.rectangle("fill", cx - roadWidth / 2, cy, roadWidth, half)
    elseif dir == "left" then
        love.graphics.rectangle("fill", cx - half, cy - roadWidth / 2, half, roadWidth)
    elseif dir == "right" then
        love.graphics.rectangle("fill", cx, cy - roadWidth / 2, half, roadWidth)
    end
end

-- Draw lane markings that connect between tiles
local function drawLaneMarkings(connections, cx, cy, half, roadWidth, lineWidth)
    local third = roadWidth / 3
    setLineWidth(lineWidth)

    if connections.up then
        line(cx, cy - third, cx, cy - half)
    end
    if connections.down then
        line(cx, cy + third, cx, cy + half)
    end
    if connections.left then
        line(cx - half, cy, cx - third, cy)
    end
    if connections.right then
        line(cx + third, cy, cx + half, cy)
    end
end

local function drawLaserEmitter(self, rotation, cx, cy, size, colorName)
    local colors = self.colors
    local outerSize = size
    local innerSize = size * 0.6
    local tipSize = size * 0.3

    local rot = rotation % 4

    -- Cache color strings once
    local casingColor = "laser_" .. colorName .. "_casing"
    local glowColor = "laser_" .. colorName .. "_glow"

    -- Predefined vertex sets for each rotation
    local outerVerts = {
        [0] = { cx, cy - outerSize, cx - outerSize / 2, cy + outerSize / 3, cx + outerSize / 2, cy + outerSize / 3 },
        [1] = { cx + outerSize, cy, cx - outerSize / 3, cy - outerSize / 2, cx - outerSize / 3, cy + outerSize / 2 },
        [2] = { cx, cy + outerSize, cx - outerSize / 2, cy - outerSize / 3, cx + outerSize / 2, cy - outerSize / 3 },
        [3] = { cx - outerSize, cy, cx + outerSize / 3, cy - outerSize / 2, cx + outerSize / 3, cy + outerSize / 2 }
    }

    local innerVerts = {
        [0] = { cx, cy - innerSize, cx - innerSize / 2, cy + innerSize / 4, cx + innerSize / 2, cy + innerSize / 4 },
        [1] = { cx + innerSize, cy, cx - innerSize / 4, cy - innerSize / 2, cx - innerSize / 4, cy + innerSize / 2 },
        [2] = { cx, cy + innerSize, cx - innerSize / 2, cy - innerSize / 4, cx + innerSize / 2, cy - innerSize / 4 },
        [3] = { cx - innerSize, cy, cx + innerSize / 4, cy - innerSize / 2, cx + innerSize / 4, cy + innerSize / 2 }
    }

    local tips = {
        [0] = { cx - tipSize / 4, cy - outerSize, tipSize / 2, tipSize },
        [1] = { cx + outerSize - tipSize, cy - tipSize / 4, tipSize, tipSize / 2 },
        [2] = { cx - tipSize / 4, cy + outerSize - tipSize, tipSize / 2, tipSize },
        [3] = { cx - outerSize, cy - tipSize / 4, tipSize, tipSize / 2 }
    }

    -- Outer casing
    colors:setColor(casingColor, 1)
    polygon("fill", outerVerts[rot])

    -- Inner core
    colors:setColor(glowColor, 1)
    polygon("fill", innerVerts[rot])

    -- Emitter tip
    colors:setColor("white_highlight", 1)
    rectangle("fill", unpack(tips[rot]))
end

local function drawTarget(self, cx, cy, size, colorName, hit, t)
    local colors = self.colors
    local baseSize = size * 0.5
    local glowSize = size * 0.4
    local lineLength = size * 0.2

    -- Cache color keys
    local casingColor = "target_" .. colorName .. "_casing"
    local glowColor = "target_" .. colorName .. "_glow"
    local coreColor = "target_" .. colorName .. "_core"

    -- Outer diamond (casing)
    colors:setColor(casingColor, 1)
    polygon("fill",
        cx, cy - baseSize,
        cx + baseSize, cy,
        cx, cy + baseSize,
        cx - baseSize, cy
    )

    -- Inner glow or core
    local alpha = 1
    local innerColor = coreColor
    if hit then
        innerColor = glowColor
        alpha = 0.9 + 0.1 * math_sin(t * 8)
    end
    colors:setColor(innerColor, alpha)

    polygon("fill",
        cx, cy - glowSize,
        cx + glowSize, cy,
        cx, cy + glowSize,
        cx - glowSize, cy
    )

    -- Crosshair
    colors:setColor("white_highlight", 0.8)
    setLineWidth(2)
    line(cx - lineLength, cy, cx + lineLength, cy, cx, cy - lineLength, cx, cy + lineLength)
    setLineWidth(1)
end

-- Draws a complete road tile
local function drawRoadTile(self, tileType, rotation, cx, cy, t, gx, gy)
    local tileSize = self.tileSize
    local colors = self.colors
    local half = tileSize / 2
    local roadWidth = tileSize * 0.4
    local lineWidth = tileSize * 0.06
    local tile = self:getTile(gx, gy)

    -- Draw base asphalt
    colors:setColor("road_base", 0.9)
    rectangle("fill", cx - half, cy - half, tileSize, tileSize)

    -- Outline for subtle grid separation
    colors:setColor("road_outline", 0.2)
    setLineWidth(1)
    rectangle("line", cx - half, cy - half, tileSize, tileSize)

    -- Draw road arms
    local connections = self.roadTileTypes[tileType][rotation + 1]
    colors:setColor("road_connection", 1)
    if connections.up then drawRoadConnection("up", cx, cy, half, roadWidth) end
    if connections.down then drawRoadConnection("down", cx, cy, half, roadWidth) end
    if connections.left then drawRoadConnection("left", cx, cy, half, roadWidth) end
    if connections.right then drawRoadConnection("right", cx, cy, half, roadWidth) end

    -- Draw central intersection block
    rectangle("fill", cx - roadWidth / 2, cy - roadWidth / 2, roadWidth, roadWidth)

    -- Lane markings (white lines reaching edges)
    colors:setColor("white_highlight", 0.8)
    drawLaneMarkings(connections, cx, cy, half, roadWidth, lineWidth)

    -- Special handling for lasers and targets with new shapes
    if tileType == "laser" then
        local laserColor = tile.laserColor or "red"
        local emitterSize = roadWidth * 0.8
        drawLaserEmitter(self, rotation, cx, cy, emitterSize, laserColor)
    elseif tileType == "target" then
        local targetColor = tile.targetColor or "red"
        local hit = self.targetsHit[gx .. "," .. gy]
        local targetSize = roadWidth * 0.9
        drawTarget(self, cx, cy, targetSize, targetColor, hit, t)
    end
end

local function drawGradualBeams(self, t)
    local colors = self.colors
    local tileSize = self.tileSize
    local beamPaths = self.activeBeamPaths
    local beamProg = self.beamProgress
    local getCenter = getTileCenter

    local pulse = 0.7 + 0.3 * math_sin(t * 8)

    for beamColor, path in pairs(beamPaths) do
        local count = #path
        if count == 0 then goto continue end

        local progress = math_min(beamProg[beamColor] or 0, count)
        local intProg = math_floor(progress)
        local partial = progress - intProg

        local colorKey = "beam_" .. beamColor
        local faintAlpha = 0.4 * pulse
        local strongAlpha = 0.9 * pulse

        -- Draw full beam segments
        if intProg >= 2 then
            local prevSeg = path[1]
            local psx, psy = getCenter(self, prevSeg.x, prevSeg.y)
            setLineWidth(3)

            for i = 2, intProg do
                local seg = path[i]
                local sx, sy = getCenter(self, seg.x, seg.y)

                colors:setColor(colorKey, faintAlpha)
                line(psx, psy, sx, sy)
                colors:setColor(colorKey, strongAlpha)
                line(psx, psy, sx, sy)

                psx, psy = sx, sy
            end
        end

        -- Partial progress toward next segment (only if valid)
        if partial > 0 and intProg >= 1 and intProg < count then
            local curr = path[intProg]
            local next = path[intProg + 1]

            if curr and next then
                local csx, csy = getCenter(self, curr.x, curr.y)
                local nsx, nsy = getCenter(self, next.x, next.y)
                local isx = csx + (nsx - csx) * partial
                local isy = csy + (nsy - csy) * partial

                -- Outer glow
                setLineWidth(12)
                colors:setColor(colorKey, faintAlpha)
                line(csx, csy, isx, isy)

                -- Inner beam
                setLineWidth(6)
                colors:setColor(colorKey, strongAlpha)
                line(csx, csy, isx, isy)

                -- Endpoint glow
                colors:setColor(colorKey, strongAlpha)
                circle("fill", isx, isy, tileSize * 0.12)
            end
        end

        ::continue::
    end

    setLineWidth(1)
end

function Grid:getTile(x, y) return tileAt(self, x, y) end

function Grid:loadLevel(levelData)
    self.gw, self.gh = levelData.gridSize, levelData.gridSize
    self.grid, self.lasers, self.beams, self.targetsHit = {}, {}, {}, {}
    self.previouslyHit = {}
    self.beamProgress = {}
    self.activeBeamPaths = {}
    self.targets = levelData.targets or {}

    -- Initialize grid with road tiles
    for y = 1, self.gh do
        self.grid[y] = {}
        for x = 1, self.gw do
            if levelData.tiles[y] and levelData.tiles[y][x] then
                self.grid[y][x] = levelData.tiles[y][x]
            else
                self.grid[y][x] = { type = "empty", rotation = 0 }
            end
        end
    end

    -- Place multiple lasers as proper road tiles
    if levelData.lasers then
        for _, laser in ipairs(levelData.lasers) do
            local lx, ly, ld, color = laser.x, laser.y, laser.dir, laser.color
            self.grid[ly][lx] = {
                type = "laser",
                rotation = ld,
                laserColor = color
            }
            table_insert(self.lasers, { x = lx, y = ly, d = ld, color = color })
        end
    end

    -- Place multiple targets as proper road tiles
    if levelData.targets then
        for _, target in ipairs(levelData.targets) do
            local tx, ty, color = target.x, target.y, target.color
            self.grid[ty][tx] = {
                type = "target",
                rotation = 0, -- Targets can receive from any direction
                targetColor = color
            }
        end
    end

    local w, h = love.graphics.getDimensions()
    self:calculateTileSize(w, h)

    computeBeamPaths(self)
end

function Grid:calculateTileSize(winw, winh)
    local maxTileW = math_floor((winw - 160) / self.gw)
    local maxTileH = math_floor((winh - 160) / self.gh)
    self.tileSize = math_max(24, math_min(64, math_min(maxTileW, maxTileH)))
    self.gridOffsetX = math_floor((winw - self.gw * self.tileSize) / 2)
    self.gridOffsetY = math_floor((winh - self.gh * self.tileSize) / 2)
end

function Grid:screenToGrid(sx, sy)
    local gx = math_floor((sx - self.gridOffsetX) / self.tileSize) + 1
    local gy = math_floor((sy - self.gridOffsetY) / self.tileSize) + 1
    if inBounds(self, gx, gy) then return gx, gy end
end

function Grid:rotateTile(x, y, delta)
    local tile = tileAt(self, x, y)
    if not tile or tile.type == "empty" then return end

    tile.rotation = (tile.rotation + (delta or 1)) % 4
    computeBeamPaths(self)
    self.sounds:play("rotate")
end

function Grid:getTargetProgress()
    local totalTargets = #self.targets
    local hitCount = 0

    for _, hit in pairs(self.targetsHit) do
        if hit then hitCount = hitCount + 1 end
    end

    return hitCount, totalTargets
end

function Grid:update(dt)
    -- Update beam progression for each active beam
    for beamColor, path in pairs(self.activeBeamPaths) do
        local pathLength = #path
        if pathLength > 0 then
            self.beamProgress[beamColor] = (self.beamProgress[beamColor] or 0) + self.beamSpeed * dt
            if self.beamProgress[beamColor] > pathLength then
                self.beamProgress[beamColor] = pathLength

                -- Check if target was just hit
                local lastSegment = path[#path]
                local targetKey = lastSegment.x .. "," .. lastSegment.y
                if self.targetsHit[targetKey] and not (self.previouslyHit[beamColor]) then
                    self.sounds:play("connect")
                    self.previouslyHit[beamColor] = true
                end
            end
        else
            self.previouslyHit[beamColor] = false
        end
    end
end

function Grid:draw()
    local t = love.timer.getTime()
    local gridOffsetX, gridOffsetY = self.gridOffsetX, self.gridOffsetY
    local tileSize = self.tileSize
    local gw, gh = self.gw, self.gh

    -- Draw grid background
    for y = 1, gh do
        for x = 1, gw do
            local sx = gridOffsetX + (x - 1) * tileSize
            local sy = gridOffsetY + (y - 1) * tileSize
            drawGrid(self, sx, sy)
        end
    end

    -- Draw road tiles
    for y = 1, gh do
        for x = 1, gw do
            local tile = tileAt(self, x, y)
            if tile and tile.type ~= "empty" then
                local sx = gridOffsetX + (x - 1) * tileSize
                local sy = gridOffsetY + (y - 1) * tileSize
                local cx = sx + tileSize / 2
                local cy = sy + tileSize / 2

                drawRoadTile(self, tile.type, tile.rotation, cx, cy, t, x, y)
            end
        end
    end

    -- Draw gradual beams for all active lasers
    drawGradualBeams(self, t)
end

return Grid
