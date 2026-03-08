;;; ox-slidev-test.el --- Tests for ox-slidev -*- lexical-binding: t; -*-

(require 'ert)
(require 'org)
(require 'ox-slidev)

(defmacro ox-slidev-test-with-temp-org (content &rest body)
  "Evaluate BODY in a temporary Org buffer containing CONTENT."
  (declare (indent 1))
  `(with-temp-buffer
     (let ((org-link-parameters (copy-tree org-link-parameters)))
       (org-link-set-parameters "slidev" :export #'ox-slidev--export-slidev-link)
       (org-mode)
       (insert ,content)
       (goto-char (point-min))
       ,@body)))

(defun ox-slidev-test--read-file (path)
  "Return full file contents from PATH."
  (with-temp-buffer
    (insert-file-contents path)
    (buffer-string)))

(defun ox-slidev-test--export-current-buffer ()
  "Export current Org buffer to Slidev markdown in a local export context."
  (let ((org-link-parameters (copy-tree org-link-parameters)))
    (org-link-set-parameters "slidev" :export #'ox-slidev--export-slidev-link)
    (org-export-as 'slidev nil nil t)))

(defun ox-slidev-test--export-info ()
  "Return minimal export info plist for the current buffer."
  (list :parse-tree (org-element-parse-buffer)
        :slide-level nil))

(ert-deftest ox-slidev-load-does-not-register-slidev-link-globally ()
  (should-not (assoc "slidev" org-link-parameters)))

(ert-deftest ox-slidev-export-includes-document-frontmatter ()
  (ox-slidev-test-with-temp-org
      "#+TITLE: Demo\n#+AUTHOR: Alice\n#+SLIDEV_THEME: seriph\n\n* Intro\nHello\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "title: Demo" output))
      (should (string-match-p "author: Alice" output))
      (should (string-match-p "theme: seriph" output))
      (should (string-match-p "# Intro" output))
      (should (string-match-p "Hello" output)))))

(ert-deftest ox-slidev-export-separates-subsequent-slides ()
  (ox-slidev-test-with-temp-org
      "* One\nFirst\n\n* Two\nSecond\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "# One" output))
      (should (string-match-p "\n---\n\n# Two" output)))))

(ert-deftest ox-slidev-export-renders-slide-properties ()
  (ox-slidev-test-with-temp-org
      "* Intro\n:PROPERTIES:\n:SLIDEV_LAYOUT: center\n:END:\nBody\n"
    (let ((org-export-with-author nil)
          (output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "layout: center" output))
      (should (string-match-p "# Intro" output)))))

(ert-deftest ox-slidev-export-renders-image-width-attribute ()
  (ox-slidev-test-with-temp-org
      "* Image\n#+ATTR_SLIDEV: :width 320\n[[file:demo.png]]\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<img src=\"demo.png\" width=\"320\" />" output)))))

(ert-deftest ox-slidev-slide-metadata-precomputes-first-slide ()
  (ox-slidev-test-with-temp-org
      "* One\nA\n\n* Two\nB\n"
    (let* ((info (ox-slidev-test--export-info))
           (metadata (ox-slidev--slide-metadata info)))
      (should (plist-get metadata :has-slides))
      (should (= 2 (length (plist-get metadata :begins))))
      (should (= (point-min)
                 (plist-get metadata :first-begin))))))

(ert-deftest ox-slidev-export-renders-simple-table-as-markdown ()
  (ox-slidev-test-with-temp-org
      "* Table\n| A | B |\n|---+---|\n| 1 | 2 |\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p (regexp-quote "| A | B |") output))
      (should (string-match-p (regexp-quote "| ---: | ---: |") output))
      (should (string-match-p (regexp-quote "| 1 | 2 |") output)))))

(ert-deftest ox-slidev-export-falls-back-to-html-for-grouped-table ()
  (ox-slidev-test-with-temp-org
      "* Table\n| A | B |\n|---+---|\n| 1 | 2 |\n|---+---|\n| 3 | 4 |\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<table" output))
      (should (string-match-p "<tbody>" output)))))

(ert-deftest ox-slidev-export-renders-footnotes-as-markdown ()
  (ox-slidev-test-with-temp-org
      "* Notes\nFootnote[fn:1]\n\n[fn:1] Line one\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p (regexp-quote "Footnote[^1]") output))
      (should (string-match-p (regexp-quote "[^1]: Line one") output)))))

(ert-deftest ox-slidev-export-renders-manual-slide-breaks ()
  (ox-slidev-test-with-temp-org
      "* One\n#+SLIDE: new\nMore\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "\n---\n\nMore" output)))))

(ert-deftest ox-slidev-export-renders-default-slot-name ()
  (ox-slidev-test-with-temp-org
      "* One\n#+begin_slot\nDefault body\n#+end_slot\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "::default::" output))
      (should (string-match-p "Default body" output)))))

(ert-deftest ox-slidev-export-accepts-uppercase-notes-block ()
  (ox-slidev-test-with-temp-org
      "* One\n#+BEGIN_NOTES\nHidden note\n#+END_NOTES\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<!--" output))
      (should (string-match-p "Hidden note" output))
      (should (string-match-p "-->" output)))))

(ert-deftest ox-slidev-export-passthroughs-md-export-block ()
  (ox-slidev-test-with-temp-org
      "* One\n#+begin_export md\n<Demo />\n#+end_export\n"
    (should (string-match-p (regexp-quote "<Demo />")
                            (ox-slidev-test--export-current-buffer)))))

(ert-deftest ox-slidev-export-passthroughs-markdown-export-block ()
  (ox-slidev-test-with-temp-org
      "* One\n#+begin_export markdown\n<Demo />\n#+end_export\n"
    (should (string-match-p (regexp-quote "<Demo />")
                            (ox-slidev-test--export-current-buffer)))))

(ert-deftest ox-slidev-export-passthroughs-slidev-export-block ()
  (ox-slidev-test-with-temp-org
      "* One\n#+begin_export slidev\n<Demo />\n#+end_export\n"
    (should (string-match-p (regexp-quote "<Demo />")
                            (ox-slidev-test--export-current-buffer)))))

(ert-deftest ox-slidev-export-quotes-frontmatter-strings-safely ()
  (ox-slidev-test-with-temp-org
      "#+TITLE: Demo: Q&A #1\n\n* Intro\nHello\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "title: 'Demo: Q&A #1'" output)))))

(ert-deftest ox-slidev-export-keeps-typed-slide-frontmatter-scalars ()
  (ox-slidev-test-with-temp-org
      "* Intro\n:PROPERTIES:\n:SLIDEV_HIDE: true\n:END:\nBody\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "hide: true" output))
      (should-not (string-match-p "hide: 'true'" output)))))

(ert-deftest ox-slidev-export-validates-json-frontmatter-literals ()
  (ox-slidev-test-with-temp-org
      "#+SLIDEV_FM_FOO: [1, 2, 3]\n#+SLIDEV_FM_BAD: {invalid}\n\n* Intro\nHello\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p (regexp-quote "FOO: [1, 2, 3]") output))
      (should (string-match-p (regexp-quote "BAD: '{invalid}'") output)))))

(ert-deftest ox-slidev-export-renders-fragment-params ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_fragment at=2 once\nstep\n#+end_fragment\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<div v-click\\.once=\"2\">" output))
      (should (string-match-p "step" output)))))

(ert-deftest ox-slidev-export-renders-fragment-after ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_fragment after at=3\nlater\n#+end_fragment\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<div v-after=\"3\">" output))
      (should (string-match-p "later" output)))))

(ert-deftest ox-slidev-export-renders-fragment-hide ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_fragment hide 4\ngone\n#+end_fragment\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<div v-click-hide=\"4\">" output))
      (should (string-match-p "gone" output)))))

(ert-deftest ox-slidev-export-renders-clicks-component ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_clicks at=2\n- one\n- two\n#+end_clicks\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<v-clicks at=\"2\">" output))
      (should (string-match-p "</v-clicks>" output)))))

(ert-deftest ox-slidev-export-renders-component-attrs-with-spaces ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_clicks class=\"text-sm mx-auto\" at=2\n- one\n#+end_clicks\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<v-clicks class=\"text-sm mx-auto\" at=\"2\">" output)))))

(ert-deftest ox-slidev-export-renders-two-cols-layout-from-properties ()
  (ox-slidev-test-with-temp-org
      "* Intro\n:PROPERTIES:\n:SLIDEV_LAYOUT: two-cols\n:SLIDEV_FM_layoutClass: gap-16\n:END:\nLeft body\n#+begin_right\nRight body\n#+end_right\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "layout: two-cols" output))
      (should (string-match-p "layoutClass: gap-16" output))
      (should (string-match-p "Left body" output))
      (should (string-match-p "::right::" output))
      (should (string-match-p "Right body" output)))))

(ert-deftest ox-slidev-export-renders-two-cols-header-layout-from-properties ()
  (ox-slidev-test-with-temp-org
      "* Intro\n:PROPERTIES:\n:SLIDEV_LAYOUT: two-cols-header\n:END:\nHeader body\n#+begin_left\nLeft body\n#+end_left\n#+begin_right\nRight body\n#+end_right\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "layout: two-cols-header" output))
      (should (string-match-p "Header body" output))
      (should (string-match-p "::left::" output))
      (should (string-match-p "::right::" output)))))

(ert-deftest ox-slidev-export-renders-cover-layout-from-properties ()
  (ox-slidev-test-with-temp-org
      "* Intro\n:PROPERTIES:\n:SLIDEV_LAYOUT: cover\n:SLIDEV_CLASS: hero\n:END:\nWelcome\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "layout: cover" output))
      (should (string-match-p "class: hero" output))
      (should (string-match-p "Welcome" output)))))

(ert-deftest ox-slidev-export-renders-center-layout-from-properties ()
  (ox-slidev-test-with-temp-org
      "* Intro\n:PROPERTIES:\n:SLIDEV_LAYOUT: center\n:END:\nCentered body\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "layout: center" output))
      (should (string-match-p "Centered body" output)))))

(ert-deftest ox-slidev-export-renders-image-right-layout-from-properties ()
  (ox-slidev-test-with-temp-org
      "* Intro\n:PROPERTIES:\n:SLIDEV_LAYOUT: image-right\n:SLIDEV_FM_image: https://example.com/cover.png\n:END:\nText body\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "layout: image-right" output))
      (should (string-match-p "image: 'https://example.com/cover.png'" output))
      (should (string-match-p "Text body" output)))))

(ert-deftest ox-slidev-export-rejects-layout-wrapper-blocks ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_two_cols layoutClass=\"gap-16\"\nLeft body\n#+end_two_cols\n"
    (should-error (ox-slidev-test--export-current-buffer)
                  :type 'user-error)))

(ert-deftest ox-slidev-export-renders-toc-component-alias ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_toc text-sm minDepth=1 maxDepth=2\n#+end_toc\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<Toc text-sm minDepth=\"1\" maxDepth=\"2\" />" output)))))

(ert-deftest ox-slidev-export-renders-arrow-component-alias ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_arrow x1=350 y1=310 x2=195 y2=342 color=#953 width=2 arrowSize=1\n#+end_arrow\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<Arrow x1=\"350\" y1=\"310\" x2=\"195\" y2=\"342\" color=\"#953\" width=\"2\" arrowSize=\"1\" />" output)))))

(ert-deftest ox-slidev-export-renders-tweet-component-alias ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_tweet id=1894208196031267235 scale=0.8\n#+end_tweet\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<Tweet id=\"1894208196031267235\" scale=\"0\\.8\" />" output)))))

(ert-deftest ox-slidev-export-renders-youtube-component-alias ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_youtube id=dQw4w9WgXcQ width=640 height=360\n#+end_youtube\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<Youtube id=\"dQw4w9WgXcQ\" width=\"640\" height=\"360\" />" output)))))

(ert-deftest ox-slidev-export-renders-link-component-alias ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_link href=https://sli.dev target=_blank\nSlidev Docs\n#+end_link\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<Link href=\"https://sli\\.dev\" target=\"_blank\">" output))
      (should (string-match-p "Slidev Docs" output))
      (should (string-match-p "</Link>" output)))))

(ert-deftest ox-slidev-export-renders-powered-by-slidev-component-alias ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_powered_by_slidev\n#+end_powered_by_slidev\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<PoweredBySlidev />" output)))))

(ert-deftest ox-slidev-export-renders-transform-component-alias ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_transform scale=0.9\nZoom me\n#+end_transform\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<Transform scale=\"0\\.9\">" output))
      (should (string-match-p "Zoom me" output))
      (should (string-match-p "</Transform>" output)))))

(ert-deftest ox-slidev-export-renders-light-or-dark-component-alias ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_light_or_dark\n#+begin_light\nLight copy\n#+end_light\n#+begin_dark\nDark copy\n#+end_dark\n#+end_light_or_dark\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<LightOrDark>" output))
      (should (string-match-p "<template #light>" output))
      (should (string-match-p "Light copy" output))
      (should (string-match-p "<template #dark>" output))
      (should (string-match-p "Dark copy" output))
      (should (string-match-p "</LightOrDark>" output)))))

(ert-deftest ox-slidev-export-renders-generic-component-block ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_component Callout type=warning icon=mdi-alert\nCareful\n#+end_component\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<Callout type=\"warning\" icon=\"mdi-alert\">" output))
      (should (string-match-p "Careful" output))
      (should (string-match-p "</Callout>" output)))))

(ert-deftest ox-slidev-export-renders-vdrag-block ()
  (ox-slidev-test-with-temp-org
      "* Intro\n#+begin_vdrag [120,140,220,auto] class=\"w-40 opacity-80\"\nDrag me\n#+end_vdrag\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<div v-drag=\"\\[120,140,220,auto\\]\" class=\"w-40 opacity-80\">" output))
      (should (string-match-p "Drag me" output))
      (should (string-match-p "</div>" output)))))

(ert-deftest ox-slidev-export-renders-inline-slidev-component-link ()
  (ox-slidev-test-with-temp-org
      "* Intro\n[[slidev:carbon:arrow-right::class=inline-block|title=Next]]\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<carbon:arrow-right class=\"inline-block\" title=\"Next\" />" output)))))

(ert-deftest ox-slidev-export-renders-inline-slidev-component-link-with-body ()
  (ox-slidev-test-with-temp-org
      "* Intro\n[[slidev:Badge::type=warning][Beta]]\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<Badge type=\"warning\">Beta</Badge>" output)))))

(ert-deftest ox-slidev-export-renders-inline-slidev-component-link-with-quoted-attrs ()
  (ox-slidev-test-with-temp-org
      "* Intro\n[[slidev:div::class=\"mt-12 py-1\"|@click=\"$slidev.nav.next\"][Go]]\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<div class=\"mt-12 py-1\" @click=\"\\$slidev\\.nav\\.next\">Go</div>" output)))))

(ert-deftest ox-slidev-export-preserves-latex-fragments ()
  (ox-slidev-test-with-temp-org
      "* Math\nInline $x^2$ and \\(y\\).\n\n\\[ z = 1 \\]\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p (regexp-quote "Inline $x^2$ and $y$.") output))
      (should (string-match-p (regexp-quote "$$ z = 1 $$") output)))))

(ert-deftest ox-slidev-export-preserves-block-math-inside-right-slot ()
  (ox-slidev-test-with-temp-org
      "* Math\n:PROPERTIES:\n:SLIDEV_LAYOUT: two-cols\n:END:\nLeft copy\n#+begin_right\n\\[\n\\int_0^1 x^2 dx = \\frac{1}{3}\n\\]\n#+end_right\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "layout: two-cols" output))
      (should (string-match-p "::right::" output))
      (should (string-match-p
               (regexp-quote "$$\n\\int_0^1 x^2 dx = \\frac{1}{3}\n$$")
               output)))))

(ert-deftest ox-slidev-export-preserves-block-math-inside-fragment ()
  (ox-slidev-test-with-temp-org
      "* Math\n#+begin_fragment after at=2\n\\[\nE = mc^2\n\\]\n#+end_fragment\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<div v-after=\"2\">" output))
      (should (string-match-p
               (regexp-quote "$$\nE = mc^2\n$$")
               output))
      (should (string-match-p "</div>" output)))))

(ert-deftest ox-slidev-export-preserves-inline-math-inside-clicks ()
  (ox-slidev-test-with-temp-org
      "* Math\n#+begin_clicks at=2\n- First $x^2$\n- Second $y^2$\n#+end_clicks\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<v-clicks at=\"2\">" output))
      (should (string-match-p (regexp-quote "-   First $x^2$") output))
      (should (string-match-p (regexp-quote "-   Second $y^2$") output))
      (should (string-match-p "</v-clicks>" output)))))

(ert-deftest ox-slidev-export-preserves-src-block-inside-fragment ()
  (ox-slidev-test-with-temp-org
      "* Code\n#+begin_fragment at=2\n#+begin_src emacs-lisp\n(message \"hi\")\n#+end_src\n#+end_fragment\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "<div v-click=\"2\">" output))
      (should (string-match-p (regexp-quote "```emacs-lisp") output))
      (should (string-match-p (regexp-quote "(message \"hi\")") output))
      (should (string-match-p (regexp-quote "```") output))
      (should (string-match-p "</div>" output)))))

(ert-deftest ox-slidev-export-preserves-block-math-inside-right-slot-fragment ()
  (ox-slidev-test-with-temp-org
      "* Math\n:PROPERTIES:\n:SLIDEV_LAYOUT: two-cols\n:END:\nLeft copy\n#+begin_right\n#+begin_fragment after at=3\n\\[\na^2 + b^2 = c^2\n\\]\n#+end_fragment\n#+end_right\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should (string-match-p "layout: two-cols" output))
      (should (string-match-p "::right::" output))
      (should (string-match-p "<div v-after=\"3\">" output))
      (should (string-match-p
               (regexp-quote "$$\na^2 + b^2 = c^2\n$$")
               output)))))

(ert-deftest ox-slidev-export-deck-snapshot-basic-workflow ()
  (ox-slidev-test-with-temp-org
      "#+TITLE: Demo: Q&A #1\n#+AUTHOR: Alice\n#+SLIDEV_THEME: seriph\n#+SLIDEV_FM_LAYOUTS: [\"cover\", \"default\"]\n\n* Intro\n:PROPERTIES:\n:SLIDEV_LAYOUT: cover\n:END:\nHello\n\n* Steps\n#+begin_fragment at=2 once\nStep two\n#+end_fragment\n\n#+SLIDE: new\nManual page\n"
    (let ((output (ox-slidev-test--export-current-buffer)))
      (should
       (equal
        output
        "---\ntitle: 'Demo: Q&A #1'\nauthor: Alice\ntheme: seriph\nLAYOUTS: [\"cover\", \"default\"]\nlayout: cover\n---\n\n# Intro\n\nHello\n\n---\n\n# Steps\n\n<div v-click.once=\"2\">\n\nStep two\n\n</div>\n\n\n---\n\nManual page\n")))))

(ert-deftest ox-slidev-export-applies-document-frontmatter-hook ()
  (let ((ox-slidev-document-frontmatter-functions
         (list (lambda (fm _info)
                 (append fm '(("foo" . "bar")))))))
    (ox-slidev-test-with-temp-org
        "* Intro\nHello\n"
      (let ((output (ox-slidev-test--export-current-buffer)))
        (should (string-match-p "foo: bar" output))))))

(ert-deftest ox-slidev-export-applies-slide-frontmatter-hook ()
  (let ((ox-slidev-slide-frontmatter-functions
         (list (lambda (fm _headline _info)
                 (append fm '(("clicks" . "3")))))))
    (ox-slidev-test-with-temp-org
        "* Intro\nHello\n"
      (let ((output (ox-slidev-test--export-current-buffer)))
        (should (string-match-p "clicks: 3" output))))))

(ert-deftest ox-slidev-export-applies-slide-body-hook ()
  (let ((ox-slidev-slide-body-functions
         (list (lambda (body _headline _info)
                 (replace-regexp-in-string "Hello" "Hi" body)))))
    (ox-slidev-test-with-temp-org
        "* Intro\nHello\n"
      (let ((output (ox-slidev-test--export-current-buffer)))
        (should (string-match-p "Hi" output))
        (should-not (string-match-p "Hello" output))))))

(ert-deftest ox-slidev-export-fixture-baseline-golden ()
  (let* ((root default-directory)
         (org-file (expand-file-name "test/fixtures/baseline.org" root))
         (expected-file (expand-file-name "test/fixtures/baseline.expected.md" root)))
    (with-current-buffer (find-file-noselect org-file)
      (org-mode)
      (should (equal (ox-slidev-test--export-current-buffer)
                     (ox-slidev-test--read-file expected-file))))))

(ert-deftest ox-slidev-export-fixture-edge-cases-golden ()
  (let* ((root default-directory)
         (org-file (expand-file-name "test/fixtures/edge-cases.org" root))
         (expected-file (expand-file-name "test/fixtures/edge-cases.expected.md" root)))
    (with-current-buffer (find-file-noselect org-file)
      (org-mode)
      (should (equal (ox-slidev-test--export-current-buffer)
                     (ox-slidev-test--read-file expected-file))))))

(ert-deftest ox-slidev-export-fixture-official-cool-golden ()
  (let* ((root default-directory)
         (org-file (expand-file-name "test/fixtures/official-cool.org" root))
         (expected-file (expand-file-name "test/fixtures/official-cool.expected.md" root)))
    (with-current-buffer (find-file-noselect org-file)
      (org-mode)
      (should (equal (ox-slidev-test--export-current-buffer)
                     (ox-slidev-test--read-file expected-file))))))

(ert-deftest ox-slidev-export-fixture-minimal-realistic-golden ()
  (let* ((root default-directory)
         (org-file (expand-file-name "test/fixtures/minimal-realistic.org" root))
         (expected-file (expand-file-name "test/fixtures/minimal-realistic.expected.md" root)))
    (with-current-buffer (find-file-noselect org-file)
      (org-mode)
      (should (equal (ox-slidev-test--export-current-buffer)
                     (ox-slidev-test--read-file expected-file))))))

(ert-deftest ox-slidev-export-fixture-speaker-flow-golden ()
  (let* ((root default-directory)
         (org-file (expand-file-name "test/fixtures/speaker-flow.org" root))
         (expected-file (expand-file-name "test/fixtures/speaker-flow.expected.md" root)))
    (with-current-buffer (find-file-noselect org-file)
      (org-mode)
      (should (equal (ox-slidev-test--export-current-buffer)
                     (ox-slidev-test--read-file expected-file))))))

(ert-deftest ox-slidev-export-fixture-plain-org-first-golden ()
  (let* ((root default-directory)
         (org-file (expand-file-name "test/fixtures/plain-org-first.org" root))
         (expected-file (expand-file-name "test/fixtures/plain-org-first.expected.md" root)))
    (with-current-buffer (find-file-noselect org-file)
      (org-mode)
      (should (equal (ox-slidev-test--export-current-buffer)
                     (ox-slidev-test--read-file expected-file))))))

(ert-deftest ox-slidev-export-fixture-showcase-golden ()
  (let* ((root default-directory)
         (org-file (expand-file-name "test/fixtures/showcase.org" root))
         (expected-file (expand-file-name "test/fixtures/showcase.expected.md" root)))
    (with-current-buffer (find-file-noselect org-file)
      (org-mode)
      (should (equal (ox-slidev-test--export-current-buffer)
                     (ox-slidev-test--read-file expected-file))))))

(ert-deftest ox-slidev-export-fixture-official-cool-includes-inline-badge ()
  (let ((output (ox-slidev-test--read-file
                 (expand-file-name "test/fixtures/official-cool.expected.md"
                                   default-directory))))
    (should (string-match-p "<Badge type=\"warning\">Beta</Badge>" output))))

;;; ox-slidev-test.el ends here
