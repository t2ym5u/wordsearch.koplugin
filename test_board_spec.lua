local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

describe("WordSearchBoard", function()
    local Board

    setup(function()
        Board = require("board")
    end)

    describe("new / generate", function()
        it("fills a 12x12 grid with letters and places at least one word", function()
            math.randomseed(42)
            local b = Board:new()
            assert.are.equal(12, b.size)
            for r = 1, b.size do
                for c = 1, b.size do
                    assert.are.equal(1, #b.grid[r][c])
                end
            end
            assert.is_true(#b.word_list > 0)
            assert.are.equal(#b.word_list, #b.found)
        end)

        it("every placed word's letters actually appear along its path in the grid", function()
            math.randomseed(7)
            local b = Board:new()
            for _, entry in ipairs(b.word_list) do
                local dr = (entry.r2 > entry.r1 and 1) or (entry.r2 < entry.r1 and -1) or 0
                local dc = (entry.c2 > entry.c1 and 1) or (entry.c2 < entry.c1 and -1) or 0
                for i = 0, #entry.word - 1 do
                    local r, c = entry.r1 + dr * i, entry.c1 + dc * i
                    assert.are.equal(entry.word:sub(i + 1, i + 1), b.grid[r][c])
                end
            end
        end)

        it("found starts all false", function()
            math.randomseed(42)
            local b = Board:new()
            for _, f in ipairs(b.found) do
                assert.is_false(f)
            end
        end)
    end)

    describe("tapCell", function()
        it("marks a word found when tapped along its exact endpoints", function()
            math.randomseed(42)
            local b = Board:new()
            local entry = b.word_list[1]
            local status, word = b:tapCell(entry.r1, entry.c1, entry.r2, entry.c2)
            assert.are.equal("found", status)
            assert.are.equal(entry.word, word)
            assert.is_true(b.found[1])
        end)

        it("also matches the reversed endpoint order", function()
            math.randomseed(42)
            local b = Board:new()
            local entry = b.word_list[1]
            local status = b:tapCell(entry.r2, entry.c2, entry.r1, entry.c1)
            assert.are.equal("found", status)
        end)

        it("returns none for endpoints matching no placed word", function()
            math.randomseed(42)
            local b = Board:new()
            local status = b:tapCell(-1, -1, -1, -1)
            assert.are.equal("none", status)
        end)
    end)

    describe("allFound / foundCount", function()
        it("becomes true once every word is tapped", function()
            math.randomseed(42)
            local b = Board:new()
            assert.is_false(b:allFound())
            for _, entry in ipairs(b.word_list) do
                b:tapCell(entry.r1, entry.c1, entry.r2, entry.c2)
            end
            assert.is_true(b:allFound())
            assert.are.equal(#b.word_list, b:foundCount())
        end)
    end)

    describe("serialize / load", function()
        it("round-trips the grid, word list and found flags", function()
            math.randomseed(42)
            local b = Board:new()
            b:tapCell(b.word_list[1].r1, b.word_list[1].c1, b.word_list[1].r2, b.word_list[1].c2)
            local data = b:serialize()

            local b2 = Board:new()
            assert.is_true(b2:load(data))
            assert.are.equal(#b.word_list, #b2.word_list)
            assert.are.equal(b.word_list[1].word, b2.word_list[1].word)
            assert.is_true(b2.found[1])
            for r = 1, b.size do
                for c = 1, b.size do
                    assert.are.equal(b.grid[r][c], b2.grid[r][c])
                end
            end
        end)

        it("load returns false for invalid data", function()
            local b = Board:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)
