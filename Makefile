EMACS ?= emacs
NPM ?= npm
PYTHON ?= python3
DEMO_SOURCE ?= test/fixtures/showcase.expected.md
DEMO_DIR ?= test/smoke-dist
DEMO_PORT ?= 4173

.PHONY: test compile smoke demo-build demo-serve

compile:
	$(EMACS) -Q --batch \
	  -L . \
	  -f batch-byte-compile \
	  ox-slidev.el \
	  org-slidev.el

test:
	$(EMACS) -Q --batch \
	  --eval "(setq load-prefer-newer t)" \
	  -L . \
	  -L test \
	  -l test/ox-slidev-test.el \
	  -l test/org-slidev-test.el \
	  -f ert-run-tests-batch-and-exit

smoke:
	TMP_DIR=$$(mktemp -d); \
	cp test/fixtures/official-cool.expected.md $$TMP_DIR/slides.md; \
	cd $$TMP_DIR && \
	  $(NPM) init -y >/dev/null 2>&1 && \
	  $(NPM) install @slidev/cli @slidev/theme-seriph >/dev/null && \
	  npx slidev build slides.md --base /

demo-build:
	TMP_DIR=$$(mktemp -d); \
	cp $(DEMO_SOURCE) $$TMP_DIR/slides.md; \
	cd $$TMP_DIR && \
	  $(NPM) init -y >/dev/null 2>&1 && \
	  $(NPM) install @slidev/cli @slidev/theme-seriph >/dev/null && \
	  npx slidev build slides.md --base / >/dev/null && \
	  mkdir -p $(abspath $(DEMO_DIR)) && \
	  cp -R dist/. $(abspath $(DEMO_DIR))/

demo-serve:
	$(PYTHON) -m http.server $(DEMO_PORT) --directory $(DEMO_DIR)
