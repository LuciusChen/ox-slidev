# Org to Slidev Mapping

This file defines the current mapping contract for `ox-slidev`.
Goal: treat Org as the authoring language and Slidev Markdown as the runtime target.

## Status Legend

- `full`: implemented and covered by tests
- `partial`: implemented with caveats
- `planned`: not implemented yet

## Core Slide Structure

| Org input | Slidev output | Status | Notes |
|---|---|---|---|
| `#+SLIDE_LEVEL: N` | Headline level `N` starts a new slide | full | Defaults to `org-slidev-slide-level` |
| Headline at slide level | `# Title` plus slide boundary | full | First slide merges document + slide frontmatter |
| `#+SLIDE: new` | `---` | full | Manual separator inside a slide |

## Frontmatter

| Org input | Slidev output | Status | Notes |
|---|---|---|---|
| `#+TITLE`, `#+AUTHOR`, `#+DATE` | `title`, `author`, `date` | full | Exported in document frontmatter |
| `#+SLIDEV_THEME` etc. | `theme`, `layout`, `class`, `background`, `aspectRatio`, `transition` | full | Document-level keys |
| `#+SLIDEV_FM_*` | Arbitrary frontmatter keys | full | Key keeps exact suffix casing |
| Headline property `:SLIDEV_*:` | Slide-level frontmatter | full | Currently layout/class/background/transition/hide |
| Frontmatter scalar rendering | YAML-safe scalar | full | Auto-quote unsafe strings; preserve typed literals |

## Special Blocks

| Org input | Slidev output | Status | Notes |
|---|---|---|---|
| `#+begin_notes` | `<!-- ... -->` | full | Speaker notes block |
| `#+begin_slot name` | `::name::` | full | Default name is `default` |
| `#+begin_left/right/top/bottom` | `::left::` etc. | full | Slot aliases |
| `#+begin_fragment` | `<div v-click>...</div>` | full | Default fragment |
| `#+begin_fragment at=2 once` | `<div v-click.once="2">` | full | Numeric token also supported |
| `#+begin_fragment after at=3` | `<div v-after="3">` | full | Progressive reveal after step |
| `#+begin_fragment hide 4` | `<div v-click-hide="4">` | full | Hide-on-click pattern |
| `#+begin_clicks at=2` | `<v-clicks at="2">...</v-clicks>` | full | Slidev click-sequence component |
| `#+begin_toc ...` | `<Toc ... />` | full | Alias for common Slidev TOC component |
| `#+begin_arrow ...` | `<Arrow ... />` | full | Alias for common Slidev arrow component |
| `#+begin_tweet ...` | `<Tweet ... />` | full | Alias for Slidev Tweet component |
| `#+begin_youtube ...` | `<Youtube ... />` | full | Alias for Slidev Youtube component |
| `#+begin_link ...` | `<Link ...>...</Link>` | full | Alias for Slidev Link component |
| `#+begin_powered_by_slidev` | `<PoweredBySlidev />` | full | Alias for Slidev footer badge |
| `#+begin_transform ...` | `<Transform ...>...</Transform>` | full | Alias for Slidev Transform wrapper |
| `#+begin_light_or_dark` | `<LightOrDark>...</LightOrDark>` | full | Works with nested `light` / `dark` blocks |
| `#+begin_light` / `#+begin_dark` | `<template #light>` / `<template #dark>` | full | Intended for use inside `light_or_dark` |
| `#+begin_component Name ...` | `<Name ...>` block | full | Generic component wrapper for Slidev/Vue components |
| `#+begin_vdrag ...` | `<div v-drag ...>` block | full | Draggable block wrapper |
| `[[slidev:Name::foo=bar|flag]]` | `<Name foo="bar" flag />` | full | Inline self-closing component syntax |
| `[[slidev:Name::foo=bar][Body]]` | `<Name foo="bar">Body</Name>` | full | Inline component with body |
| `[[slidev:div::class=\"...\"|@click=\"...\"][Body]]` | Vue attrs with quoted values | full | Supports quoted values and Vue-style attrs inline |

## Blocks and Links

| Org input | Slidev output | Status | Notes |
|---|---|---|---|
| `#+begin_src LANG` | fenced code block | full | `#+ATTR_SLIDEV: :code ...` supported |
| Image link + `#+ATTR_SLIDEV: :width` | `<img width="...">` | full | Without width falls back to markdown image |
| `#+begin_export md/slidev/markdown` | raw passthrough | full | Keeps value unchanged |

## Known Gaps

| Area | Status | Notes |
|---|---|---|
| Tables | partial | Simple tables export as markdown; grouped or special tables fall back to HTML |
| Footnotes | full | Exported as markdown footnotes (`[^id]` / `[^id]: ...`) |
| LaTeX fragments/environments | full | Preserved in markdown form for Slidev math rendering |
| Advanced list attributes | partial | Prefer explicit `clicks` / `fragment` blocks; no implicit list attr magic |
| Rich Vue components in Org syntax | full | Block-style via `component` and inline via `slidev:` links |
| Legacy layout wrapper blocks | rejected | Use headline properties like `:SLIDEV_LAYOUT:` and slot blocks instead |

## Authoring Guidance

1. Prefer plain Org when Slidev-specific syntax does not buy you anything.
2. Use headline property drawers for slide layout/frontmatter.
3. Use slot blocks (`left/right/top/bottom`) only for layout content, not for
   declaring layout identity.
4. Use `#+begin_export slidev` for features that do not yet have an Org mapping.
5. When introducing a new mapping:
   - add translator logic
   - add at least one ERT case
   - update this matrix

## Composite Patterns

1. Use `transform` as a wrapper around components such as `tweet` or
   `youtube` when the visual behavior belongs to the container.
2. Use `light_or_dark` with nested `light` and `dark` blocks for
   theme-dependent content.
3. Combine slot blocks such as `right` with explicit layout frontmatter to stay
   close to Slidev layout semantics.
4. If a component is missing an alias, prefer `component` for block content and
   `slidev:` links for inline content rather than raw export blocks.

## Inline Syntax Notes

1. Inline component attrs are separated with `|` inside the `slidev:` path.
2. Use quoted values for attrs containing spaces, e.g. `class="mt-12 py-1"`.
3. Vue-style attrs such as `@click=...`, `v-if=...`, and `v-show=...` are passed through unchanged.
4. Use link description as component body when you need inline non-self-closing output.

## Extension Hooks

- `ox-slidev-document-frontmatter-functions`:
  post-process merged document frontmatter `(FM INFO) -> FM`.
- `ox-slidev-slide-frontmatter-functions`:
  post-process per-slide frontmatter `(FM HEADLINE INFO) -> FM`.
- `ox-slidev-slide-body-functions`:
  post-process rendered body `(BODY HEADLINE INFO) -> BODY`.
