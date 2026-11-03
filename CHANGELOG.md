# Changelog

All notable changes to this project will be documented in this file.

## [1.4.1] - 2026-11-03

### Changed
- Picks up game-common 1.11.0: the shared on-screen keyboard (where used)
  gives every key the same letter size, and the no-repeat history helper.

## [1.4.0] - 2026-11-02

### Added
- Multiplayer mode ("Word Search · multiplayer" under Tools → Games → Party
  & quiz, or Mode: Multiplayer in the menu): 2 to 8 players race on one
  shared grid. Whoever spots a word traces it and taps their name in "Who
  found it?"; the word is ticked with their initial and scores its length
  (or 1 point per word). Optional clock (3, 5 or 10 minutes); a round ends
  when every word is found or time is up (missed words are shown); a match
  is 1, 2, 3 or 5 grids, with scores after each and a final winner. The
  match in progress is saved apart from the solo grid. Separate
  multiplayer rules. Needs game-common with party.lua.

### Changed
- Family-friendly words: the game is also played at a family table, so it
  never hides a vulgar, sexual, scatological, slur or drug-related word in
  the grid any more (`blocklist.lua`, applied when the word lists load) --
  69 English and 113 French words, e.g. CACA and SUCEUR.

## [1.3.1] - 2026-11-02

### Changed
- Listed under **Tools → Games**, grouped by category, instead of its own
  entry in the Tools menu (game-common 1.9.1).

## [1.3.0] - 2026-10-30

### Added
- "Daily Challenge" in the menu, right after "New game": today's puzzle at
  your size and difficulty, the same grid for everyone playing it today.
  Needs game-common 1.7.0.

## [1.2.0] - 2026-10-30

### Changed
- Redesigned play screen: the grid is larger, filling the room the word list
  leaves, with a single frame around it. The word list's height is reserved
  up front, so ticking words off never pushes it off the screen.
- The status line reads "12×12 · Found: 3/10" and wraps in landscape instead
  of being cut off.
- The title-bar menu shows "Language: …" (was the bare "EN" / "FR").
- Once every word is found, "New game" appears under the word list, so the
  next round no longer needs the menu.

### Fixed
- The last word found was never ticked in the list.
- Letters were sized from the cell and then scaled again for the screen's
  DPI, so they could overflow their cells; they are now fitted and centred.

## [1.1.19] - 2026-10-07

### Fixed
- The Tools menu entry is translated again. `main.lua` took `_` from
  KOReader's `gettext`, which knows nothing of this plugin's strings, so the
  menu label stayed English while the game's own screen, which goes through
  `i18n`, was translated. `_` now comes from `i18n` here too.


## [1.1.18] - 2026-10-01

### Fixed
- Picks up game-common v1.5.0. Play statistics were recorded under a key no
  tool could match: `ReaderUI`/`FileManager:registerModule()` rewrite a plugin
  instance's `name` to `reader<id>` / `filemanager<id>` right after it is
  built, so this game's sessions were split across two rows and neither
  carried its plugin id. Rows written under the old keys are merged back on
  first read. The same release brings the `stopPlugin()` /
  `deletePluginSettings()` hooks KOReader 2026.07 calls when a plugin is
  deleted from the device (PR #15240).

  No change to this plugin's own code -- it inherits all of it from the
  shared library.

## [1.1.14] - 2026-08-03

### Fixed
- The word list was rendered with a single-line, non-wrapping widget, so
  it routinely ran wider than the screen and part of it was left
  invisible. It's now shown in a width-bound, auto-height text box that
  wraps to as many lines as needed.

### Changed
- Puzzles now place 12-16 words (was 8-10) on a larger 12x12 grid (was
  10x10).
- Word placement now tries all 8 directions (previously only
  right/down/diagonal-down-right) and prefers positions that cross an
  already-placed word's matching letter, so words intersect far more
  often instead of only by chance.

## [1.1.13] - 2026-07-31

### Fixed
- `board_widget.lua` referenced Blitbuffer color constants that don't
  exist (COLOR_GRAY_C / COLOR_GRAY_A), which evaluated to `nil` and crashed the
  color-comparison in `paintTo()` as soon as the corresponding
  highlight was drawn. Now uses the correct constant name(s)
  (COLOR_GRAY / COLOR_LIGHT_GRAY).

## [1.1.10] - 2026-07-29

### Fixed
- The English and French word pools were hand-picked tables of only
  ~30 words each, hardcoded in board.lua, so the same handful of words
  resurfaced constantly across generated puzzles. Both pools are now
  loaded from new shared, vetted word files (`words_en.lua`,
  `words_fr.lua`, also used by anagram.koplugin and hangman.koplugin):
  9283 English words (Google Books frequency list intersected with a
  proper dictionary to drop proper nouns/typos) and 9000 French words
  (OpenSubtitles frequency list intersected with the project's
  Scrabble-valid FR dictionary), both filtered to a consistent 4-7
  letters.
