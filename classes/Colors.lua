-- Pathfinder - Love2D
-- Tile-based puzzle: rotate road tiles to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local setColor = love.graphics.setColor

local Colors = {}
Colors.__index = Colors

function Colors.new()
    local instance = setmetatable({}, Colors)

    instance.colors = {

        red = { 1.0, 0.2, 0.2 },

        road_base = { 0.3, 0.3, 0.5 },
        road_outline = { 0.5, 0.5, 0.8 },
        road_connection = { 0.7, 0.7, 1.0 },
        selection_glow = { 0.5, 1.0, 0.9 },
        white = { 1, 1, 1 },
        moonlit_charcoal = { 0.1, 0.1, 0.12 },
        neutral_grey = { 0.22, 0.22, 0.24 },
        neon_green = { 0 / 255, 255 / 255, 68 / 255 },
        lime_green = { 0.6, 1.0, 0.2 },
        medium_blue = { 0.2, 0.5, 0.8 },
        white_highlight = { 1, 1, 1 },
        neon_green_glow = { 0 / 255, 255 / 255, 100 / 255 },

        -- Laser casing colors
        laser_red_casing = { 0.7, 0.1, 0.1 },
        laser_blue_casing = { 0.1, 0.1, 0.7 },
        laser_green_casing = { 0.1, 0.5, 0.1 },
        laser_yellow_casing = { 0.6, 0.5, 0.1 },

        -- Target casing colors
        target_red_casing = { 0.7, 0.1, 0.1 },
        target_blue_casing = { 0.1, 0.1, 0.7 },
        target_green_casing = { 0.1, 0.5, 0.1 },
        target_yellow_casing = { 0.6, 0.5, 0.1 },

        -- Target core colors
        target_red_core = { 1.0, 0.3, 0.3 },
        target_blue_core = { 0.3, 0.3, 1.0 },
        target_green_core = { 0.3, 0.8, 0.3 },
        target_yellow_core = { 1.0, 0.9, 0.3 },

        -- Laser and target colors
        laser_red = { 1.0, 0.2, 0.2 },
        laser_red_glow = { 1.0, 0.4, 0.4 },
        target_red = { 0.9, 0.1, 0.1 },
        target_red_glow = { 1.0, 0.3, 0.3 },

        laser_blue = { 0.2, 0.5, 1.0 },
        laser_blue_glow = { 0.4, 0.7, 1.0 },
        target_blue = { 0.1, 0.3, 0.8 },
        target_blue_glow = { 0.3, 0.5, 1.0 },

        laser_green = { 0.2, 0.8, 0.2 },
        laser_green_glow = { 0.4, 1.0, 0.4 },
        target_green = { 0.1, 0.6, 0.1 },
        target_green_glow = { 0.3, 0.8, 0.3 },

        laser_yellow = { 1.0, 0.8, 0.2 },
        laser_yellow_glow = { 1.0, 0.9, 0.4 },
        target_yellow = { 0.8, 0.6, 0.1 },
        target_yellow_glow = { 1.0, 0.8, 0.3 },

        beam_red = { 1.0, 0.3, 0.3, 0.8 },
        beam_blue = { 0.3, 0.6, 1.0, 0.8 },
        beam_green = { 0.3, 1.0, 0.3, 0.8 },
        beam_yellow = { 1.0, 0.9, 0.3, 0.8 },
    }

    return instance
end

function Colors:getColor(name)
    return self.colors[name]
end

function Colors:setColor(name, alpha)
    local col = self.colors[name]
    if col then
        local r, g, b, a = col[1], col[2], col[3], alpha or (col[4] or 1)
        setColor(r, g, b, a)
    else
        error("Color '" .. name .. "' not found")
    end
end

return Colors
