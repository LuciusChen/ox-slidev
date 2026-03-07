# ox-slidev - Design Reference

This file documents the canonical design decisions for ox-slidev.
Consult it before adding features or changing existing behavior.

---

## Core Principles

- Org expresses document structure. Slidev expresses presentation rendering.
- Default writing should look like ordinary Org. Zero learning cost for simple decks.
- Slide-specific metadata stays explicit and localized (property drawers, keywords).
- Complex Slidev/Vue capability is handled by passthrough, not by new DSL layers.
- Export output must be human-readable and hand-editable Slidev Markdown.
- YAML values must always be serialized through `ox-slidev--yaml-scalar`. Never concatenate raw strings into frontmatter.

---

## Elisp Implementation Rules

These are the project-local Elisp rules distilled from the `clutch` guide and
adapted for ox-slidev.

### Simplicity first

- Question every abstraction. If a helper, wrapper, or new file does not solve a
  concrete current problem, do not add it.
- Prefer a small number of clear files with stable responsibilities over
  cosmetic file splitting.
- Delete dead code outright. Do not keep compatibility shims for internal
  experiments.

### Boundaries

- `ox-slidev.el` owns export translation and formatting only.
- `org-slidev.el` owns interactive commands, preview process management, and
  file/project resolution.
- Do not mix preview-process behavior into the exporter, and do not move export
  formatting logic into command-layer helpers.
- Loading a file must not enable behavior implicitly. Activation must happen via
  command invocation, minor mode enablement, or explicit variable setup.

### Naming

- Public API uses the file prefix: `ox-slidev-` or `org-slidev-`.
- Internal helpers use double-dash private names: `ox-slidev--...`,
  `org-slidev--...`.
- Predicates end in `-p`.
- Unused parameters must be prefixed with `_`.

### State and customization

- User-facing configuration belongs in `defcustom` with precise `:type` and
  `:group`.
- Shared process/cache state uses plain `defvar`.
- Buffer-local state, if introduced later, must use `defvar-local`.

### Control flow

- Prefer flat control flow over nested `let`/`if` pyramids.
- Use `when-let*`, `if-let*`, `pcase`, and small helpers when they make logic
  easier to verify.
- Keep pure data transformation separate from buffer/process side effects.

### Error handling

- Use `user-error` for user-caused problems such as missing file, wrong major
  mode, or missing `slidev` executable.
- Use `error` only for programmer bugs or invariants that should never fail.
- Use `condition-case` only for recoverable failures where export or preview can
  still degrade gracefully.

### Function design

- Interactive commands should be thin wrappers: validate context, call the
  implementation helper, report result.
- Helpers should be named for what they compute, not where they are called.
- Avoid introducing generic utility layers unless at least two concrete callers
  justify them.

### Quality gates

- `make test` must pass after behavior changes.
- Byte-compilation should stay warning-free.
- Changes to export behavior, defaults, authoring guidance, or preview workflow
  must update the docs in the same change.

---

## Files

| File | Responsibility |
|---|---|
| `ox-slidev.el` | ox export backend: translators, frontmatter, pagination |
| `org-slidev.el` | User commands: export-to-file, preview, auto-export mode |
| `test/ox-slidev-test.el` | Export backend ERT coverage |
| `test/org-slidev-test.el` | Command-layer ERT coverage |

---

## Pagination

### Primary rule

```elisp
(setq org-slidev-slide-level 1)   ; global default
#+SLIDE_LEVEL: 2                  ; per-file override (higher priority)
```

| Headline level vs SLIDE_LEVEL | Behavior |
|---|---|
| `level < SLIDE_LEVEL` | Section container. No slide boundary. |
| `level == SLIDE_LEVEL` | New slide. Headline title -> `# Title`. |
| `level > SLIDE_LEVEL` | Sub-heading within slide. `##`, `###`, ... |

### Manual break

```org
#+SLIDE: new
```

Forces a slide boundary at any position regardless of headline level.
Implemented as a keyword translator.

### Priority order

1. Explicit `#+SLIDE: new`
2. Headline level == SLIDE_LEVEL

---

## Frontmatter

### YAML serialization

All frontmatter values pass through `ox-slidev--yaml-scalar` before emission.
The rules, in order:

1. Multi-line string -> YAML literal block (`|-`)
2. Typed scalar (booleans, numbers, JSON arrays/objects, already-quoted strings) -> emit as-is
3. Strings needing quoting (contains `: #`, starts with special chars, leading/trailing space) -> single-quoted
4. Everything else -> plain scalar

Never concatenate raw user values directly into the `---` block.

### Document-level

Org keywords map to the opening frontmatter block.

```org
#+TITLE: Demo
#+AUTHOR: Lucius Chen
#+DATE: 2026-03-06
#+SLIDEV_THEME: seriph
#+SLIDEV_ASPECT: 16/9
#+SLIDEV_BACKGROUND: /bg.png
#+SLIDEV_TRANSITION: fade
#+SLIDEV_FM_monaco: true
#+SLIDEV_FM_routerMode: hash
```

Exports to:

```yaml
---
title: Demo
author: Lucius Chen
date: 2026-03-06
theme: seriph
aspectRatio: 16/9
background: /bg.png
transition: fade
monaco: true
routerMode: hash
---
```

Built-in keyword -> frontmatter key mappings:

| Org keyword | Slidev field |
|---|---|
| `#+TITLE` | `title` |
| `#+AUTHOR` | `author` |
| `#+DATE` | `date` |
| `#+SLIDEV_THEME` | `theme` |
| `#+SLIDEV_LAYOUT` | `layout` |
| `#+SLIDEV_CLASS` | `class` |
| `#+SLIDEV_BACKGROUND` | `background` |
| `#+SLIDEV_ASPECT` | `aspectRatio` |
| `#+SLIDEV_TRANSITION` | `transition` |
| `#+SLIDEV_FM_<key>` | `<key>` |

Post-processing hook: `ox-slidev-document-frontmatter-functions`.
Each function receives `(FM INFO)` and returns a new FM alist.

### Slide-level

Defined in the headline's property drawer.

```org
* My Slide
:PROPERTIES:
:SLIDEV_LAYOUT: center
:SLIDEV_CLASS: text-center
:SLIDEV_BACKGROUND: /images/bg.png
:SLIDEV_FM_image: /images/demo.png
:END:
```

Exports to:

```yaml
---
layout: center
class: text-center
background: /images/bg.png
image: /images/demo.png
---

# My Slide
```

Shorthand properties:

| Property | Slidev field |
|---|---|
| `:SLIDEV_LAYOUT:` | `layout` |
| `:SLIDEV_CLASS:` | `class` |
| `:SLIDEV_BACKGROUND:` | `background` |
| `:SLIDEV_TRANSITION:` | `transition` |
| `:SLIDEV_HIDE:` | `hide` |
| `:SLIDEV_FM_<key>:` | `<key>` |

Post-processing hooks:
- `ox-slidev-slide-frontmatter-functions`: `(FM HEADLINE INFO)` -> new FM alist
- `ox-slidev-slide-body-functions`: `(BODY HEADLINE INFO)` -> new BODY string

### First-slide merge rule

The first slide's property drawer is merged into the document frontmatter block.
If a key appears in both document keywords and the first slide's drawer,
the slide-level value wins.

Subsequent slides each get their own `---` block only if they have properties.
Slides without properties get only the `---` separator.

### First-slide detection

First-slide identity is determined by comparing `(:begin headline)` against
`:first-begin` in the precomputed slide metadata cache
(`ox-slidev--slide-metadata`). The cache is keyed by parse tree object and
computed once per export.

---

## Speaker Notes

```org
#+begin_notes
Speak slowly here. Reference the diagram on the left.
#+end_notes
```

Exports to:

```markdown
<!--
Speak slowly here. Reference the diagram on the left.
-->
```

- `#+BEGIN_NOTES` / `#+END_NOTES` is accepted as an alias.
- Notes are scoped to the slide they appear in.
- Notes content must not appear in the visible slide body.

---

## Layout Slots

The canonical model is the `slot` block with an explicit name.
`left`, `right`, `top`, `bottom` are aliases.

```org
#+begin_slot left
Content for the left column
#+end_slot
```

Alias form:

```org
#+begin_left
Content for the left column
#+end_left
```

Both export to:

```markdown
::left::

Content for the left column
```

A `#+begin_slot` without a name uses `default`.

### Canonical two-cols form

```org
* Two Columns
:PROPERTIES:
:SLIDEV_LAYOUT: two-cols
:SLIDEV_FM_layoutClass: gap-12
:END:

Left column text here.

#+begin_right
Right column text here.
#+end_right
```

The property drawer is the canonical way to declare layout identity.
Slot blocks provide the layout content.

### Rejected layout wrappers

Layout wrapper blocks such as `#+begin_two_cols`, `#+begin_cover`,
`#+begin_image_right`, and related variants are rejected.

Use headline properties for layout identity and frontmatter:

```org
* Two Columns
:PROPERTIES:
:SLIDEV_LAYOUT: two-cols
:SLIDEV_FM_layoutClass: gap-12
:END:
```

Then use slot blocks such as `#+begin_right` only for layout content.

Do not add new layout wrapper blocks. They duplicate Slidev's frontmatter model
inside Org and blur the boundary between layout declaration and content.

---

## Fragment and Clicks

### `fragment` block

```org
#+begin_fragment
- item 1
- item 2
#+end_fragment
```

Exports to:

```html
<div v-click>

- item 1
- item 2

</div>
```

Fragment parameters (space-separated after `#+begin_fragment`):

| Parameter | Effect | Vue directive |
|---|---|---|
| `at=N` or bare `N` | appear on click N | `v-click="N"` |
| `after` | appear after previous click | `v-after` |
| `hide` | hide on click | `v-click-hide` |
| `once` | only show once | `v-click.once` |

### `clicks` block

```org
#+begin_clicks
- First
- Second
- Third
#+end_clicks
```

Exports to:

```html
<v-clicks>

- First
- Second
- Third

</v-clicks>
```

`#+begin_clicks` accepts HTML-style params passed through to `<v-clicks>`.

---

## Component Blocks

### Built-in Slidev component aliases

| Block | Component |
|---|---|
| `toc` | `<Toc />` |
| `arrow` | `<Arrow />` |
| `tweet` | `<Tweet />` |
| `youtube` | `<Youtube />` |
| `powered_by_slidev` / `poweredbyslidev` | `<PoweredBySlidev />` |
| `link` | `<Link>...</Link>` |
| `transform` | `<Transform>...</Transform>` |
| `light_or_dark` / `lightordark` | `<LightOrDark>...</LightOrDark>` |
| `light` | `<template #light>...</template>` |
| `dark` | `<template #dark>...</template>` |

These are the only special blocks that get built-in component alias treatment.
User components should use `component` blocks or `slidev:` links.

### `component` block

```org
#+begin_component MyWidget foo=bar
Content
#+end_component
```

Exports to:

```html
<MyWidget foo="bar">

Content

</MyWidget>
```

### `vdrag` block

```org
#+begin_vdrag 100,200
Draggable content
#+end_vdrag
```

Exports to:

```html
<div v-drag="100,200">

Draggable content

</div>
```

### `slidev:` inline links

Inline component embedding uses Org's native link syntax.

```org
See [[slidev:MyBadge][label text]] for details.
```

Exports to:

```html
See <MyBadge>label text</MyBadge> for details.
```

With attributes:

```org
[[slidev:Arrow::x1=10|y1=20|x2=100|y2=200]]
```

Exports to:

```html
<Arrow x1="10" y1="20" x2="100" y2="200" />
```

---

## Passthrough (Escape Hatch)

For any Slidev or Vue capability not expressible in Org, use export blocks.
This is a first-class design choice.

```org
#+begin_export slidev
<MyComponent :scale="0.8" />
#+end_export
```

`slidev`, `md`, and `markdown` are all treated as aliases and emit content unchanged.

Use passthrough for complex Vue template expressions (`:bind`, `v-for`, `v-model`),
`v-motion`, and anything else not covered above. Do not add new Org DSL wrappers
for one-off Vue expressions.

---

## Code Blocks

```org
#+ATTR_SLIDEV: :code {1,3-5}|monaco-run
#+begin_src typescript
const msg = 'hello'
#+end_src
```

Exports to:

````markdown
```typescript {1,3-5}|monaco-run
const msg = 'hello'
```
````

---

## Tables

Simple Org tables export as GFM markdown tables with alignment markers derived
from column alignment. Complex tables (multiple rule separators, special columns)
fall back to HTML via `org-md--convert-to-html`. Pipe characters in cells are
escaped as `\|`. Newlines within cells become `<br>`.

---

## Images

No attributes -> Markdown image. `:width` present -> `<img>` tag.

```org
#+ATTR_SLIDEV: :width 400px
[[file:screenshot.png]]
```

Exports to `<img src="screenshot.png" width="400px" />`.

---

## Footnotes

Footnote references and definitions export as standard Markdown footnote syntax.
Multi-line footnote bodies are indented with two spaces.

---

## Design Boundary

### What ox-slidev owns

- Document structure -> slide pagination
- Org metadata -> frontmatter YAML
- Speaker notes -> HTML comments
- Column layout slots
- Fragment and clicks
- Built-in Slidev component aliases
- Code fence options, image sizing, footnotes, tables

### What ox-slidev does not own

- Complex Vue template expressions (`:bind`, `v-for`, `v-if`, `v-model`)
- `v-motion` and animation beyond click sequencing
- User-defined Vue components (use `component` block or `slidev:` link)
- Slidev layout internals beyond `layout:` / `layoutClass:`
- Any Slidev feature introduced after this design was written

### Boundary rule

> If a feature requires encoding Slidev's rendering semantics into Org syntax,
> it belongs in passthrough, not in ox-slidev.

---

## Exporter State

First-slide identity is determined via `ox-slidev--slide-metadata`:

1. Walks the parse tree once at first call
2. Collects all slide headline `:begin` positions
3. Caches the result in `ox-slidev--slide-metadata-cache` keyed by parse tree
4. `ox-slidev--first-slide-p` compares `:begin` against `:first-begin`

No INFO plist mutation. No buffer-local mutation.

---

## User Commands (org-slidev.el)

| Command | Description |
|---|---|
| `org-slidev-insert-starter` | Insert built-in starter deck at point |
| `org-slidev-export-to-file` | Export current buffer to `.md` file |
| `org-slidev-export-to-buffer` | Export to `*Org Slidev Export*` buffer |
| `org-slidev-preview` | Export + start Slidev preview + open browser |
| `org-slidev-stop-server` | Kill the running preview server |
| `org-slidev-server-status` | Report server port and PID |
| `org-slidev-show-server-buffer` | Show `*org-slidev*` process buffer |
| `org-slidev-auto-export-mode` | Minor mode: re-export on every save |

### Preview workflow

```text
org-slidev-preview
  -> org-slidev-export-to-file
  -> org-slidev--project-root
  -> start: slidev <target> --port 3030
  -> process filter watches for "Local:" in output
  -> browse-url opens http://localhost:3030
  -> subsequent saves (with auto-export-mode) trigger HMR reload
```

If a server is already running for the same file, only re-exports.

### Project root resolution

`org-slidev--project-root` walks up from the `.md` file looking for markers in
`org-slidev-project-root-files` (default: `package.json`, `pnpm-lock.yaml`,
`yarn.lock`, `package-lock.json`, `.git`). The server runs with
`default-directory` set to the project root; the target passed to Slidev is
relative to that root.

Override by setting `org-slidev-project-root-function` to a function that
takes `MD-FILE` and returns a directory.

### Key variables

| Variable | Default | Description |
|---|---|---|
| `org-slidev-slidev-executable` | `"slidev"` | Supports `"npx slidev"`, multi-word |
| `org-slidev-output-file` | `nil` | `nil` = same dir/name as `.org` |
| `org-slidev-dev-port` | `3030` | Dev server port |
| `org-slidev-open-browser` | `t` | Auto-open browser on server ready |
| `org-slidev-project-root-files` | `'("package.json" ...)` | Root detection markers |
| `org-slidev-project-root-function` | `nil` | Override root resolution entirely |

---

## Running Tests

```bash
make test
```
