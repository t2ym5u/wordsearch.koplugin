# Changelog

All notable changes to this project will be documented in this file.

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
