# Minimal Authoring Surface

This file defines the smallest recommended `ox-slidev` surface for real decks.
Use this first. Reach for more specialized syntax only when the deck actually
needs it.

## Stable Path

1. Org headlines for slide boundaries.
2. `#+TITLE:` and `#+SLIDEV_THEME:` for document metadata.
3. Plain Org text, lists, links, and source blocks.
4. `#+begin_notes` for speaker notes.
5. `#+begin_fragment` and `#+begin_clicks` for reveal flow.
6. `#+begin_two_cols` with `#+begin_right` for common two-column slides.
7. `#+begin_image_right` or `#+begin_image_left` for image-led slides.
8. `[[slidev:...]]` for occasional inline Slidev/Vue components.

## Advanced Path

- `component`: when there is no dedicated alias and the block is still easy to
  read.
- `transform`, `light_or_dark`, `tweet`, `youtube`: when the deck genuinely
  benefits from the Slidev-specific component.

## Escape Hatch

- `#+begin_export slidev`: only when there is no mapped Org form yet.
- Document the reason in the Org source if the raw Slidev block is likely to
  stay for a while.

## Avoid By Default

- Adding new wrapper syntax for one-off slides.
- Depending on implicit behavior that is hard to read from the Org source.
- Replacing plain Org with custom syntax when plain Org already exports well.

## A Practical Rule

If a pattern appears fewer than three times in real decks, do not add a new
syntax layer for it yet.
