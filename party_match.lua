-- ---------------------------------------------------------------------------
-- party_match.lua — a "· multiplayer" Word Search match (pure Lua, no UI).
--
-- Everyone searches the same grid laid on the table. Whoever spots a word
-- traces it, says so, and the reader asks who it was: the word is credited
-- to that player (its length in points, or 1 per word) and their tag is shown
-- next to it in the word list. A round ends when every word is found or when
-- the clock runs out (the missing words are then shown); a match is N rounds,
-- one grid each.
--
-- The grid itself is a WordSearchBoard; the match only keeps who found which
-- word (finders[word index] = player index), the scores (party.lua) and the
-- clock.
-- ---------------------------------------------------------------------------

local Party = require("party")

local Match = {}
Match.__index = Match

Match.ROUNDS    = { 1, 2, 3, 5 }
Match.DURATIONS = { 0, 180, 300, 600 }   -- seconds, 0 = no limit
Match.SCORINGS  = { "length", "word" }

-- opts: rounds (default 3), duration (seconds, 0 = none, default 300),
-- scoring ("length" | "word", default "length").
function Match.new(names, opts)
    opts = opts or {}
    local m = setmetatable({
        scores   = Party.newScores(names),
        rounds   = tonumber(opts.rounds) or 3,
        duration = tonumber(opts.duration) or 300,
        scoring  = opts.scoring == "word" and "word" or "length",
    }, Match)
    m:startRound()
    return m
end

-- Next round: a fresh clock and no finders. The caller deals the grid.
function Match:startRound()
    Party.nextRound(self.scores)
    self.finders   = {}
    self.time_left = self.duration
    self.time_up   = false
end

function Match:round()
    return self.scores.round
end

function Match:hasClock()
    return self.duration > 0
end

function Match:points(word)
    if self.scoring == "word" then return 1 end
    return #(word or "")
end

-- Word `i` of `board` was found by `player`: marks it found, credits the
-- player. Returns the points won (0 when nothing changed).
function Match:credit(board, i, player)
    local entry = board.word_list[i]
    if not entry or self.finders[i] or self:isRoundOver(board) then return 0 end
    if not self.scores.names[player] then return 0 end
    board.found[i] = true
    self.finders[i] = player
    local pts = self:points(entry.word)
    Party.award(self.scores, player, pts)
    return pts
end

-- One second off the clock. Returns true when that ran it out.
function Match:tick()
    if not self:hasClock() or self.time_up then return false end
    self.time_left = math.max(0, self.time_left - 1)
    if self.time_left == 0 then
        self.time_up = true
        return true
    end
    return false
end

function Match:isRoundOver(board)
    return self.time_up or board:allFound()
end

function Match:isLastRound()
    return self.scores.round >= self.rounds
end

function Match:isOver(board)
    return self:isRoundOver(board) and self:isLastRound()
end

-- Per-word state for the list: "found" (with the finder's index), "missed"
-- (the round ended before anyone found it) or "open".
function Match:wordState(board, i)
    if self.finders[i] then return "found", self.finders[i] end
    if self:isRoundOver(board) then return "missed" end
    return "open"
end

-- Time is up: the words nobody found are shown on the grid (marked found
-- there, but with no finder).
function Match:revealMissed(board)
    for i = 1, #board.word_list do board.found[i] = true end
end

-- Short tags for the word list: the shortest prefix (at least one letter)
-- that tells each player apart from the others; a name that is a prefix of
-- another one is used whole. A tag that would need more than 5 letters
-- ("Player 1" / "Player 2") becomes initial + seat number ("P1", "P2").
function Match.tags(names)
    local chars = {}
    for i, s in ipairs(names) do
        local list = {}
        for ch in tostring(s):gmatch("[\1-\127\194-\244][\128-\191]*") do list[#list + 1] = ch end
        chars[i] = list
    end
    local function prefix(i, n) return table.concat(chars[i], "", 1, math.min(n, #chars[i])) end
    local out = {}
    for i = 1, #names do
        local n = 1
        while n < #chars[i] do
            local clash = false
            for j = 1, #names do
                if j ~= i and prefix(j, n):lower() == prefix(i, n):lower() then clash = true break end
            end
            if not clash then break end
            n = n + 1
        end
        out[i] = n > 5 and (prefix(i, 1) .. i) or prefix(i, n)
        if out[i] == "" then out[i] = tostring(i) end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Save / restore
-- ---------------------------------------------------------------------------

function Match:serialize()
    local finders = {}
    for i, v in pairs(self.finders) do finders[#finders + 1] = { i, v } end
    return {
        scores    = Party.copyScores(self.scores),
        rounds    = self.rounds,
        duration  = self.duration,
        scoring   = self.scoring,
        time_left = self.time_left,
        time_up   = self.time_up,
        finders   = finders,
    }
end

-- Returns a Match, or nil when `t` is unusable.
function Match.restore(t)
    if type(t) ~= "table" then return nil end
    local scores = Party.restoreScores(t.scores)
    if not scores or scores.round < 1 then return nil end
    local m = setmetatable({
        scores    = scores,
        rounds    = tonumber(t.rounds) or 3,
        duration  = tonumber(t.duration) or 0,
        scoring   = t.scoring == "word" and "word" or "length",
        time_left = tonumber(t.time_left) or 0,
        time_up   = t.time_up and true or false,
        finders   = {},
    }, Match)
    for _i, pair in ipairs(type(t.finders) == "table" and t.finders or {}) do
        local i, v = tonumber(pair[1]), tonumber(pair[2])
        if i and v and scores.names[v] then m.finders[i] = v end
    end
    return m
end

return Match
