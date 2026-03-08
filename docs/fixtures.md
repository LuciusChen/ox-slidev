# Fixture Index

These fixture decks are the regression backbone of the project. Each one exists
to prove a different authoring path.

## Baseline

- Source: `test/fixtures/baseline.org`
- Purpose: smallest backend smoke coverage.
- Use when: touching core export behavior.

## Plain Org First

- Source: `test/fixtures/plain-org-first.org`
- Purpose: prove that normal Org content stays readable and useful.
- Use when: checking that custom syntax is not becoming mandatory.

## Minimal Realistic

- Source: `test/fixtures/minimal-realistic.org`
- Purpose: lock the recommended minimal stable surface.
- Use when: refining the preferred authoring path.

## Speaker Flow

- Source: `test/fixtures/speaker-flow.org`
- Purpose: cover reveal flow, notes, and slide pacing.
- Use when: changing fragments, clicks, or note handling.

## Official Cool

- Source: `test/fixtures/official-cool.org`
- Purpose: cover richer mapped Slidev syntax in a compact, advanced demo.
- Use when: changing advanced components or slide layout/frontmatter handling.

## Edge Cases

- Source: `test/fixtures/edge-cases.org`
- Purpose: cover boundary behavior, explicit default slot output, and raw
  Slidev/markdown passthrough.
- Use when: changing escape hatch behavior or deciding whether a feature should
  stay raw instead of becoming new Org syntax.

## Showcase

- Source: `test/fixtures/showcase.org`
- Purpose: provide a more normal presentation-shaped demo with realistic talk
  flow while still covering a broad set of Slidev features.
- Use when: checking the visible demo output or validating everyday talk content.
- Companion doc: [walkthrough.md](./walkthrough.md)
