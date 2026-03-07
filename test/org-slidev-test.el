;;; org-slidev-test.el --- Tests for org-slidev -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'org-slidev)

(ert-deftest org-slidev-starter-template-loads-built-in-template ()
  (let ((template (org-slidev--starter-template)))
    (should (string-match-p "#\\+TITLE: Demo" template))
    (should (string-match-p "#\\+begin_clicks" template))
    (should (string-match-p ":SLIDEV_LAYOUT: two-cols" template))))

(ert-deftest org-slidev-insert-starter-inserts-template-into-org-buffer ()
  (with-temp-buffer
    (org-mode)
    (org-slidev-insert-starter)
    (let ((content (buffer-string)))
      (should (string-match-p "#\\+TITLE: Demo" content))
      (should (string-match-p "\\* Opening" content))
      (should (string-match-p "#\\+begin_src emacs-lisp" content)))))

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

(ert-deftest org-slidev-project-root-detection-uses-markers ()
  (let* ((root (make-temp-file "org-slidev-root-" t))
         (nested (expand-file-name "a/b" root))
         (md-file (expand-file-name "slides.md" nested)))
    (unwind-protect
        (progn
          (make-directory nested t)
          (with-temp-file (expand-file-name "package.json" root) (insert "{}"))
          (with-temp-file md-file (insert "# demo\n"))
          (let ((org-slidev-project-root-function nil))
            (should (equal (file-name-as-directory root)
                           (org-slidev--project-root md-file)))))
      (delete-directory root t))))

(ert-deftest org-slidev-build-dev-args-uses-path-relative-to-project-root ()
  (let* ((root (make-temp-file "org-slidev-root-" t))
         (nested (expand-file-name "deck" root))
         (md-file (expand-file-name "slides.md" nested)))
    (unwind-protect
        (progn
          (make-directory nested t)
          (with-temp-file md-file (insert "# demo\n"))
          (let ((org-slidev-dev-port 4321))
            (should (equal '("deck/slides.md" "--port" "4321")
                           (org-slidev--build-dev-args
                            md-file
                            (file-name-as-directory root))))))
      (delete-directory root t))))

(ert-deftest org-slidev-process-filter-opens-browser-on-ready ()
  (let* ((buf (generate-new-buffer " *org-slidev-filter-test*"))
         (proc (start-process "org-slidev-filter-test" buf "cat"))
         (opened-url nil)
         (next-filter nil)
         (org-slidev-open-browser t)
         (org-slidev-dev-port 3030))
    (unwind-protect
        (cl-letf (((symbol-function 'browse-url)
                   (lambda (url &rest _) (setq opened-url url)))
                  ((symbol-function 'set-process-filter)
                   (lambda (_process filter) (setq next-filter filter))))
          (org-slidev--process-filter proc "Local: http://localhost:3030/\n")
          (should (equal "http://localhost:3030" opened-url))
          (should (eq #'org-slidev--process-filter-plain next-filter)))
      (when (process-live-p proc)
        (delete-process proc))
      (kill-buffer buf))))

(ert-deftest org-slidev-process-sentinel-clears-state-when-process-exits ()
  (let* ((buf (generate-new-buffer " *org-slidev-sentinel-test*"))
         (proc (start-process "org-slidev-sentinel-test" buf "sh" "-c" "exit 0"))
         (org-slidev--process proc)
         (org-slidev--preview-file "/tmp/demo.md"))
    (unwind-protect
        (progn
          (while (process-live-p proc)
            (accept-process-output proc 0.05))
          (org-slidev--process-sentinel proc "finished\n")
          (should (null org-slidev--process))
          (should (null org-slidev--preview-file)))
      (when (buffer-live-p buf)
        (kill-buffer buf)))))

(ert-deftest org-slidev-preview-reuses-running-server-for-same-file ()
  (let ((temp-org (make-temp-file "org-slidev-preview-" nil ".org"))
        (started nil))
    (unwind-protect
        (progn
          (with-temp-file temp-org
            (insert "* Intro\nHello\n"))
          (with-current-buffer (find-file-noselect temp-org)
            (org-mode)
            (cl-letf (((symbol-function 'org-slidev-export-to-file)
                       (lambda (&optional _org-file)
                         (concat (file-name-sans-extension temp-org) ".md")))
                      ((symbol-function 'org-slidev--process-live-p)
                       (lambda () t))
                      ((symbol-function 'org-slidev--start-server)
                       (lambda (_md-file) (setq started t))))
              (setq org-slidev--preview-file
                    (concat (file-name-sans-extension temp-org) ".md"))
              (org-slidev-preview)
              (should (null started)))))
      (delete-file temp-org))))

(ert-deftest org-slidev-preview-starts-server-for-new-file ()
  (let ((temp-org (make-temp-file "org-slidev-preview-" nil ".org"))
        (started-file nil))
    (unwind-protect
        (progn
          (with-temp-file temp-org
            (insert "* Intro\nHello\n"))
          (with-current-buffer (find-file-noselect temp-org)
            (org-mode)
            (cl-letf (((symbol-function 'org-slidev-export-to-file)
                       (lambda (&optional _org-file)
                         (concat (file-name-sans-extension temp-org) ".md")))
                      ((symbol-function 'org-slidev--process-live-p)
                       (lambda () nil))
                      ((symbol-function 'org-slidev--start-server)
                       (lambda (md-file) (setq started-file md-file))))
              (setq org-slidev--preview-file nil)
              (org-slidev-preview)
              (should (equal (concat (file-name-sans-extension temp-org) ".md")
                             started-file)))))
      (delete-file temp-org))))

;;; org-slidev-test.el ends here
