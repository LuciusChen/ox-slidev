# ox-slidev

`ox-slidev` exports Org files to [Slidev](https://sli.dev/) Markdown and adds a small command layer for local preview.

The repository currently contains:

- `ox-slidev.el`: the Org export backend
- `org-slidev.el`: user commands for export, preview, and auto-export

## Status

This is an MVP. The core workflow is in place:

1. Write slides in Org.
2. Export to Slidev Markdown.
3. Start `slidev dev` for live preview.

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
M-x org-slidev-export-to-file
M-x org-slidev-preview
M-x org-slidev-stop-server
```

If you want automatic re-export on save:

```text
M-x org-slidev-auto-export-mode
```

## Example

```org
#+TITLE: Demo
#+AUTHOR: Alice
#+SLIDEV_THEME: seriph

* Intro
Hello Slidev

* Code
#+ATTR_SLIDEV: :code {1|3}
#+begin_src emacs-lisp
(message "hello")
#+end_src

* Image
#+ATTR_SLIDEV: :width 320
[[file:demo.png]]

* Notes
#+begin_notes
Talk track for this slide.
#+end_notes
```

## Supported MVP features

- `#+SLIDE_LEVEL:` to choose which headline level starts a new slide
- document frontmatter from Org keywords like `#+TITLE:` and `#+AUTHOR:`
- Slidev frontmatter keywords such as `#+SLIDEV_THEME:`
- slide-level frontmatter from property drawers
- `#+SLIDE: new` manual slide separators
- special blocks: `notes`, `slot`, `left`, `right`, `top`, `bottom`, `fragment`
- fenced code blocks with `#+ATTR_SLIDEV: :code ...`
- image width via `#+ATTR_SLIDEV: :width ...`
- preview server helpers from `org-slidev.el`

## Development

Run tests with:

```sh
make test
```

The test suite covers the export backend and the command-layer export path.
