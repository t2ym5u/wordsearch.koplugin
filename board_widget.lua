local Blitbuffer    = require("ffi/blitbuffer")
local Device        = require("device")
local Font          = require("ui/font")
local Geom          = require("ui/geometry")
local GestureRange  = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText    = require("ui/rendertext")
local UIManager     = require("ui/uimanager")

local C_BG       = Blitbuffer.COLOR_WHITE
local C_GRID     = Blitbuffer.COLOR_GRAY_9
local C_BORDER   = Blitbuffer.COLOR_BLACK
local C_FOUND    = Blitbuffer.COLOR_LIGHT_GRAY
local C_SELECTED = Blitbuffer.COLOR_GRAY
local C_TEXT     = Blitbuffer.COLOR_BLACK

local Screen = Device.screen

-- Largest face whose ink for `sample` fits max_w x max_h. Measured unbounded
-- (a max_width limit cuts the text, so the width test could never fail), ink
-- height is y_top + y_bottom, and Font:getFace scales its size by the DPI, so
-- the pixel bound is converted back first.
local function fitFace(name, sample, max_w, max_h)
    local lo = 6
    local hi = math.max(lo, math.floor(max_h * 1000 / Screen:scaleBySize(1000)) * 2)
    local best = lo
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local m = RenderText:sizeUtf8Text(0, Screen:getWidth(), Font:getFace(name, mid), sample, true, false)
        if m.x <= max_w and m.y_top + m.y_bottom <= max_h then
            best, lo = mid, mid + 1
        else
            hi = mid - 1
        end
    end
    return Font:getFace(name, best)
end

-- ---------------------------------------------------------------------------
-- WordSearchBoardWidget
-- ---------------------------------------------------------------------------

local WordSearchBoardWidget = InputContainer:extend{
    board      = nil,
    max_width  = 200,
    max_height = 200,
    onFirstTap = nil,
    onSelectWord = nil,
}

function WordSearchBoardWidget:init()
    local size = self.board.size
    local cell = math.floor(math.min(self.max_width, self.max_height) / size)
    cell = math.max(cell, 12)
    self.cell  = cell
    self.w     = cell * size
    self.h     = cell * size
    self.dimen = Geom:new{ w = self.w, h = self.h }
    self.paint_rect = nil
    self.first_tap  = nil

    self.letter_face = fitFace("smallinfofont", "W", math.floor(cell * 0.75), math.floor(cell * 0.55))

    self.ges_events = {
        CellTap = { GestureRange:new{ ges = "tap", range = function() return self.paint_rect end } },
    }
end

function WordSearchBoardWidget:onCellTap(_, ges)
    if not self.paint_rect then return true end
    local rect = self.paint_rect
    local lx = ges.pos.x - rect.x
    local ly = ges.pos.y - rect.y
    local cell = self.cell
    if lx < 0 or ly < 0 or lx >= self.w or ly >= self.h then return true end
    local c = math.floor(lx / cell) + 1
    local r = math.floor(ly / cell) + 1
    local size = self.board.size
    if r < 1 or r > size or c < 1 or c > size then return true end

    if not self.first_tap then
        self.first_tap = { r = r, c = c }
        self:refresh()
    else
        local r1, c1 = self.first_tap.r, self.first_tap.c
        self.first_tap = nil
        if self.onSelectWord then
            self.onSelectWord(r1, c1, r, c)
        end
        self:refresh()
    end
    return true
end

function WordSearchBoardWidget:_isCellFound(r, c)
    local board = self.board
    for i, entry in ipairs(board.word_list) do
        if board.found[i] then
            local dr = entry.r2 - entry.r1
            local dc = entry.c2 - entry.c1
            local wlen = math.max(math.abs(dr), math.abs(dc)) + 1
            local step_r = dr == 0 and 0 or (dr > 0 and 1 or -1)
            local step_c = dc == 0 and 0 or (dc > 0 and 1 or -1)
            for s = 0, wlen - 1 do
                if entry.r1 + step_r * s == r and entry.c1 + step_c * s == c then
                    return true
                end
            end
        end
    end
    return false
end

function WordSearchBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board = self.board
    local size  = board.size
    local cell  = self.cell

    bb:paintRect(x, y, self.w, self.h, C_BG)

    -- Cell backgrounds
    for r = 1, size do
        for c = 1, size do
            local cx = x + (c - 1) * cell
            local cy = y + (r - 1) * cell
            local bg = C_BG
            if self:_isCellFound(r, c) then
                bg = C_FOUND
            elseif self.first_tap and self.first_tap.r == r and self.first_tap.c == c then
                bg = C_SELECTED
            end
            if bg ~= C_BG then
                bb:paintRect(cx, cy, cell, cell, bg)
            end
        end
    end

    -- Grid lines
    for i = 0, size do
        bb:paintRect(x + i * cell, y, 1, self.h, C_GRID)
        bb:paintRect(x, y + i * cell, self.w, 1, C_GRID)
    end

    -- Border
    local thick = 2
    bb:paintRect(x, y, self.w, thick, C_BORDER)
    bb:paintRect(x, y + self.h - thick, self.w, thick, C_BORDER)
    bb:paintRect(x, y, thick, self.h, C_BORDER)
    bb:paintRect(x + self.w - thick, y, thick, self.h, C_BORDER)

    -- Letters
    local half = math.floor(cell / 2)
    for r = 1, size do
        for c = 1, size do
            local ch = board.grid[r][c]
            if ch and ch ~= "" then
                local cx = x + (c - 1) * cell
                local cy = y + (r - 1) * cell
                -- Centred on the cell: the baseline sits half the ink
                -- height below the middle.
                local m  = RenderText:sizeUtf8Text(0, Screen:getWidth(), self.letter_face, ch, true, false)
                local tx = cx + half - math.floor(m.x / 2)
                local ty = cy + half + math.floor((m.y_top - m.y_bottom) / 2)
                RenderText:renderUtf8Text(bb, tx, ty, self.letter_face, ch, true, false, C_TEXT)
            end
        end
    end
end

function WordSearchBoardWidget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

return WordSearchBoardWidget
