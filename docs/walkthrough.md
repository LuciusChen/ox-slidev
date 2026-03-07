# Walkthrough: From Org File to Slidev Deck

This is the shortest practical path from an empty Org file to a reviewable
Slidev deck.

Use this after [slidev-correspondence.md](./slidev-correspondence.md) if you
want to see how the pieces fit together in one real deck.

The reference source in this walkthrough is:

- [showcase.org](/home/lucius/ox-slidev/test/fixtures/showcase.org)

## Goal

Write one Org file that:

- stays readable during drafting
- exports to stable Slidev markdown
- previews cleanly in Slidev
- stays easy to review as plain text

## Step 1: Start with document metadata

Put deck-wide metadata at the top:

```org
#+TITLE: Research Update
#+AUTHOR: Team Ox
#+SLIDEV_THEME: seriph
#+SLIDEV_FM_DRAWINGS: false
```

This is enough to define:

- deck title
- author
- Slidev theme
- one arbitrary frontmatter key

Use document keywords only for values that truly apply to the whole deck.

## Step 2: Use one headline per slide

The base rule is simple:

- one slide-level headline == one slide
- deeper headlines become sub-headings inside the slide

Example:

```org
* Opening
Research Update

* Agenda
- Problem framing
- Working assumptions
```

If you can express a slide as plain Org, stop there.

## Step 3: Add layout only when the slide really needs it

Most slides do not need layout metadata.
When they do, put it in the headline property drawer.

Cover slide:

```org
* Opening
:PROPERTIES:
:SLIDEV_LAYOUT: cover
:SLIDEV_CLASS: px-14
:END:
Research Update

From Org source to a talk-shaped Slidev deck
```

Two-column slide:

```org
* Problem
:PROPERTIES:
:SLIDEV_LAYOUT: two-cols
:SLIDEV_FM_layoutClass: gap-12
:END:
Left column text

#+begin_right
Right column text
#+end_right
```

The rule is:

- layout identity in properties
- region content in slot blocks

## Step 4: Add reveal flow only where pacing matters

For ordinary static content, use plain lists and paragraphs.
For reveal flow, use explicit blocks.

Progressive list:

```org
* Agenda
#+begin_clicks at=2
- Problem framing
- Working assumptions
- Key result
#+end_clicks
```

Delayed supporting note:

```org
#+begin_right
#+begin_fragment after at=2
Current friction drops when one source can serve writing, review, and demo.
#+end_fragment
#+end_right
```

This keeps reveal behavior visible in the source instead of hiding it in magic
attributes.

## Step 5: Keep normal content as normal Org

The `showcase` deck deliberately uses plain Org for most slide body content:

- paragraphs
- lists
- tables
- links
- LaTeX
- source blocks

Example table slide:

```org
* Signals
The workflow is useful when the review surface gets smaller without losing
Slidev-native features.

| Signal        | Before                | After                    |
|---------------+-----------------------+--------------------------|
| Review unit   | Org + hand-edited md  | One Org source           |
| Preview loop  | Export and inspect    | Export, then Slidev HMR  |
| Final output  | Inconsistent markdown | Stable golden + demo     |
```

Example math slide:

```org
* Result
:PROPERTIES:
:SLIDEV_LAYOUT: image-right
:SLIDEV_FM_image: https://cover.sli.dev
:END:
The exported deck preserves math and ordinary content.

Inline result: $f(x) = x^2 + 1$

\[
\int_0^1 x^2 dx = \frac{1}{3}
\]
```

Example code slide:

```org
* Example
#+ATTR_SLIDEV: :code {1|3}
#+begin_src emacs-lisp
(setq org-slidev-open-browser t)
(message "export -> preview -> review")
#+end_src
```

## Step 6: Use notes as notes

Speaker notes stay in a dedicated block:

```org
#+begin_notes
Set the context before showing details.
#+end_notes
```

This keeps presenter-only content out of the visible slide body.

## Step 7: Export and preview

From Emacs:

```text
M-x org-slidev-export-to-file
M-x org-slidev-preview
```

Or from the generated markdown with Slidev directly:

```sh
slidev path/to/slides.md
```

The full command-layer behavior is documented in [CLAUDE.md](/home/lucius/ox-slidev/CLAUDE.md),
but for normal use you only need export and preview.

## Step 8: Know when to stop adding syntax

The `showcase` deck is intentionally moderate.
It proves a useful rule:

- plain Org first
- explicit Slidev mapping second
- raw Slidev last

Do not add custom syntax just because Slidev has a feature.
Add syntax only when:

1. the feature is real
2. it appears repeatedly in decks
3. the Org source stays readable after the mapping

## Read the Reference Deck

When reading [showcase.org](/home/lucius/ox-slidev/test/fixtures/showcase.org),
notice this sequence:

1. `Opening`: cover layout
2. `Agenda`: clicks + notes
3. `Problem`: two-cols + right slot + fragment
4. `Signals`: plain Org table
5. `Result`: image-right + LaTeX
6. `Rollout`: ordered clicks + notes
7. `Example`: code fence options
8. `Takeaway`: plain list
9. `Close`: quote layout

That is already enough structure for many normal technical talks.

## If You Need More

1. Read [slidev-correspondence.md](./slidev-correspondence.md) for result-to-syntax lookup.
2. Read [minimal-authoring.md](./minimal-authoring.md) for the stable authoring surface.
3. Read [mapping.md](./mapping.md) only when you need the full contract.
