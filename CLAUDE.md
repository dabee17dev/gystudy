# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A single-page Korean-language quiz app for idioms (관용표현) and proverbs (속담), titled "관용표현 & 속담 퀴즈". The entire application — markup, styles, data, and logic — lives in [index.html](index.html). There is no build step, framework, module system, or test suite; it is plain HTML/CSS/vanilla JS in one file.

## Commands

Vite is the only dependency, used purely as a static dev server (no config file, no bundling):

```bash
npm install       # install vite
npx vite           # serve index.html with hot reload at localhost:5173
npx vite build     # (unused in practice) production build
npx vite preview   # preview a build
```

`npm test` is a placeholder that exits with an error — there are no tests.

You can also just open `index.html` directly in a browser; the app has no server-side dependencies. The one runtime asset it references is `bgm.mp3` (background music), which is not in the repo.

## Architecture

Everything is driven by the `DB` array (in the `<script>` block of [index.html](index.html)), the single source of truth. Each entry is:

```js
{ type: "관용어" | "속담", idiom, meaning, chosung, keywords: [...] }
```

- `chosung` is the Korean initial-consonant hint (e.g. `ㅂㅁㅇ ㅈㄷ` for 발목을 잡다).
- `keywords` are accepted substrings for the free-text "meaning" quiz mode.

The UI is a set of sibling `<div class="container">` / `#*-area` panels that are shown/hidden by toggling `style.display` (`flex` to show, `none` to hide) — there is no router. Navigation functions (`goHome`, `showDict`, `openSetup`, `showSettings`, etc.) manually flip the visible panel and the floating settings button.

Four quiz modes, selected from the main menu and branched on the `currentMode` global inside `loadQuestion` / `submitAnswer`:

1. Meaning → guess the idiom (free text; whitespace-insensitive exact match).
2. Idiom → pick the meaning (multiple choice; 3 distractors pulled from other `DB` entries).
3. Chosung + meaning → guess the idiom (free text exact match).
4. Idiom → write the meaning (free text; correct if any `keywords` substring is present).

Game flow: `openSetup(mode)` → `executeGameStart` (reads nickname/time-limit/round-count) → `startGame` (shuffles `DB`, slices to round count) → `loadQuestion` → `submitAnswer`/`checkOption` → `showFeedback` → `nextQuestion` → `showResult`. Score is `100 / totalRounds` per correct answer. A per-question countdown (`startTimer`/`stopTimer`) auto-fails on timeout when a time limit is set.

Cross-cutting subsystems:
- **Theming**: light/dark via CSS custom properties on `:root` and `[data-theme="dark"]`; `toggleTheme` sets/removes the `data-theme` attribute on `<body>`. State is in-memory only — nothing is persisted to `localStorage`.
- **Audio**: BGM plays through the `#bgm` `<audio>` element; SFX (correct/incorrect) are synthesized on the fly with the Web Audio API in `playSound` (no sound files).
- **Dictionary (도감)**: `showDict` opens a searchable, tabbed browser over `DB` filtered by `type`, rendered by `renderDictList`.

## Conventions

- UI text, comments, and identifiers are predominantly Korean; keep that convention when editing.
- Data-model note: some code defensively reads `item.meaning || item.실상` (a legacy `실상` field), but no current `DB` entry uses `실상` — new entries should use `meaning`.
- When adding quiz content, append objects to the `DB` array with all five fields; the dictionary counts, quiz pools, and multiple-choice distractors all derive from it automatically.
