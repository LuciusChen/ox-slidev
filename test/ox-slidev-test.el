;;; ox-slidev-test.el --- Tests for ox-slidev -*- lexical-binding: t; -*-

(require 'ert)
(require 'org)
(require 'ox-slidev)

(defmacro ox-slidev-test-with-temp-org (content &rest body)
  "Evaluate BODY in a temporary Org buffer containing CONTENT."
  (declare (indent 1))
  `(with-temp-buffer
     (org-mode)
     (insert ,content)
     (goto-char (point-min))
     ,@body))

(ert-deftest ox-slidev-export-includes-document-frontmatter ()
  (ox-slidev-test-with-temp-org
      "#+TITLE: Demo\n#+AUTHOR: Alice\n#+SLIDEV_THEME: seriph\n\n* Intro\nHello\n"
    (let ((output (org-export-as 'slidev nil nil t)))
      (should (string-match-p "title: Demo" output))
      (should (string-match-p "author: Alice" output))
      (should (string-match-p "theme: seriph" output))
      (should (string-match-p "# Intro" output))
      (should (string-match-p "Hello" output)))))

(ert-deftest ox-slidev-export-separates-subsequent-slides ()
  (ox-slidev-test-with-temp-org
      "* One\nFirst\n\n* Two\nSecond\n"
    (let ((output (org-export-as 'slidev nil nil t)))
      (should (string-match-p "# One" output))
      (should (string-match-p "\n---\n\n# Two" output)))))

(ert-deftest ox-slidev-export-renders-slide-properties ()
  (ox-slidev-test-with-temp-org
      "* Intro\n:PROPERTIES:\n:SLIDEV_LAYOUT: center\n:END:\nBody\n"
    (let ((org-export-with-author nil)
          (output (org-export-as 'slidev nil nil t)))
      (should (string-match-p "layout: center" output))
      (should (string-match-p "# Intro" output)))))

(ert-deftest ox-slidev-export-renders-image-width-attribute ()
  (ox-slidev-test-with-temp-org
      "* Image\n#+ATTR_SLIDEV: :width 320\n[[file:demo.png]]\n"
    (let ((output (org-export-as 'slidev nil nil t)))
      (should (string-match-p "<img src=\"demo.png\" width=\"320\" />" output)))))

(ert-deftest ox-slidev-export-renders-manual-slide-breaks ()
  (ox-slidev-test-with-temp-org
      "* One\n#+SLIDE: new\nMore\n"
    (let ((output (org-export-as 'slidev nil nil t)))
      (should (string-match-p "\n---\n\nMore" output)))))

;;; ox-slidev-test.el ends here
