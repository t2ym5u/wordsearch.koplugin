-- Spec for the multiplayer match (party_match.lua): scoring, rounds, clock,
-- tags and save/restore.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path

package.loaded["i18n"] = function(s) return s end
package.loaded["ffi/util"] = { template = function(s, ...)
    local args = { ... }
    return (s:gsub("%%(%d)", function(n) return tostring(args[tonumber(n)]) end))
end }

local Board = require("board")
local Match = require("party_match")

local function newBoard(seed)
    math.randomseed(seed or 3)
    return Board:new()
end

describe("Word Search match", function()
    it("credits a word's length, or 1 per word, to the finder", function()
        local b = newBoard()
        local m = Match.new({ "Alice", "Bob" }, { rounds = 2, duration = 0 })
        local w1 = b.word_list[1].word
        assert.are.equal(#w1, m:credit(b, 1, 2))
        assert.is_true(b.found[1])
        assert.are.same({ 0, #w1 }, m.scores.points)
        assert.are.equal("found", (m:wordState(b, 1)))
        assert.are.equal(2, select(2, m:wordState(b, 1)))
        -- Already found: no double credit.
        assert.are.equal(0, m:credit(b, 1, 1))

        local m2 = Match.new({ "Alice", "Bob" }, { scoring = "word" })
        assert.are.equal(1, m2:credit(b, 2, 1))
    end)

    it("ignores unknown players and words", function()
        local b = newBoard()
        local m = Match.new({ "A", "B" }, {})
        assert.are.equal(0, m:credit(b, 1, 3))
        assert.are.equal(0, m:credit(b, 99, 1))
        assert.is_false(b.found[1])
    end)

    it("ends the round when every word is found, the match after N rounds", function()
        local b = newBoard()
        local m = Match.new({ "A", "B" }, { rounds = 2, duration = 0 })
        assert.are.equal(1, m:round())
        for i = 1, #b.word_list do
            assert.is_false(m:isRoundOver(b))
            m:credit(b, i, (i % 2) + 1)
        end
        assert.is_true(m:isRoundOver(b))
        assert.is_false(m:isOver(b))
        m:startRound()
        b = newBoard(5)
        assert.are.equal(2, m:round())
        assert.is_false(m:isRoundOver(b))
        assert.are.same({}, m.finders)
        for i = 1, #b.word_list do m:credit(b, i, 1) end
        assert.is_true(m:isOver(b))
    end)

    it("runs the clock out, then shows the missed words", function()
        local b = newBoard()
        local m = Match.new({ "A", "B" }, { duration = 3 })
        assert.is_true(m:hasClock())
        m:credit(b, 1, 1)
        assert.is_false(m:tick())
        assert.is_false(m:tick())
        assert.is_true(m:tick())
        assert.are.equal(0, m.time_left)
        assert.is_true(m:isRoundOver(b))
        m:revealMissed(b)
        assert.is_true(b:allFound())
        assert.are.equal("found", (m:wordState(b, 1)))
        assert.are.equal("missed", (m:wordState(b, 2)))
        -- Nothing can be credited once the round is over.
        assert.are.equal(0, m:credit(b, 2, 2))
        assert.is_false(m:tick())
        -- No clock at all: ticking never ends the round.
        local m2 = Match.new({ "A", "B" }, { duration = 0 })
        assert.is_false(m2:hasClock())
        assert.is_false(m2:tick())
    end)

    it("tags players by the shortest distinct prefix", function()
        assert.are.same({ "A", "B" }, Match.tags({ "Alice", "Bob" }))
        assert.are.same({ "Al", "An", "B" }, Match.tags({ "Alice", "Anne", "Bob" }))
        assert.are.same({ "Paul", "Pauli" }, Match.tags({ "Paul", "Pauline" }))
        assert.are.same({ "Ér", "Ém" }, Match.tags({ "Éric", "Émile" }))
        assert.are.same({ "P1", "P2" }, Match.tags({ "Player 1", "Player 2" }))
    end)

    it("saves and restores scores, round, finders and clock", function()
        local b = newBoard()
        local m = Match.new({ "Alice", "Bob", "Chloé" }, { rounds = 3, duration = 300, scoring = "word" })
        m:credit(b, 1, 3)
        m:credit(b, 2, 1)
        m:tick()
        local saved = { match = m:serialize(), board = b:serialize() }

        local r = Match.restore(saved.match)
        local b2 = Board:new()
        assert.is_true(b2:load(saved.board))
        assert.are.same(m.scores, r.scores)
        assert.are.equal(299, r.time_left)
        assert.are.equal("word", r.scoring)
        assert.are.equal(3, r.rounds)
        assert.are.equal(3, select(2, r:wordState(b2, 1)))
        assert.are.equal(1, select(2, r:wordState(b2, 2)))
        assert.are.equal("open", (r:wordState(b2, 3)))
        assert.is_true(b2.found[1] and b2.found[2])

        -- A finished match restores finished.
        for i = 1, #b2.word_list do r:credit(b2, i, 2) end
        r.rounds = 1
        local r2 = Match.restore(r:serialize())
        local b3 = Board:new()
        b3:load(b2:serialize())
        assert.is_true(r2:isOver(b3))

        assert.is_nil(Match.restore(nil))
        assert.is_nil(Match.restore({ scores = { names = { "A" }, points = {} } }))
    end)
end)
