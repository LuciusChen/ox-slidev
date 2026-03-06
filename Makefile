EMACS ?= emacs

.PHONY: test

test:
	$(EMACS) -Q --batch \
	  -L . \
	  -L test \
	  -l test/ox-slidev-test.el \
	  -l test/org-slidev-test.el \
	  -f ert-run-tests-batch-and-exit
