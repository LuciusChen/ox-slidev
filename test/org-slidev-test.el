;;; org-slidev-test.el --- Tests for org-slidev -*- lexical-binding: t; -*-

(require 'ert)
(require 'org)
(require 'org-slidev)

(ert-deftest org-slidev-export-to-file-supports-explicit-source-file ()
  (let* ((temp-org (make-temp-file "org-slidev-" nil ".org"))
         (temp-md (concat (file-name-sans-extension temp-org) ".md"))
         (buffer nil))
    (unwind-protect
        (progn
          (with-temp-file temp-org
            (insert "#+TITLE: Demo\n\n* Intro\nHello\n"))
          (setq buffer (find-file-noselect temp-org))
          (with-current-buffer buffer
            (org-mode))
          (org-slidev-export-to-file temp-org)
          (should (file-exists-p temp-md))
          (with-temp-buffer
            (insert-file-contents temp-md)
            (let ((output (buffer-string)))
              (should (string-match-p "# Intro" output))
              (should (string-match-p "Hello" output)))))
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (when (file-exists-p temp-org)
        (delete-file temp-org))
      (when (file-exists-p temp-md)
        (delete-file temp-md)))))

;;; org-slidev-test.el ends here
