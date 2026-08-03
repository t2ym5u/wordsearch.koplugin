-- Word pools (4-7 letters, frequency-filtered common words, shared with anagram.koplugin)
local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local WORDS_EN = lrequire("words_en")
local WORDS_FR = lrequire("words_fr")

local DIRS = {
    {1,0}, {-1,0}, {0,1}, {0,-1},
    {1,1}, {1,-1}, {-1,1}, {-1,-1},
}
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local SIZE  = 12

-- ---------------------------------------------------------------------------
-- WordSearchBoard
-- ---------------------------------------------------------------------------

local WordSearchBoard = {}
WordSearchBoard.__index = WordSearchBoard

function WordSearchBoard:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        lang      = opts.lang or "en",
        size      = SIZE,
        grid      = nil,
        word_list = nil,
        found     = nil,
    }, self)
    obj:generate()
    return obj
end

function WordSearchBoard:_wordList()
    return self.lang == "fr" and WORDS_FR or WORDS_EN
end

function WordSearchBoard:generate()
    local size = self.size
    local pool = self:_wordList()

    -- pick words to place
    local shuffled = {}
    for _, w in ipairs(pool) do shuffled[#shuffled + 1] = w end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    local count = math.random(12, 16)
    local chosen = {}
    for i = 1, math.min(count, #shuffled) do
        chosen[#chosen + 1] = shuffled[i]
    end
    -- longest words first: they're harder to fit and give shorter words
    -- more existing letters to cross over
    table.sort(chosen, function(a, b) return #a > #b end)

    -- empty grid
    local grid = {}
    for r = 1, size do
        grid[r] = {}
        for c = 1, size do grid[r][c] = "" end
    end

    -- Returns end position and overlap count if `word` fits at (r1,c1) going
    -- (dr,dc) without letter conflicts, or nil if it doesn't fit.
    local function fits(word, r1, c1, dr, dc)
        local wlen = #word
        local r2 = r1 + dr * (wlen - 1)
        local c2 = c1 + dc * (wlen - 1)
        if r2 < 1 or r2 > size or c2 < 1 or c2 > size then return nil end
        local overlaps = 0
        for i = 0, wlen - 1 do
            local ch = grid[r1 + dr*i][c1 + dc*i]
            local wch = word:sub(i+1, i+1)
            if ch ~= "" then
                if ch ~= wch then return nil end
                overlaps = overlaps + 1
            end
        end
        return r2, c2, overlaps
    end

    local placed = {}
    for _, word in ipairs(chosen) do
        -- Enumerate every valid placement, preferring ones that cross an
        -- already-placed word (overlaps > 0) so the grid gets interlinked.
        local crossing, any = {}, {}
        for r1 = 1, size do
            for c1 = 1, size do
                for _, dir in ipairs(DIRS) do
                    local dr, dc = dir[1], dir[2]
                    local r2, c2, overlaps = fits(word, r1, c1, dr, dc)
                    if r2 then
                        local cand = { r1=r1, c1=c1, r2=r2, c2=c2, dr=dr, dc=dc }
                        any[#any + 1] = cand
                        if overlaps > 0 then crossing[#crossing + 1] = cand end
                    end
                end
            end
        end
        local pool_cands = #crossing > 0 and crossing or any
        if #pool_cands > 0 then
            local pick = pool_cands[math.random(#pool_cands)]
            local wlen = #word
            for i = 0, wlen - 1 do
                grid[pick.r1 + pick.dr*i][pick.c1 + pick.dc*i] = word:sub(i+1, i+1)
            end
            placed[#placed + 1] = { word=word, r1=pick.r1, c1=pick.c1, r2=pick.r2, c2=pick.c2 }
        end
        -- skip word if it truly doesn't fit anywhere
    end

    -- fill remaining cells
    for r = 1, size do
        for c = 1, size do
            if grid[r][c] == "" then
                local idx = math.random(#ALPHA)
                grid[r][c] = ALPHA:sub(idx, idx)
            end
        end
    end

    self.grid      = grid
    self.word_list = placed
    self.found     = {}
    for i = 1, #placed do self.found[i] = false end
end

-- Returns "found" or "none"
function WordSearchBoard:tapCell(r1, c1, r2, c2)
    for i, entry in ipairs(self.word_list) do
        if not self.found[i] then
            if (entry.r1 == r1 and entry.c1 == c1 and entry.r2 == r2 and entry.c2 == c2) or
               (entry.r1 == r2 and entry.c1 == c2 and entry.r2 == r1 and entry.c2 == c1) then
                self.found[i] = true
                return "found", entry.word
            end
        end
    end
    return "none", nil
end

function WordSearchBoard:allFound()
    for i = 1, #self.found do
        if not self.found[i] then return false end
    end
    return true
end

function WordSearchBoard:foundCount()
    local n = 0
    for i = 1, #self.found do
        if self.found[i] then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function WordSearchBoard:serialize()
    local grid_flat = {}
    for r = 1, self.size do
        for c = 1, self.size do
            grid_flat[#grid_flat + 1] = self.grid[r][c]
        end
    end
    local wl = {}
    for _, e in ipairs(self.word_list) do
        wl[#wl + 1] = { e.word, e.r1, e.c1, e.r2, e.c2 }
    end
    return {
        lang      = self.lang,
        grid_flat = grid_flat,
        word_list = wl,
        found     = self.found,
    }
end

function WordSearchBoard:load(data)
    if type(data) ~= "table" or not data.grid_flat then return false end
    self.lang = data.lang or "en"
    local grid = {}
    local idx  = 1
    for r = 1, SIZE do
        grid[r] = {}
        for c = 1, SIZE do
            grid[r][c] = data.grid_flat[idx] or ""
            idx = idx + 1
        end
    end
    self.grid = grid
    self.word_list = {}
    for _, e in ipairs(data.word_list or {}) do
        self.word_list[#self.word_list + 1] = { word=e[1], r1=e[2], c1=e[3], r2=e[4], c2=e[5] }
    end
    self.found = {}
    for i, v in ipairs(data.found or {}) do self.found[i] = v end
    for i = #self.found + 1, #self.word_list do self.found[i] = false end
    return true
end

return WordSearchBoard
