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
- **Theming**: light/dark via CSS custom properties on `:root` and `[data-theme="dark"]`; `toggleTheme` sets/removes the `data-theme` attribute on `<body>`. The theme is persisted to `localStorage` under the `gystudy-settings` key (`{ isDarkMode }`) via `saveSettings`, and restored on load by `loadSettings`.
- **Dictionary (도감)**: `showDict` opens a searchable, tabbed browser over `DB` filtered by `type`, rendered by `renderDictList`.

(No audio: BGM/SFX were removed in v2.0.0 — the app has no sound.)

## 버전 관리 (Versioning)

이 프로젝트는 **유의적 버전(Semantic Versioning, `MAJOR.MINOR.PATCH`)** 을 따른다.

### 등급 정의

- **MAJOR** — 하위 호환이 깨지는 변경. 예: `DB` 항목 스키마 변경(필드 추가/삭제/의미 변경), 저장된 `localStorage` 데이터를 **기존 코드가 못 읽거나 오해하게 되는** 포맷 변경, 기존 기능 제거, 기존 동작을 바꾸는 대규모 개편.
- **MINOR** — 하위 호환되는 기능 추가·확장. 예: 새 퀴즈 모드, 새 설정 항목, `DB`에 새 관용어/속담 추가, 기존 저장 데이터를 안전하게 무시·확장하는 `localStorage` 필드 추가.
- **PATCH** — 하위 호환되는 버그 수정, 문구 수정, **사용자가 보는 스타일·레이아웃 조정**, 데이터 오류 수정(중복 제거 등).

### 언제 올리는가 (bump 판단)

**기준: "사용자가 체감할 변화"가 있으면 올린다.** 화면 표시, 동작, 데이터/콘텐츠, 눈에 보이는 스타일·레이아웃이 바뀌면 등급(MAJOR/MINOR/PATCH)에 맞춰 버전을 올린다.

**올리지 않는 경우 (버전 유지):** 사용자 눈에 전혀 드러나지 않는 순수 내부·부수 변경.
- 동작 불변 리팩터링(내부 구조/변수명 정리 등 렌더 결과 동일)
- 주석, [CLAUDE.md](CLAUDE.md)·README 등 문서
- 빌드/배포/도구 설정: `.gitignore`, `vercel.json`(배포 동작 변화 없을 때), `.claude/launch.json` 등
- CI·포맷팅 등

판단이 애매하면 "이 변경으로 사용자가 보거나 겪는 것이 달라지는가?"를 묻는다. 달라지면 올리고, 아니면 유지한다. 하나의 버전 bump가 관련된 여러 커밋을 묶어도 된다.

### 버전을 올릴 때 (반드시 함께 수정)

버전 문자열은 **두 곳**에 있으며 항상 동일하게 유지해야 한다:

1. [package.json](package.json) 의 `"version"` — 배포/패키지 기준의 단일 소스.
2. [index.html](index.html) 스크립트 상단의 `const APP_VERSION` — 화면 하단(메인 메뉴)에 `v1.0.0` 형태로 표기되는 값.

둘 중 하나만 바꾸면 표기가 어긋나므로 커밋 전 두 값이 일치하는지 확인한다.

### 릴리스 관례

- 버전을 올리는 커밋 후 해당 커밋에 git 태그를 단다: `git tag v1.2.0 && git push origin v1.2.0`.
- 태그명은 `v` 접두사 + 버전(`vMAJOR.MINOR.PATCH`) 형식.

## Conventions

- UI text, comments, and identifiers are predominantly Korean; keep that convention when editing.
- When adding quiz content, append objects to the `DB` array with all five fields (`type`, `idiom`, `meaning`, `chosung`, `keywords`); the dictionary counts, quiz pools, and multiple-choice distractors all derive from it automatically.
