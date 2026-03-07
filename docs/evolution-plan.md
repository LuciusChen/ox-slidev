# ox-slidev Evolution Plan

Goal: evolve from MVP to a practical, Emacs-native authoring workflow that compiles cleanly to Slidev.

## Principles

1. Emacs philosophy:
   - composable functions
   - minimal surprise defaults
   - user-customizable behavior
   - hook points before hardcoding behavior
2. Slidev alignment:
   - generated markdown should be idiomatic Slidev
   - favor explicit mappings over implicit magic
   - keep escape hatches for raw Slidev markdown
3. Development discipline:
   - every feature has tests
   - snapshot tests for export stability
   - e2e fixtures for real deck workflows

## Execution Checklist

- [x] Add explicit extension points for export transforms
  - [x] document-level transform hook
  - [x] per-slide transform hook
  - [x] test coverage for hook invocation and return contract
- [x] Improve frontmatter type handling
  - [x] booleans/numbers/null/json containers
  - [x] multiline scalar behavior
  - [x] tests for valid/invalid edge cases
- [x] Expand Slidev block mappings
  - [x] fragment variants (`v-click`, `v-click.once`, `v-after`, `v-click-hide`)
  - [x] add at least one more high-value block mapping
  - [x] regression tests
- [x] Emacs-native preview UX
  - [x] project root detection for `slidev` cwd
  - [x] robust process restart semantics
  - [x] tests for argument building and state transitions
- [x] End-to-end fixture decks
  - [x] baseline deck
  - [x] "cool" showcase deck using advanced Slidev constructs
  - [x] golden export snapshots
- [x] Full flow verification
  - [x] `make test`
  - [x] run local slidev smoke command when available
  - [x] record any remaining known gaps

## Definition of Done

- tests are green
- mapping docs are updated
- behavior is predictable and overridable via Emacs customization

## Latest Validation Notes

- ERT suite: green (`21/21`)
- ERT suite: green (`27/27`)
- Slidev CLI smoke:
  - initial direct build failed due missing theme package in entry directory context
  - succeeded after preparing a temp project with `@slidev/cli` and `@slidev/theme-seriph`
    and building `official-cool.expected.md` as `slides.md`
  - `make smoke` now automates the same validation path
- Org-native component coverage:
  - added `component`, `toc`, `arrow`, and `vdrag` block mappings
  - updated the official-style fixture to use Org-native syntax instead of raw export blocks
