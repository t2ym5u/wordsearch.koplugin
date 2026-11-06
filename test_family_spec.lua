-- Family-friendly words: the game is also played at a family table, so a word
-- it hides in the grid (and lists beside it) must never be one of
-- blocklist.lua's vulgar, sexual, scatological, slur or drug-related words.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

local Blocklist = dofile(DIR .. "blocklist.lua")

describe("family-friendly word list", function()
    local Board

    setup(function()
        Board = require("board")
    end)

    it("the raw lists do carry blocklisted words (so the filter is exercised)", function()
        local fr = dofile(DIR .. "words_fr.lua")
        local seen = {}
        for _, w in ipairs(fr) do seen[w] = true end
        assert.is_true(seen.CACA)
        assert.is_true(seen.SUCEUR)
    end)

    for _, lang in ipairs({ "en", "fr" }) do
        it("the " .. lang .. " pool it draws from has no blocklisted word", function()
            local pool = Board:new({ lang = lang }):_wordList()
            assert.is_true(#pool > 1000)
            for _, w in ipairs(pool) do
                assert.is_false(Blocklist.isBlocked(w, lang), w)
            end
        end)

        it("never hides a blocklisted word in a " .. lang .. " grid", function()
            math.randomseed(7)
            for _ = 1, 30 do
                local b = Board:new({ lang = lang })
                for _, w in ipairs(b.word_list) do
                    assert.is_false(Blocklist.isBlocked(w.word, lang), w.word)
                end
            end
        end)
    end
end)

-- "lynch" and its forms were missing from the shared blocklist: a game could
-- draw or reveal LYNCH (EN) or LYNCHAGE (FR). LYNCHPIN is another word.
describe("blocklist: lynch", function()
    it("blocks every English and French form, in any case", function()
        for _, w in ipairs({ "LYNCH", "lynched", "Lynches", "LYNCHING", "LYNCHER", "lynchers" }) do
            assert.is_true(Blocklist.isBlocked(w, "en"), w)
        end
        for _, w in ipairs({ "lyncher", "LYNCHAGE", "lynchee", "lyncheurs" }) do
            assert.is_true(Blocklist.isBlocked(w, "fr"), w)
        end
        assert.is_false(Blocklist.isBlocked("LYNCHPIN", "en"))
    end)
end)
