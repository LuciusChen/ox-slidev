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
- Purpose: cover richer Slidev-specific syntax and the fixed demo build.
- Use when: changing advanced components, layout wrappers, or demo output.
