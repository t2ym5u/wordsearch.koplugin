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

local WordSearchScreen = ScreenBase:extend{}

function WordSearchScreen:init()
    local state = self.plugin:loadState()
    local lang  = self.plugin:getSetting("lang", "en")
    self.board  = WordSearchBoard:new{ lang = lang }
    if not self.board:load(state) then
        -- fresh game
    end
    ScreenBase.init(self)
end

function WordSearchScreen:isRoundOver()
    return self.board:allFound()
end

function WordSearchScreen:serializeState()
    return self.board:serialize()
end

function WordSearchScreen:buildLayout()
    local is_landscape = self:isLandscape()

    local title_bar = self:buildTitleBar(_("Word Search"), function()
        return {
            { text = _("New game"),     callback = function() self:onNewGame() end },
            self:makeDailyButtonConfig(),
            { text = self:_langLabel(), callback = function() self:openLangMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
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
    local lang = self.plugin:getSetting("lang", "en")
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
        current_id = self.plugin:getSetting("lang", "en"),
        parent     = self,
        on_select  = function(lang)
            self.plugin:saveSetting("lang", lang)
            if self.lang_btn then
                self.lang_btn:setText(self:_langLabel(), self.lang_btn.width)
            end
            self:onNewGame()
        end,
    }
end

function WordSearchScreen:updateStatus(msg)
    local status
    if msg then
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
    local lang = self.plugin:getSetting("lang", "en")
    return T(_("Language: %1"), lang == "fr" and "FR" or "EN")
end

return WordSearchScreen
