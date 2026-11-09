local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local ScreenBase            = require("screen_base")
local MenuHelper            = require("menu_helper")
local Party                 = require("party")
local PartyMatch            = lrequire("party_match")
local WordSearchBoard       = lrequire("board")
local WordSearchBoardWidget = lrequire("board_widget")

-- ---------------------------------------------------------------------------
-- WordSearchScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Word Search — Rules

Find all the hidden words in the letter grid.

Words may be hidden in any direction:
• Horizontally (left→right or right→left)
• Vertically (top→bottom or bottom→top)
• Diagonally (all four diagonal directions)

Tap the first letter of a word, then tap the last letter to mark it found.
Found words are crossed off the word list.
Solve the puzzle by finding every word in the list.
]])

local GAME_RULES_FR = [[
Mots Cachés — Règles

Trouvez tous les mots cachés dans la grille de lettres.

Les mots peuvent être cachés dans n'importe quelle direction :
• Horizontalement (gauche→droite ou droite→gauche)
• Verticalement (haut→bas ou bas→haut)
• En diagonale (les quatre directions diagonales)

Appuyez sur la première lettre d'un mot, puis sur la dernière pour le marquer comme trouvé.
Les mots trouvés sont barrés dans la liste.
Résolvez le puzzle en trouvant tous les mots de la liste.
]]

local GAME_RULES_PARTY_EN = [[
Word Search · multiplayer — Rules

For 2 to 8 players around one reader. Lay it in the middle of the table: everyone searches the same grid at the same time.

Setup (title-bar menu)
• Players: how many; Player names: type each name (remembered).
• Rounds: 1, 2, 3 or 5 grids per match.
• Time: 3, 5 or 10 minutes per grid, or No limit.
• Scoring: Word length (a 7-letter word is worth 7 points) or 1 per word.
• Language: the language of the words.

A round
• A new grid and its word list are shown; the clock (if any) starts.
• Words hide in any of the 8 directions, forwards or backwards.
• Whoever spots a word says so and traces it: tap its first letter, then its last letter.
• The reader asks "Who found it?": tap the finder's name. The word is ticked in the list with their initial, e.g. "✓ CAMEL (A)", and their points go up. "Nobody" (a slip of the finger, or a word traced for someone else to check) leaves the word to be found. The clock stops while you answer.
• The round ends when every word is found, or when the time is up: the words nobody found are then shown on the grid, and nobody scores them.
• The scores are shown; "Next round" deals the next grid.

End of the match
• After the last round the final scores are shown: the highest total wins. Equal totals are a tie.
• "New game" starts a new match. Closing the reader keeps the match in progress.
]]

local GAME_RULES_PARTY_FR = [[
Mots mêlés · à plusieurs — Règles

De 2 à 8 joueurs autour d'une seule liseuse. Posez-la au milieu de la table : tout le monde cherche dans la même grille en même temps.

Préparation (menu de la barre de titre)
• Joueurs : combien ; Noms des joueurs : tapez chaque nom (ils sont mémorisés).
• Manches : 1, 2, 3 ou 5 grilles par partie.
• Durée : 3, 5 ou 10 minutes par grille, ou Sans limite.
• Points : Longueur du mot (un mot de 7 lettres vaut 7 points) ou 1 par mot.
• Langue : la langue des mots.

Une manche
• Une nouvelle grille et sa liste de mots s'affichent ; le chrono (s'il y en a un) démarre.
• Les mots se cachent dans les 8 directions, à l'endroit ou à l'envers.
• Celui qui repère un mot l'annonce et le trace : touchez sa première lettre, puis sa dernière.
• La liseuse demande « Qui a trouvé ? » : touchez le nom du joueur. Le mot est coché dans la liste avec son initiale, par ex. « ✓ CHAMEAU (A) », et ses points augmentent. « Personne » (un doigt qui a glissé, ou un mot tracé pour vérifier) laisse le mot à trouver. Le chrono s'arrête pendant la réponse.
• La manche se termine quand tous les mots sont trouvés, ou quand le temps est écoulé : les mots que personne n'a trouvés s'affichent alors dans la grille, sans points pour personne.
• Les scores s'affichent ; « Manche suivante » donne la grille suivante.

Fin de la partie
• Après la dernière manche, les scores finaux s'affichent : le plus haut total gagne. À total égal, c'est une égalité.
• « Nouvelle partie » relance une partie. Fermer la liseuse garde la partie en cours.
]]

local MODE_RULES = {
    solo  = { GAME_RULES_EN, GAME_RULES_FR },
    party = { GAME_RULES_PARTY_EN, GAME_RULES_PARTY_FR },
}

local WordSearchScreen = ScreenBase:extend{}

local PARTY_KEY = "party_state"

function WordSearchScreen:init()
    self.party = self.plugin.launch_mode == "party"
    if self.party then
        self:_loadParty()
    else
        self:_loadSolo()
    end
    ScreenBase.init(self)
    self:_startCountdown()
end

function WordSearchScreen:_loadSolo()
    local state = self.plugin:loadState()
    local lang  = self.plugin:getLang({ "fr", "en" })
    self.board  = WordSearchBoard:new{ lang = lang, empty = true }
    if not self.board:load(state) then
        self.board:generate()
    end
    self.match = nil
end

function WordSearchScreen:isRoundOver()
    if self.party then return self.match:isRoundOver(self.board) end
    return self.board:allFound()
end

-- The solo save (setting "state"); a party match keeps its own key, so the
-- solo grid in progress is left as it was.
function WordSearchScreen:serializeState()
    if self.party then return self.plugin:loadState() end
    return self.board:serialize()
end

function WordSearchScreen:closeScreen()
    self:_stopCountdown()
    if self.party then self:_saveParty() end
    ScreenBase.closeScreen(self)
end

function WordSearchScreen:buildLayout()
    local is_landscape = self:isLandscape()

    local title_bar = self:buildTitleBar(_("Word Search"), function()
        if self.party then return self:_partyMenuItems() end
        return {
            { text = _("New game"),     callback = function() self:onNewGame() end },
            self:makeDailyButtonConfig(),
            { text = self:_langLabel(), callback = function() self:openLangMenu() end },
            { text = self:_modeLabel(), callback = function() self:_setMode("party") end },
            self:makeModeRulesButtonConfig(MODE_RULES),
        }
    end)

    -- Word list: wraps to the controls width. Its height is reserved for the
    -- list with every word ticked off, so finding a word never adds a line
    -- and pushes the controls off the bottom of the screen.
    local controls_w = self:getControlsWidth()
    self.status_text:setMaxWidth(controls_w)
    local list_face = Font:getFace("smallinfofont")
    local full = TextBoxWidget:new{
        text      = self:_wordListText(true),
        face      = list_face,
        width     = controls_w,
        alignment = "center",
    }
    local list_h = full:getSize().h
    full:free()
    self.word_list_widget = TextBoxWidget:new{
        text      = self:_wordListText(),
        face      = list_face,
        width     = controls_w,
        height    = list_h,
        alignment = "center",
    }
    local controls = VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self.word_list_widget,
    }
    self.header_widget, self.header_frame, self.scores_widget = nil, nil, nil
    if self.party then
        -- Round and clock on one bold line, in its own frame: the countdown
        -- repaints this box only.
        local header_face = Font:getFace("cfont", 24)
        -- Height reserved for the longest text it can show, so a message
        -- (wrapped in the narrow landscape panel) never moves the list.
        local header_h = 0
        for _i, text in ipairs(self:_headerCandidates()) do
            local tb = TextBoxWidget:new{ text = text, face = header_face, bold = true,
                width = controls_w, alignment = "center" }
            header_h = math.max(header_h, tb:getSize().h)
            tb:free()
        end
        self.header_widget = TextBoxWidget:new{
            text      = self:_headerText(),
            face      = header_face,
            bold      = true,
            width     = controls_w,
            height    = header_h,
            alignment = "center",
        }
        -- Full width and fixed height: the countdown repaints this box only.
        self.header_frame = FrameContainer:new{
            padding = 0, margin = 0, bordersize = 0,
            self.header_widget,
        }
        -- Scores, wrapped; the height is reserved for three-digit totals so
        -- a growing score never pushes the word list down.
        local full_scores = TextBoxWidget:new{
            text = self:_scoresText("000"), face = list_face,
            width = controls_w, alignment = "center",
        }
        local scores_h = full_scores:getSize().h
        full_scores:free()
        self.scores_widget = TextBoxWidget:new{
            text = self:_scoresText(), face = list_face, bold = true,
            width = controls_w, height = scores_h, alignment = "center",
        }
        -- They take the status line's place: messages go to the header.
        controls[1] = self.header_frame
        table.insert(controls, 2, self.scores_widget)
    end

    -- No bottom actions while playing (the grid and the word list are the game); once
    -- the round is over, "New game" appears under the list.
    self.action_bar = nil
    if self:isRoundOver() then
        table.insert(controls, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(controls, self:buildActionBar({}))
    end

    -- Board widget: it draws its own border, so the frame only pads it.
    local frame_pad   = Size.padding.large
    local frame_extra = 2 * frame_pad
    local budget_w, budget_h = self:getBoardBudget(title_bar, controls)
    local board_size = math.max(math.min(budget_w, budget_h) - frame_extra, 100)
    self.board_widget = WordSearchBoardWidget:new{
        board        = self.board,
        max_width    = board_size,
        max_height   = board_size,
        onSelectWord = function(r1, c1, r2, c2)
            self:onSelectWord(r1, c1, r2, c2)
        end,
    }

    local board_frame = FrameContainer:new{
        padding    = frame_pad,
        margin     = 0,
        bordersize = 0,
        self.board_widget,
    }

    if is_landscape then
        local content = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        self:buildPortraitLayout(title_bar, board_frame,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
    self:updateStatus()
end

-- all_found: render every word as ticked off (used to reserve the height).
function WordSearchScreen:_wordListText(all_found)
    local board = self.board
    local parts = {}
    if self.party then
        local tags = PartyMatch.tags(self.match.scores.names)
        local longest = ""
        for _i, t in ipairs(tags) do if #t > #longest then longest = t end end
        for i, entry in ipairs(board.word_list) do
            local state, who = self.match:wordState(board, i)
            -- Missed words (time up) stay unticked; the grid shows them.
            -- No-break spaces keep a word and its tag on one line.
            if all_found then
                parts[#parts + 1] = T("\xE2\x9C\x93\u{00A0}%1\u{00A0}(%2)", entry.word, longest)
            elseif state == "found" then
                parts[#parts + 1] = T("\xE2\x9C\x93\u{00A0}%1\u{00A0}(%2)", entry.word, tags[who])
            else
                parts[#parts + 1] = entry.word
            end
        end
        return table.concat(parts, "  ")
    end
    for i, entry in ipairs(board.word_list) do
        if all_found or board.found[i] then
            parts[#parts + 1] = "\xE2\x9C\x93 " .. entry.word
        else
            parts[#parts + 1] = entry.word
        end
    end
    return table.concat(parts, "  ")
end

function WordSearchScreen:onSelectWord(r1, c1, r2, c2)
    if self.party then return self:_partySelectWord(r1, c1, r2, c2) end
    local result, word = self.board:tapCell(r1, c1, r2, c2)
    if result == "found" then
        self.board_widget:refresh()
        self:updateStatus(T(_("Found: %1!"), word))
        self.plugin:saveState(self.board:serialize())
        if self.board:allFound() then
            -- Rebuild: ticks the last word too and brings up "New game".
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
            self:updateStatus(_("Congratulations! All words found!"))
        else
            self:_refreshWordList()
        end
    else
        self:updateStatus(_("No match. Try again."))
    end
end

function WordSearchScreen:_refreshWordList()
    if self.word_list_widget then
        self.word_list_widget:setText(self:_wordListText())
    end
end

function WordSearchScreen:onNewGame()
    if self.party then return self:onNewMatch() end
    local lang = self.plugin:getLang({ "fr", "en" })
    self.board = WordSearchBoard:new{ lang = lang }
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function WordSearchScreen:openLangMenu()
    local items = {
        { id = "en", text = _("English") },
        { id = "fr", text = _("Français") },
    }
    MenuHelper.openPickerMenu{
        title      = _("Language"),
        items      = items,
        current_id = self.plugin:getLang({ "fr", "en" }),
        parent     = self,
        on_select  = function(lang)
            self.plugin:setLang(lang)
            if self.lang_btn then
                self.lang_btn:setText(self:_langLabel(), self.lang_btn.width)
            end
            self:onNewGame()
        end,
    }
end

function WordSearchScreen:updateStatus(msg)
    local status
    if self.party then
        -- A message shows in the header for a few seconds (or until the
        -- next action when there is no clock).
        self.header_msg, self.header_msg_ticks = msg, 3
        if self.scores_widget then self.scores_widget:setText(self:_scoresText()) end
        if self.header_widget then self.header_widget:setText(self:_headerText()) end
        status = ""
    elseif msg then
        status = msg
    elseif self.board:allFound() then
        status = _("All words found!")
    else
        status = self:joinStatus(
            T("%1×%1", self.board.size),
            T(_("Found: %1/%2"), self.board:foundCount(), #self.board.word_list))
    end
    ScreenBase.updateStatus(self, status)
end

function WordSearchScreen:_langLabel()
    local lang = self.plugin:getLang({ "fr", "en" })
    return T(_("Language: %1"), lang == "fr" and "FR" or "EN")
end

-- ---------------------------------------------------------------------------
-- Mode: solo / multiplayer
-- ---------------------------------------------------------------------------

function WordSearchScreen:_modeLabel()
    return T(_("Mode: %1"), self.party and _("Multiplayer") or _("Solo"))
end

-- Switching starts a multiplayer match; back to solo, the solo grid in
-- progress comes back (its save is never touched by a match).
function WordSearchScreen:_setMode(mode)
    self:_stopCountdown()
    if self.party then
        self:_saveParty()
    else
        self.plugin:saveState(self.board:serialize())
    end
    self.plugin.launch_mode = mode
    self.party = mode == "party"
    if self.party then
        self:_newMatch()
    else
        self:_loadSolo()
    end
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self:_startCountdown()
end

-- ---------------------------------------------------------------------------
-- Multiplayer match
-- ---------------------------------------------------------------------------

function WordSearchScreen:_partyOptions()
    return {
        rounds   = self.plugin:getSetting("party_rounds", 3),
        duration = self.plugin:getSetting("party_duration", 300),
        scoring  = self.plugin:getSetting("party_scoring", "length"),
    }
end

function WordSearchScreen:_newBoard()
    return WordSearchBoard:new{ lang = self.plugin:getLang({ "fr", "en" }) }
end

function WordSearchScreen:_newMatch()
    local names = Party.loadPlayers(self.plugin, Party.loadCount(self.plugin))
    self.match = PartyMatch.new(names, self:_partyOptions())
    self.board = self:_newBoard()
    self:_saveParty()
end

function WordSearchScreen:_loadParty()
    local t = self.plugin:loadState(PARTY_KEY)
    local m = type(t) == "table" and PartyMatch.restore(t.match)
    local board = WordSearchBoard:new{ lang = self.plugin:getLang({ "fr", "en" }), empty = true }
    if m and board:load(t.board) then
        self.match, self.board = m, board
    else
        self:_newMatch()
    end
end

function WordSearchScreen:_saveParty()
    if not self.match then return end
    self.plugin:saveState({ match = self.match:serialize(), board = self.board:serialize() }, PARTY_KEY)
end

function WordSearchScreen:onNewMatch()
    self:_stopCountdown()
    self:_newMatch()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self:_startCountdown()
end

function WordSearchScreen:onNextRound()
    if not (self.match:isRoundOver(self.board) and not self.match:isLastRound()) then return end
    self.match:startRound()
    self.board = self:_newBoard()
    self:_saveParty()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self:_startCountdown()
end

function WordSearchScreen:getRoundOverButtons()
    if not self.party then return ScreenBase.getRoundOverButtons(self) end
    local scores = { text = _("Scores"), callback = function() self:_showScores() end }
    if self.match:isLastRound() then
        return { scores, { text = _("New game"), callback = function() self:onNewMatch() end } }
    end
    return { scores, { text = _("Next round"), callback = function() self:onNextRound() end } }
end

function WordSearchScreen:_showScores()
    local m = self.match
    if m:isOver(self.board) then
        Party.showScoreboard(m.scores, { final = true })
    else
        Party.showScoreboard(m.scores, { title = T(_("Round %1/%2"), m:round(), m.rounds) })
    end
end

-- A traced word is only credited once someone claims it; "Nobody" leaves it
-- to be found (a slip of the finger).
function WordSearchScreen:_partySelectWord(r1, c1, r2, c2)
    if self.match:isRoundOver(self.board) then return end
    local result, _word, i = self.board:tapCell(r1, c1, r2, c2)
    if result ~= "found" then
        self:updateStatus(_("No match. Try again."))
        return
    end
    self.board.found[i] = false
    self:_stopCountdown()
    Party.askWhoFound(self.match.scores.names, { on_pick = function(p)
        self:onWordClaimed(i, p)
    end })
end

function WordSearchScreen:onWordClaimed(i, p)
    local m = self.match
    -- The list ticks the word with the finder's tag, the scores line adds
    -- the points: no message needed.
    if p then m:credit(self.board, i, p) end
    self:_saveParty()
    if m:isRoundOver(self.board) then
        self:_onRoundEnd()
        return
    end
    self:_refreshWordList()
    if self.board_widget then self.board_widget:refresh() end
    self:updateStatus()
    self:_startCountdown()
end

function WordSearchScreen:_onRoundEnd()
    self:_stopCountdown()
    self:_saveParty()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self:_showScores()
end

function WordSearchScreen:_partyMenuItems()
    local plugin = self.plugin
    local opts = self:_partyOptions()
    return {
        { text = _("New game"), callback = function() self:onNewMatch() end },
        { text = T(_("Players: %1"), #self.match.scores.names), callback = function()
            Party.pickCount(plugin, function() self:onNewMatch() end, self)
        end },
        { text = _("Player names"), callback = function()
            Party.editPlayers(plugin, self.match.scores.names, function()
                self:_saveParty()
                self:_refreshWordList()
                self:updateStatus()
            end, self)
        end },
        { text = T(_("Rounds: %1"), opts.rounds), callback = function()
            self:_pickSetting(_("Rounds"), "party_rounds", opts.rounds, PartyMatch.ROUNDS, tostring)
        end },
        { text = T(_("Time: %1"), self:_durationLabel(opts.duration)), callback = function()
            self:_pickSetting(_("Time"), "party_duration", opts.duration, PartyMatch.DURATIONS,
                function(v) return self:_durationLabel(v) end)
        end },
        { text = T(_("Scoring: %1"), self:_scoringLabel(opts.scoring)), callback = function()
            self:_pickSetting(_("Scoring"), "party_scoring", opts.scoring, PartyMatch.SCORINGS,
                function(v) return self:_scoringLabel(v) end)
        end },
        { text = self:_langLabel(), callback = function() self:openLangMenu() end },
        { text = self:_modeLabel(), callback = function() self:_setMode("solo") end },
        self:makeModeRulesButtonConfig(MODE_RULES),
    }
end

-- A match setting: saved, then a new match starts with it.
function WordSearchScreen:_pickSetting(title, key, current, values, label)
    local items = {}
    for _i, v in ipairs(values) do items[#items + 1] = { id = v, text = label(v) } end
    MenuHelper.openPickerMenu{
        title      = title,
        items      = items,
        current_id = current,
        parent     = self,
        on_select  = function(v)
            self.plugin:saveSetting(key, v)
            self:onNewMatch()
        end,
    }
end

function WordSearchScreen:_durationLabel(secs)
    if not secs or secs <= 0 then return _("No limit") end
    return T(_("%1 min"), math.floor(secs / 60))
end

function WordSearchScreen:_scoringLabel(id)
    return id == "word" and _("1 per word") or _("Word length")
end

-- ---------------------------------------------------------------------------
-- Countdown: one tick a second, repainting the timer box only.
-- ---------------------------------------------------------------------------

-- "Round 1/3 · 4:12" (no clock: "Round 1/3"); a message or the end of the
-- round in place of the clock.
function WordSearchScreen:_headerText()
    local m = self.match
    local round = T(_("Round %1/%2"), m:round(), m.rounds)
    if m:isRoundOver(self.board) then
        return self:joinStatus(round, m.time_up and _("Time's up!") or _("All words found!"))
    end
    if self.header_msg then return self.header_msg end
    if not m:hasClock() then return round end
    local t = m.time_left
    return self:joinStatus(round, string.format("%d:%02d", math.floor(t / 60), t % 60))
end

function WordSearchScreen:_headerCandidates()
    local round = T(_("Round %1/%2"), self.match.rounds, self.match.rounds)
    return {
        self:joinStatus(round, "00:00"),
        self:joinStatus(round, _("Time's up!")),
        self:joinStatus(round, _("All words found!")),
        _("No match. Try again."),
    }
end

-- "Alice 7 · Bob 14", a line only breaking between players; with `pad`,
-- every total reads `pad` (to measure the widest it can get).
function WordSearchScreen:_scoresText(pad)
    local scores = self.match.scores
    local parts = {}
    for i, s in ipairs(scores.names) do
        parts[i] = (s .. " " .. (pad or scores.points[i] or 0)):gsub(" ", "\u{00A0}")
    end
    return table.concat(parts, ScreenBase.STATUS_SEP)
end

function WordSearchScreen:_startCountdown()
    self:_stopCountdown()
    local m = self.match
    if not (self.party and m and m:hasClock()) or m:isRoundOver(self.board) then return end
    local gen = self._tick_gen
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

function WordSearchScreen:_stopCountdown()
    -- Any pending tick sees a newer generation and does nothing.
    self._tick_gen = (self._tick_gen or 0) + 1
end

function WordSearchScreen:_onTick(gen)
    if gen ~= self._tick_gen or not self.party then return end
    if self.match:tick() then
        self.match:revealMissed(self.board)
        self:_onRoundEnd()
        return
    end
    if self.header_msg then
        self.header_msg_ticks = (self.header_msg_ticks or 0) - 1
        if self.header_msg_ticks <= 0 then self.header_msg = nil end
    end
    if self.header_widget then
        self.header_widget:setText(self:_headerText())
        local frame = self.header_frame
        UIManager:setDirty(self, function() return "fast", frame.dimen end)
    end
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

-- The word lists are only needed while a game is open: drop them when the
-- screen closes (the next game reads its language's list again).
function WordSearchScreen:onCloseWidget()
    WordSearchBoard.release()
end

return WordSearchScreen
