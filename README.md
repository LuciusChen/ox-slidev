# ox-slidev

`ox-slidev` exports Org files to [Slidev](https://sli.dev/) Markdown and adds a small command layer for local preview.

The repository currently contains:

- `ox-slidev.el`: the Org export backend
- `org-slidev.el`: user commands for export, preview, and auto-export

## Status

This is an MVP. The core workflow is in place:

1. Write slides in Org.
2. Export to Slidev Markdown.
3. Start `slidev` for live preview.

## Requirements

- Emacs 27.1+
- Org 9.5+
- Node.js
- `slidev` available on `PATH`, or configure `org-slidev-slidev-executable`

## Load

Add the repository to `load-path`, then require the packages:

```elisp
(add-to-list 'load-path "/path/to/ox-slidev")
(require 'ox-slidev)
(require 'org-slidev)
```

## Basic usage

Open an Org file and run:

```text
M-x org-slidev-insert-starter
M-x org-slidev-set-layout
M-x org-slidev-set-frontmatter
M-x org-slidev-insert-block
M-x org-slidev-export-to-file
M-x org-slidev-preview
M-x org-slidev-stop-server
```

If you want automatic re-export on save:

```text
M-x org-slidev-auto-export-mode
```

For block expansion via `org-tempo` without overriding built-in templates:

```text
M-x org-slidev-install-structure-templates
```

This installs non-conflicting keys such as `<svnotes`, `<svright`, `<svclicks`,
and `<svfragment`.

## Read This First

If you want to start writing, read only these two files:

1. [docs/slidev-correspondence.md](docs/slidev-correspondence.md)
   Visible result -> Slidev syntax -> Org syntax.
2. [docs/walkthrough.md](docs/walkthrough.md)
   One real deck from metadata to preview, based on `showcase.org`.

Everything else is reference material:

- [docs/minimal-authoring.md](docs/minimal-authoring.md): stable authoring rules
- [docs/mapping.md](docs/mapping.md): full mapping contract
- [docs/fixtures.md](docs/fixtures.md): sample deck index

## Recommended Path

1. Plain Org first.
2. Stable `ox-slidev` syntax only when it removes repetition.
3. Advanced Slidev-specific syntax only when the deck clearly benefits.
4. Raw `export slidev` as the last resort.

Minimal example:

```org
#+TITLE: Demo
#+SLIDEV_THEME: seriph

* Intro
Hello Slidev

* Notes
#+begin_notes
Talk track for this slide.
#+end_notes

* Flow
#+begin_clicks at=2
- one
- two
#+end_clicks
```

Use advanced syntax sparingly:
- headline property drawers for layout/frontmatter, plus `fragment` and `clicks`
  for repeated Slidev patterns
- `slidev:` inline links for occasional components
- `component` or raw `export slidev` only when there is no simpler readable form

Starter deck:
- built-in template: [starter.org](/home/lucius/ox-slidev/templates/starter.org)
- insert command: `M-x org-slidev-insert-starter`

Demo deck:
- visible demo build now uses [showcase.org](/home/lucius/ox-slidev/test/fixtures/showcase.org)
- richer regression/demo coverage with realistic presentation content and a
  broader set of mapped Slidev features

## Development

Run tests with:

```sh
make test
```

Run byte compilation with:

```sh
make compile
```

Run the end-to-end Slidev smoke build with:

```sh
make smoke
```

Build a fixed demo directory you can inspect locally:

```sh
make demo-build
make demo-serve
```

Then open `http://127.0.0.1:4173`.
The built files are written to `test/smoke-dist/`.

The test suite covers the export backend, command-layer behavior, and fixture-based regression output.
