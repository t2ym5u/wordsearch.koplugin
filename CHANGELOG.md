# Changelog

All notable changes to this project will be documented in this file.

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
