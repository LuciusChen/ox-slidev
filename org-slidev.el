;;; org-slidev.el --- User commands for ox-slidev export and preview -*- lexical-binding: t; -*-

;; Author: ox-slidev contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (org "9.5") (ox-slidev "0.1.0"))
;; Keywords: org, export, slidev, presentation
;; URL: https://github.com/your-repo/ox-slidev

;;; Commentary:

;; User-facing commands for exporting Org files to Slidev and
;; launching the Slidev dev server for live preview.
;;
;; Typical workflow:
;;
;;   1. Write your presentation in an Org file.
;;   2. M-x org-slidev-preview
;;      → exports to slides.md, starts `slidev dev`, opens browser.
;;
;;   3. Edit Org file, M-x org-slidev-export-to-file to re-export.
;;      (or enable org-slidev-auto-export-mode for automatic re-export on save)
;;
;; Requirements:
;;   - Node.js and `slidev` must be available on PATH, or configure
;;     `org-slidev-slidev-executable' to point to the binary.

;;; Code:

(require 'ox-slidev)
(require 'subr-x)


;;; ============================================================
;;; Custom Variables
;;; ============================================================

(defgroup org-slidev nil
  "User commands for Slidev export and preview."
  :tag "Org Slidev"
  :group 'ox-slidev)

(defcustom org-slidev-slidev-executable "slidev"
  "Path or name of the slidev executable.
If slidev is not on PATH, set this to the full path, e.g.:
  \"/usr/local/bin/slidev\"
  \"npx slidev\"
  \"./node_modules/.bin/slidev\""
  :type 'string
  :group 'org-slidev)

(defcustom org-slidev-output-file nil
  "Output .md file path for export.
If nil, defaults to the same directory and base name as the Org
file, with a .md extension.
Example: if nil and source is ~/talks/demo.org, output is ~/talks/demo.md."
  :type '(choice (const nil) file)
  :group 'org-slidev)

(defcustom org-slidev-dev-port 3030
  "Port for the Slidev dev server."
  :type 'integer
  :group 'org-slidev)

(defcustom org-slidev-open-browser t
  "Whether to open the browser automatically after starting the dev server."
  :type 'boolean
  :group 'org-slidev)

(defcustom org-slidev-process-buffer-name "*org-slidev*"
  "Name of the buffer used for the Slidev dev server process."
  :type 'string
  :group 'org-slidev)

(defcustom org-slidev-before-export-hook nil
  "Hook run before exporting an Org file to Slidev Markdown."
  :type 'hook
  :group 'org-slidev)

(defcustom org-slidev-after-export-hook nil
  "Hook run after exporting an Org file to Slidev Markdown.
Functions are called with the output file path as argument."
  :type 'hook
  :group 'org-slidev)


;;; ============================================================
;;; Internal State
;;; ============================================================

(defvar org-slidev--process nil
  "The currently running Slidev dev server process, or nil.")

(defvar org-slidev--preview-file nil
  "The exported Markdown file associated with the running Slidev process.")


;;; ============================================================
;;; Utilities
;;; ============================================================

(defun org-slidev--output-file (&optional org-file)
  "Return the output .md path for ORG-FILE (default: current buffer file)."
  (let ((source (or org-file (buffer-file-name))))
    (unless source
      (user-error "Buffer is not visiting a file; cannot determine output path"))
    (or org-slidev-output-file
        (concat (file-name-sans-extension source) ".md"))))

(defun org-slidev--assert-org-buffer ()
  "Signal an error if the current buffer is not an Org buffer."
  (unless (derived-mode-p 'org-mode)
    (user-error "Current buffer is not an Org buffer")))

(defun org-slidev--command-parts ()
  "Return `org-slidev-slidev-executable' as a shell-style argument list."
  (split-string-and-unquote org-slidev-slidev-executable))

(defun org-slidev--org-buffer-for-file (org-file)
  "Return a visiting buffer for ORG-FILE and ensure it is an Org buffer."
  (let ((buffer (find-file-noselect org-file)))
    (with-current-buffer buffer
      (org-slidev--assert-org-buffer))
    buffer))

(defun org-slidev--slidev-available-p ()
  "Return non-nil if the slidev executable can be found."
  (when-let* ((cmd (car (org-slidev--command-parts))))
    (executable-find cmd)))

(defun org-slidev--process-live-p ()
  "Return non-nil if the Slidev dev server process is currently running."
  (and org-slidev--process
       (process-live-p org-slidev--process)))

(defun org-slidev--get-or-create-process-buffer ()
  "Return the Slidev process buffer, creating it if necessary."
  (get-buffer-create org-slidev-process-buffer-name))

(defun org-slidev--dev-url ()
  "Return the local URL for the Slidev dev server."
  (format "http://localhost:%d" org-slidev-dev-port))

(defun org-slidev--open-browser ()
  "Open the Slidev dev server URL in the default browser."
  (let ((url (org-slidev--dev-url)))
    (message "org-slidev: opening %s" url)
    (browse-url url)))

(defun org-slidev--ready-output-p (output)
  "Return non-nil when OUTPUT looks like Slidev's ready message."
  (or (string-match-p (regexp-quote (org-slidev--dev-url)) output)
      (string-match-p "\\bLocal:\\b" output)))


;;; ============================================================
;;; Export
;;; ============================================================

;;;###autoload
(defun org-slidev-export-to-file (&optional org-file)
  "Export the current Org buffer (or ORG-FILE) to a Slidev Markdown file.
Returns the output file path on success.

The output path is determined by `org-slidev-output-file', or
defaults to the same directory/basename as the source with .md extension."
  (interactive)
  (let* ((buffer (if org-file
                     (org-slidev--org-buffer-for-file org-file)
                   (current-buffer)))
         (source (or org-file (buffer-file-name buffer))))
    (unless source
      (user-error "Buffer is not visiting a file; cannot determine source path"))
    (with-current-buffer buffer
      (org-slidev--assert-org-buffer)
      (let ((outfile (org-slidev--output-file source)))
        (run-hooks 'org-slidev-before-export-hook)
        (message "org-slidev: exporting %s -> %s"
                 (file-name-nondirectory source) outfile)
        (org-export-to-file 'slidev outfile)
        (run-hook-with-args 'org-slidev-after-export-hook outfile)
        (message "org-slidev: export complete -> %s" outfile)
        outfile))))

;;;###autoload
(defun org-slidev-export-to-buffer ()
  "Export the current Org buffer to a temporary Slidev Markdown buffer.
Useful for inspecting export output without writing to disk."
  (interactive)
  (org-slidev--assert-org-buffer)
  (org-export-to-buffer 'slidev "*Org Slidev Export*"
    nil nil nil nil nil
    (lambda () (text-mode))))


;;; ============================================================
;;; Dev Server
;;; ============================================================

(defun org-slidev--start-server (md-file)
  "Start the Slidev dev server for MD-FILE.
Kills any previously running server first."
  (unless (org-slidev--slidev-available-p)
    (user-error
     "Slidev executable not found: %S\nSet `org-slidev-slidev-executable' or install slidev via npm"
     org-slidev-slidev-executable))
  ;; Kill existing process if running
  (when (org-slidev--process-live-p)
    (org-slidev-stop-server))
  (let* ((buf  (org-slidev--get-or-create-process-buffer))
         (args (org-slidev--build-dev-args md-file))
         (parts (org-slidev--command-parts))
         (cmd  (car parts))
         (cmd-args (append (cdr parts) args))
         (default-directory (file-name-directory md-file)))
    (with-current-buffer buf
      (erase-buffer)
      (insert (format "org-slidev: starting server\n  cmd: %s %s\n  file: %s\n\n"
                      cmd (mapconcat #'identity cmd-args " ") md-file)))
    (setq org-slidev--process
          (apply #'start-process
                 "org-slidev-server"
                 buf
                 cmd
                 cmd-args))
    (setq org-slidev--preview-file md-file)
    (set-process-sentinel org-slidev--process #'org-slidev--process-sentinel)
    (set-process-filter  org-slidev--process #'org-slidev--process-filter)
    org-slidev--process))

(defun org-slidev--build-dev-args (md-file)
  "Build argument list for `slidev dev' given MD-FILE."
  (list "dev"
        (file-name-nondirectory md-file)
        "--port" (number-to-string org-slidev-dev-port)))

(defun org-slidev--process-sentinel (process event)
  "Handle Slidev server PROCESS state changes (EVENT)."
  (let ((status (string-trim event)))
    (cond
     ((string-prefix-p "finished" status)
      (message "org-slidev: server stopped"))
     ((string-prefix-p "exited" status)
      (message "org-slidev: server exited (%s) — check %s for details"
               status org-slidev-process-buffer-name))
     ((string-prefix-p "killed" status)
      (message "org-slidev: server killed"))
     (t
     (message "org-slidev: server event: %s" status))))
  (when (not (process-live-p process))
    (setq org-slidev--process nil)
    (setq org-slidev--preview-file nil)))

(defun org-slidev--process-filter (process output)
  "Append OUTPUT from Slidev PROCESS to its buffer.
Also watches for the ready signal to open the browser."
  (when (buffer-live-p (process-buffer process))
    (with-current-buffer (process-buffer process)
      (let ((inhibit-read-only t))
        (goto-char (point-max))
        (insert output))))
  ;; Detect when dev server is ready and open browser
  (when (and org-slidev-open-browser
             (org-slidev--ready-output-p output))
    (org-slidev--open-browser)
    ;; Only open once — replace filter with plain inserter
    (set-process-filter process #'org-slidev--process-filter-plain)))

(defun org-slidev--process-filter-plain (process output)
  "Plain output filter: append OUTPUT to PROCESS buffer only."
  (when (buffer-live-p (process-buffer process))
    (with-current-buffer (process-buffer process)
      (let ((inhibit-read-only t))
        (goto-char (point-max))
        (insert output)))))


;;; ============================================================
;;; Preview Command
;;; ============================================================

;;;###autoload
(defun org-slidev-preview ()
  "Export the current Org buffer and start the Slidev dev server.

Workflow:
  1. Export current buffer → slides.md (or configured output path)
  2. Start `slidev dev' on the exported file
  3. Open browser at http://localhost:PORT (if `org-slidev-open-browser' is t)

If a server is already running for this file, re-exports and reloads
(Slidev's HMR will pick up the change automatically).
If a server is running for a DIFFERENT file, kills it and starts fresh."
  (interactive)
  (org-slidev--assert-org-buffer)
  (let* ((outfile (org-slidev-export-to-file))
         (same-file (and (org-slidev--process-live-p)
                         (equal org-slidev--preview-file outfile))))
    (if same-file
        ;; Server already running for this file.
        ;; Slidev HMR watches slides.md, so re-export is enough.
        (message "org-slidev: re-exported → Slidev HMR will reload automatically")
      ;; Start a fresh server.
      (org-slidev--start-server outfile)
      (message "org-slidev: server starting at %s — check %s for output"
               (org-slidev--dev-url)
               org-slidev-process-buffer-name))))

;;;###autoload
(defun org-slidev-stop-server ()
  "Stop the running Slidev dev server, if any."
  (interactive)
  (if (org-slidev--process-live-p)
      (progn
        (delete-process org-slidev--process)
        (setq org-slidev--process nil)
        (setq org-slidev--preview-file nil)
        (message "org-slidev: server stopped"))
    (message "org-slidev: no server running")))

;;;###autoload
(defun org-slidev-show-server-buffer ()
  "Display the Slidev server output buffer."
  (interactive)
  (let ((buf (get-buffer org-slidev-process-buffer-name)))
    (if buf
        (pop-to-buffer buf)
      (message "org-slidev: no server buffer found"))))

;;;###autoload
(defun org-slidev-server-status ()
  "Report the current status of the Slidev dev server."
  (interactive)
  (if (org-slidev--process-live-p)
      (message "org-slidev: server running at %s (pid %d)"
               (org-slidev--dev-url)
               (process-id org-slidev--process))
    (message "org-slidev: no server running")))


;;; ============================================================
;;; Auto-export Minor Mode
;;; ============================================================

(defun org-slidev--auto-export-on-save ()
  "Re-export to Slidev Markdown after saving, if in an Org buffer."
  (when (derived-mode-p 'org-mode)
    (org-slidev-export-to-file)))

;;;###autoload
(define-minor-mode org-slidev-auto-export-mode
  "Minor mode to automatically re-export to Slidev Markdown on save.

When enabled, saving the Org buffer triggers `org-slidev-export-to-file'.
If `org-slidev-preview' was used to start the dev server, Slidev's HMR
will pick up the change and reload the presentation automatically."
  :lighter " Slidev"
  :group 'org-slidev
  (if org-slidev-auto-export-mode
      (add-hook 'after-save-hook #'org-slidev--auto-export-on-save nil t)
    (remove-hook 'after-save-hook #'org-slidev--auto-export-on-save t)))


;;; ============================================================
;;; Provide
;;; ============================================================

(provide 'org-slidev)

;;; org-slidev.el ends here
