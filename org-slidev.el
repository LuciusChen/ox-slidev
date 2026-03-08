;;; org-slidev.el --- User commands for ox-slidev export and preview -*- lexical-binding: t; -*-

;; Author: ox-slidev contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (org "9.5") (ox-slidev "0.1.0"))
;; Keywords: org, export, slidev, presentation
;; URL: https://github.com/LuciusChen/ox-slidev

;;; Commentary:

;; User-facing commands for exporting Org files to Slidev and
;; launching the Slidev dev server for live preview.
;;
;; Typical workflow:
;;
;;   1. Write your presentation in an Org file.
;;   2. M-x org-slidev-preview
;;      → exports to slides.md, starts `slidev`, opens browser.
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
(require 'cl-lib)
(require 'org)


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

(defcustom org-slidev-project-root-files
  '("package.json" "pnpm-lock.yaml" "yarn.lock" "package-lock.json" ".git")
  "Marker files used to detect the Slidev project root."
  :type '(repeat string)
  :group 'org-slidev)

(defcustom org-slidev-project-root-function nil
  "Optional function used to resolve project root for preview.
When non-nil, called with one argument MD-FILE and should return a directory."
  :type '(choice (const nil) function)
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

(defcustom org-slidev-common-layouts
  '("cover"
    "center"
    "quote"
    "fact"
    "statement"
    "two-cols"
    "two-cols-header"
    "image-left"
    "image-right")
  "Common Slidev layout names offered by `org-slidev-set-layout'."
  :type '(repeat string)
  :group 'org-slidev)

(defcustom org-slidev-common-frontmatter-keys
  '("layoutClass" "image" "class" "background" "transition" "hide")
  "Common slide-level frontmatter keys offered by `org-slidev-set-frontmatter'."
  :type '(repeat string)
  :group 'org-slidev)

(defcustom org-slidev-structure-templates
  '(("svnotes" . "notes")
    ("svright" . "right")
    ("svleft" . "left")
    ("svtop" . "top")
    ("svbottom" . "bottom")
    ("svclicks" . "clicks")
    ("svfragment" . "fragment"))
  "Non-conflicting org-tempo templates for common Slidev blocks.
Each element is (KEY . TEMPLATE) and is added by
`org-slidev-install-structure-templates'."
  :type '(alist :key-type string :value-type string)
  :group 'org-slidev)

(defconst org-slidev--templates-dir
  (expand-file-name "templates"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Built-in template directory for `org-slidev'.")

(defcustom org-slidev-template-files
  '(("starter" . "starter.org")
    ("technical-talk" . "technical-talk.org")
    ("project-update" . "project-update.org"))
  "Built-in template names mapped to files under `org-slidev--templates-dir'."
  :type '(alist :key-type string :value-type string)
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

(defun org-slidev--project-root (md-file)
  "Return best project root for MD-FILE."
  (or (and org-slidev-project-root-function
           (funcall org-slidev-project-root-function md-file))
      (cl-loop for marker in org-slidev-project-root-files
               thereis (locate-dominating-file md-file marker))
      (file-name-directory md-file)))

(defun org-slidev--open-browser ()
  "Open the Slidev dev server URL in the default browser."
  (let ((url (org-slidev--dev-url)))
    (message "org-slidev: opening %s" url)
    (browse-url url)))

(defun org-slidev--ready-output-p (output)
  "Return non-nil when OUTPUT looks like Slidev's ready message."
  (or (string-match-p (regexp-quote (org-slidev--dev-url)) output)
      (string-match-p "\\bLocal:\\b" output)))

(defun org-slidev--template-file (name)
  "Return absolute built-in template file path for template NAME."
  (when-let* ((file (cdr (assoc name org-slidev-template-files))))
    (expand-file-name file org-slidev--templates-dir)))

(defun org-slidev--template-names ()
  "Return available built-in template names."
  (mapcar #'car org-slidev-template-files))

(defun org-slidev--starter-template ()
  "Return the built-in starter deck contents."
  (org-slidev--template-content "starter"))

(defun org-slidev--template-content (name)
  "Return built-in template NAME contents."
  (let ((file (org-slidev--template-file name)))
    (unless (and file (file-exists-p file))
      (user-error "Unknown template: %s" name))
    (with-temp-buffer
      (insert-file-contents file)
      (buffer-string))))

(defun org-slidev--current-heading-point ()
  "Return the current heading point or signal a user-facing error."
  (org-slidev--assert-org-buffer)
  (save-excursion
    (condition-case nil
        (progn
          (org-back-to-heading t)
          (point))
      (error
       (user-error "Point is not inside an Org headline")))))

(defun org-slidev--set-slide-property (property value)
  "Set current slide PROPERTY to VALUE.
If VALUE is empty, remove PROPERTY instead."
  (let ((heading-point (org-slidev--current-heading-point)))
    (save-excursion
      (goto-char heading-point)
      (if (string-empty-p value)
          (org-entry-delete (point) property)
        (org-entry-put (point) property value)))))

(defun org-slidev--block-skeleton (kind)
  "Return insertion skeleton for Slidev block KIND."
  (pcase kind
    ("notes" "#+begin_notes\n\n#+end_notes\n")
    ("right" "#+begin_right\n\n#+end_right\n")
    ("left" "#+begin_left\n\n#+end_left\n")
    ("top" "#+begin_top\n\n#+end_top\n")
    ("bottom" "#+begin_bottom\n\n#+end_bottom\n")
    ("clicks" "#+begin_clicks\n- \n#+end_clicks\n")
    ("fragment" "#+begin_fragment\n\n#+end_fragment\n")
    ("export-slidev" "#+begin_export slidev\n\n#+end_export\n")
    (_ nil)))


;;; ============================================================
;;; Export
;;; ============================================================

;;;###autoload
(defun org-slidev-set-layout (layout)
  "Set `SLIDEV_LAYOUT' on the current headline to LAYOUT."
  (interactive
   (list
    (completing-read "Slidev layout: "
                     org-slidev-common-layouts
                     nil
                     t)))
  (org-slidev--set-slide-property "SLIDEV_LAYOUT" layout)
  (message "org-slidev: set layout to %s" layout))

;;;###autoload
(defun org-slidev-set-frontmatter (key value)
  "Set generic slide frontmatter KEY to VALUE on the current headline.
This writes a `SLIDEV_FM_<key>' property in the current headline drawer."
  (interactive
   (list
    (completing-read "Frontmatter key: "
                     org-slidev-common-frontmatter-keys
                     nil
                     nil)
    (read-string "Frontmatter value: ")))
  (let ((property (concat "SLIDEV_FM_" key)))
    (org-slidev--set-slide-property property value)
    (message "org-slidev: set %s to %s" key value)))

;;;###autoload
(defun org-slidev-insert-block (kind)
  "Insert a common Slidev block KIND at point."
  (interactive
   (list
    (completing-read "Block: "
                     '("notes" "right" "left" "top" "bottom"
                       "clicks" "fragment" "component" "export-slidev")
                     nil
                     t)))
  (pcase kind
    ("component"
     (let ((name (read-string "Component name: ")))
       (insert (format "#+begin_component %s\n\n#+end_component\n" name))))
    (_
     (insert (or (org-slidev--block-skeleton kind)
                 (user-error "Unsupported block kind: %s" kind))))))

;;;###autoload
(defun org-slidev-install-structure-templates ()
  "Install non-conflicting Slidev org-tempo templates.
This adds `org-slidev-structure-templates' to `org-structure-template-alist'
without overriding existing keys."
  (interactive)
  (require 'org-tempo)
  (dolist (entry org-slidev-structure-templates)
    (unless (assoc (car entry) org-structure-template-alist)
      (add-to-list 'org-structure-template-alist entry t)))
  (message "org-slidev: installed %d structure templates"
           (length org-slidev-structure-templates)))

;;;###autoload
(defun org-slidev-insert-starter ()
  "Insert the built-in starter deck at point in the current Org buffer."
  (interactive)
  (org-slidev--assert-org-buffer)
  (insert (org-slidev--starter-template)))

;;;###autoload
(defun org-slidev-insert-template (name)
  "Insert built-in template NAME at point in the current Org buffer."
  (interactive
   (list
    (completing-read "Template: "
                     (org-slidev--template-names)
                     nil
                     t
                     nil
                     nil
                     "starter")))
  (org-slidev--assert-org-buffer)
  (insert (org-slidev--template-content name)))

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
         (project-root (org-slidev--project-root md-file))
         (args (org-slidev--build-dev-args md-file project-root))
         (parts (org-slidev--command-parts))
         (cmd  (car parts))
         (cmd-args (append (cdr parts) args))
         (default-directory project-root))
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

(defun org-slidev--build-dev-args (md-file &optional project-root)
  "Build argument list for Slidev preview given MD-FILE and PROJECT-ROOT."
  (let* ((root (or project-root (org-slidev--project-root md-file)))
         (target (if root
                     (file-relative-name md-file root)
                   (file-name-nondirectory md-file))))
    (list target
          "--port" (number-to-string org-slidev-dev-port))))

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
  2. Start Slidev on the exported file
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
