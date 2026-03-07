# Slidev Result to Org Reference

Use this when you know what you want to see in the slide, but do not yet know
which Slidev or Org syntax to write.

The canonical rule stays the same:

- Slide layout lives in headline properties.
- Slot content lives in `left/right/top/bottom` blocks.
- Reveal behavior lives in `fragment` and `clicks`.
- Complex Vue stays in `export slidev`.

If you stay inside the patterns in this file, you can start writing decks
without first reading the official Slidev docs.

## Quick Start

If you are writing a normal deck, this is enough to begin:

1. Use one headline per slide.
2. Put layout in the headline property drawer.
3. Use plain Org for paragraphs, lists, code, tables, links, and LaTeX.
4. Use `right/left/top/bottom` only when a layout exposes slots.
5. Use `clicks` or `fragment` only when reveal behavior matters.
6. Use `export slidev` only for uncommon Vue or Slidev features.

Minimal deck:

```org
#+TITLE: Demo
#+SLIDEV_THEME: seriph

* Opening
:PROPERTIES:
:SLIDEV_LAYOUT: cover
:END:
Hello Slidev

* Problem
:PROPERTIES:
:SLIDEV_LAYOUT: two-cols
:SLIDEV_FM_layoutClass: gap-12
:END:
Left column text

#+begin_right
Right column text
#+end_right

* Flow
#+begin_clicks at=2
- one
- two
#+end_clicks
```

## Common Slides

These are the main patterns most decks need.

### Cover slide

```org
* Opening
:PROPERTIES:
:SLIDEV_LAYOUT: cover
:SLIDEV_CLASS: text-center
:END:
Research Update

One Org file, one review surface
```

### Two-column explanation

```org
* Problem
:PROPERTIES:
:SLIDEV_LAYOUT: two-cols
:SLIDEV_FM_layoutClass: gap-12
:END:
We want plain Org to remain readable.

- plain text
- explicit metadata
- predictable output

#+begin_right
#+begin_fragment after at=2
Review cost drops when one source serves writing and demo.
#+end_fragment
#+end_right
```

### Image-right slide

```org
* Result
:PROPERTIES:
:SLIDEV_LAYOUT: image-right
:SLIDEV_FM_image: https://cover.sli.dev
:END:
The exported deck preserves ordinary content and math.

Inline result: $f(x) = x^2 + 1$
```

### Quote slide

```org
* Close
:PROPERTIES:
:SLIDEV_LAYOUT: quote
:END:
Readable Org first, Slidev power when it is justified.
```

### Reveal flow slide

```org
* Rollout
#+begin_clicks at=2
1. Keep most slides plain.
2. Add explicit Slidev syntax only where it helps.
3. Lock output with tests before polishing visuals.
#+end_clicks
```

### Code slide

```org
* Example
#+ATTR_SLIDEV: :code {1|3}
#+begin_src emacs-lisp
(setq org-slidev-open-browser t)
(message "export -> preview -> review")
#+end_src
```

### Math slide

```org
* Result
Inline result: $f(x) = x^2 + 1$

\[
\int_0^1 x^2 dx = \frac{1}{3}
\]
```

### Notes slide

```org
* Agenda
- Problem framing
- Working assumptions
- Rollout

#+begin_notes
Pause after the second bullet.
#+end_notes
```

## Result to Syntax Table

The tables below are organized by visible result:

1. What you want in the deck
2. The Slidev markdown shape
3. The `ox-slidev` Org shape

## Core Slide Structure

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Start a new slide | `---` | New headline at `SLIDE_LEVEL`, or `#+SLIDE: new` |
| Slide title | `# Title` | Headline title |
| Sub-heading inside current slide | `## Title` / `### Title` | Deeper Org headline |

Example:

```org
#+SLIDE_LEVEL: 1

* Intro
Hello

* Detail
More text
```

## Frontmatter and Layout

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Whole deck theme | `theme: seriph` | `#+SLIDEV_THEME: seriph` |
| Cover slide | `layout: cover` | `:SLIDEV_LAYOUT: cover` |
| Quote slide | `layout: quote` | `:SLIDEV_LAYOUT: quote` |
| Centered slide | `layout: center` | `:SLIDEV_LAYOUT: center` |
| Two-column slide | `layout: two-cols` | `:SLIDEV_LAYOUT: two-cols` |
| Right-image slide | `layout: image-right` | `:SLIDEV_LAYOUT: image-right` |
| Layout class / spacing | `layoutClass: gap-12` | `:SLIDEV_FM_layoutClass: gap-12` |
| Arbitrary slide frontmatter | `image: ...` | `:SLIDEV_FM_image: ...` |

Example:

```org
* Problem
:PROPERTIES:
:SLIDEV_LAYOUT: two-cols
:SLIDEV_FM_layoutClass: gap-12
:END:
Left side text

#+begin_right
Right side text
#+end_right
```

This is the canonical `two-cols` pattern:

```org
* Problem
:PROPERTIES:
:SLIDEV_LAYOUT: two-cols
:SLIDEV_FM_layoutClass: gap-12
:END:
Left column text.

#+begin_right
Right column text.
#+end_right
```

## Slots and Regions

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Put content in right column | `::right::` | `#+begin_right ... #+end_right` |
| Put content in left column | `::left::` | `#+begin_left ... #+end_left` |
| Put content in top or bottom slot | `::top::` / `::bottom::` | `#+begin_top`, `#+begin_bottom` |
| Explicit slot name | `::name::` | `#+begin_slot name` |

Example:

```org
* Two Cols
:PROPERTIES:
:SLIDEV_LAYOUT: two-cols
:END:

Main text

#+begin_right
Supporting note
#+end_right
```

## Reveal and Animation

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Reveal one block on click | `<div v-click>` | `#+begin_fragment` |
| Reveal block on click 2 | `<div v-click="2">` | `#+begin_fragment at=2` |
| Reveal after click 3 | `<div v-after="3">` | `#+begin_fragment after at=3` |
| Hide on click | `<div v-click-hide="4">` | `#+begin_fragment hide 4` |
| Reveal list item by item | `<v-clicks>` | `#+begin_clicks` |

Example:

```org
* Flow
#+begin_clicks at=2
- one
- two
- three
#+end_clicks

#+begin_fragment after at=3
After-click summary
#+end_fragment
```

## Notes

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Speaker notes only, not visible in slide body | `<!-- ... -->` | `#+begin_notes ... #+end_notes` |

Example:

```org
* Intro
Visible text

#+begin_notes
Pause here before moving on.
#+end_notes
```

## Code and Math

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Regular code block | ```` ```ts ```` | `#+begin_src ts` |
| Slidev code options | ```` ```ts {1,3}|monaco-run ```` | `#+ATTR_SLIDEV: :code {1,3}|monaco-run` |
| Inline math | `$x^2$` | Inline LaTeX fragment |
| Block math | `$$ ... $$` | `\[ ... \]` or `$$ ... $$` |

Example:

```org
* Result
Inline result: $f(x) = x^2 + 1$

\[
\int_0^1 x^2 dx = \frac{1}{3}
\]
```

## Components

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Table of contents | `<Toc />` | `#+begin_toc ... #+end_toc` |
| Arrow | `<Arrow />` | `#+begin_arrow ... #+end_arrow` |
| Tweet | `<Tweet />` | `#+begin_tweet ... #+end_tweet` |
| Youtube video | `<Youtube />` | `#+begin_youtube ... #+end_youtube` |
| Generic block component | `<MyWidget>...</MyWidget>` | `#+begin_component MyWidget ...` |
| Inline component | `<Badge type="warning" />` | `[[slidev:Badge::type=warning]]` |
| Inline component with body | `<Badge>Beta</Badge>` | `[[slidev:Badge][Beta]]` |

Example:

```org
* Motion
#+begin_toc text-sm minDepth=1 maxDepth=2
#+end_toc

Inline badge [[slidev:Badge::type=warning][Beta]]
```

## Images

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Regular markdown image | `![](...)` | Normal image link |
| Width-controlled image | `<img width="400px" />` | `#+ATTR_SLIDEV: :width 400px` + image link |
| Image layout frontmatter | `image: ...` | `:SLIDEV_FM_image: ...` |

Example:

```org
* Gallery
:PROPERTIES:
:SLIDEV_LAYOUT: image-right
:SLIDEV_FM_image: https://cover.sli.dev
:END:

Caption text
```

## Escape Hatch

| Visible result | Slidev markdown | Org input |
|---|---|---|
| Raw Slidev / Vue syntax | emitted unchanged | `#+begin_export slidev ... #+end_export` |

Use this when:

- the feature is real but rare
- the Vue expression is complex
- forcing an Org DSL would make the source harder to read

Example:

```org
#+begin_export slidev
<MyWidget :scale="0.8" v-if="ready" />
#+end_export
```

## Recommended Reading Order

1. Read [minimal-authoring.md](./minimal-authoring.md) first.
2. Use this file when you think in terms of visible slide results.
3. Use [mapping.md](./mapping.md) when you need the full contract.

## When You Need Official Slidev Docs

You usually do not need them for the supported authoring path in this project.

Go to the official docs only when:

1. You want a Slidev feature that this document does not mention.
2. You are writing raw `export slidev` blocks.
3. You need a complex Vue expression such as `v-for`, `v-model`, or `:bind`.
4. You need the exact behavior of a built-in Slidev component that we expose
   only as a thin alias.

If none of those is true, stay in this document and write the deck in Org.

## Official Slidev References

These are the closest official pages to this document's purpose:

- Syntax: <https://sli.dev/guide/syntax>
- Layouts: <https://sli.dev/builtin/layouts>
- Slot sugar: <https://sli.dev/features/slot-sugar>
- Animations: <https://sli.dev/guide/animations>
- Built-in components: <https://sli.dev/builtin/components.html>
