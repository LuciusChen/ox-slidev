;;; ox-slidev.el --- Slidev Markdown exporter for Org-mode -*- lexical-binding: t; -*-

;; Author: ox-slidev contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (org "9.5"))
;; Keywords: org, export, slidev, presentation
;; URL: https://github.com/your-repo/ox-slidev

;;; Commentary:

;; ox-slidev exports Org-mode files to Slidev Markdown format.
;;
;; Usage:
;;   M-x org-slidev-export-to-file
;;   M-x org-slidev-export-to-buffer
;;
;; See README for full documentation.

;;; Code:

(require 'ox)
(require 'ox-md)
(require 'cl-lib)
(require 'subr-x)


;;; ============================================================
;;; Custom Variables
;;; ============================================================

(defgroup ox-slidev nil
  "Options for exporting Org files to Slidev Markdown."
  :tag "Org Slidev"
  :group 'org-export)

(defcustom org-slidev-slide-level 1
  "Default headline level that triggers a new slide.
Can be overridden per file with #+SLIDE_LEVEL:."
  :type 'integer
  :group 'ox-slidev)

(defcustom org-slidev-code-theme nil
  "Default Shiki code theme. nil means use Slidev default."
  :type '(choice (const nil) string)
  :group 'ox-slidev)


;;; ============================================================
;;; Backend Registration
;;; ============================================================

(org-export-define-derived-backend 'slidev 'md
  :options-alist
  '((:slide-level      "SLIDE_LEVEL"      nil nil     t)
    (:slidev-theme     "SLIDEV_THEME"     nil nil     t)
    (:slidev-layout    "SLIDEV_LAYOUT"    nil nil     t)
    (:slidev-class     "SLIDEV_CLASS"     nil nil     t)
    (:slidev-background "SLIDEV_BACKGROUND" nil nil   t)
    (:slidev-aspect    "SLIDEV_ASPECT"    nil nil     t)
    (:slidev-transition "SLIDEV_TRANSITION" nil nil   t))
  :translate-alist
  '((template      . ox-slidev--template)
    (inner-template . ox-slidev--inner-template)
    (headline      . ox-slidev--headline)
    (special-block . ox-slidev--special-block)
    (export-block  . ox-slidev--export-block)
    (src-block     . ox-slidev--src-block)
    (link          . ox-slidev--link)
    (keyword       . ox-slidev--keyword))
  :menu-entry
  '(?S "Export to Slidev"
       ((?f "To file"   ox-slidev-export-to-file)
        (?b "To buffer" ox-slidev-export-to-buffer))))


;;; ============================================================
;;; Utilities
;;; ============================================================

(defun ox-slidev--slide-level (info)
  "Return effective slide level from INFO plist."
  (let ((file-level (plist-get info :slide-level)))
    (if (and file-level (not (string-empty-p (string-trim file-level))))
        (string-to-number (string-trim file-level))
      org-slidev-slide-level)))

(defun ox-slidev--collect-doc-fm (info)
  "Collect document-level frontmatter from INFO plist.
Returns an alist of (key . value) pairs."
  (let ((fm '()))
    ;; Standard Org keywords
    (when-let* ((v (plist-get info :title)))
      (push (cons "title" (org-export-data v info)) fm))
    (when-let* ((v (plist-get info :author)))
      (let ((str (org-export-data v info)))
        (unless (string-empty-p str)
          (push (cons "author" str) fm))))
    (when-let* ((v (plist-get info :date)))
      (let ((str (org-export-data v info)))
        (unless (string-empty-p str)
          (push (cons "date" str) fm))))
    ;; Slidev-specific keywords
    (dolist (pair '((:slidev-theme     . "theme")
                    (:slidev-layout    . "layout")
                    (:slidev-class     . "class")
                    (:slidev-background . "background")
                    (:slidev-aspect    . "aspectRatio")
                    (:slidev-transition . "transition")))
      (when-let* ((v (plist-get info (car pair))))
        (unless (string-empty-p (string-trim v))
          (push (cons (cdr pair) (string-trim v)) fm))))
    ;; Generic #+SLIDEV_FM_* keywords
    ;; These are collected from the parse tree keywords
    (nreverse fm)))

(defun ox-slidev--collect-generic-fm (tree)
  "Scan TREE for #+SLIDEV_FM_* keywords and return alist."
  (let ((fm '()))
    (org-element-map tree 'keyword
      (lambda (kw)
        (let ((key (org-element-property :key kw))
              (val (org-element-property :value kw)))
          (when (string-prefix-p "SLIDEV_FM_" key)
            (let ((fm-key (substring key (length "SLIDEV_FM_"))))
              (push (cons fm-key (string-trim val)) fm))))))
    (nreverse fm)))

(defun ox-slidev--headline-fm (headline)
  "Extract slide-level frontmatter from HEADLINE property drawer.
Returns an alist."
  (let ((fm '())
        (section (org-element-map (org-element-contents headline) 'section
                   #'identity nil t)))
    (dolist (pair '(("SLIDEV_LAYOUT" . "layout")
                    ("SLIDEV_CLASS" . "class")
                    ("SLIDEV_BACKGROUND" . "background")
                    ("SLIDEV_TRANSITION" . "transition")
                    ("SLIDEV_HIDE" . "hide")))
      (when-let* ((val (org-element-property (intern (concat ":" (car pair)))
                                             headline)))
        (push (cons (cdr pair) (string-trim val)) fm)))
    (when section
      (dolist (child (org-element-contents section))
        (when (eq (org-element-type child) 'property-drawer)
          (dolist (prop (org-element-contents child))
            (let ((key (org-element-property :key prop))
                  (val (org-element-property :value prop)))
              (when (string-prefix-p "SLIDEV_FM_" key)
                (let ((fm-key (substring key (length "SLIDEV_FM_"))))
                  (push (cons fm-key (string-trim val)) fm))))))))
    (nreverse fm)))

(defun ox-slidev--fm-to-string (fm)
  "Convert frontmatter alist FM to YAML string (without delimiters)."
  (mapconcat
   (lambda (pair)
     (let ((key (car pair))
           (val (cdr pair)))
       (format "%s: %s" key val)))
   fm
   "\n"))

(defun ox-slidev--fm-block (fm)
  "Wrap FM alist as a complete frontmatter block string.
Returns empty string if FM is empty."
  (if (null fm)
      ""
    (concat "---\n" (ox-slidev--fm-to-string fm) "\n---\n")))

(defun ox-slidev--merge-fm (base override)
  "Merge two frontmatter alists. OVERRIDE takes precedence."
  (let ((result (copy-alist base)))
    (dolist (pair override)
      (let ((existing (assoc (car pair) result)))
        (if existing
            (setcdr existing (cdr pair))
          (push pair result))))
    result))

(defun ox-slidev--document-fm (info)
  "Return merged document frontmatter from INFO."
  (let* ((tree (plist-get info :parse-tree))
         (doc-fm (ox-slidev--collect-doc-fm info))
         (generic-fm (ox-slidev--collect-generic-fm tree)))
    (ox-slidev--merge-fm doc-fm generic-fm)))

(defun ox-slidev--first-slide-p (headline info)
  "Return non-nil when HEADLINE is the first slide headline in INFO."
  (let ((slide-level (ox-slidev--slide-level info))
        (headline-begin (org-element-property :begin headline))
        first-slide-begin)
    (org-element-map (plist-get info :parse-tree) 'headline
      (lambda (node)
        (when (and (null first-slide-begin)
                   (= (org-element-property :level node) slide-level))
          (setq first-slide-begin (org-element-property :begin node))
          t))
      info t)
    (and first-slide-begin
         (= headline-begin first-slide-begin))))


;;; ============================================================
;;; Template
;;; ============================================================

(defun ox-slidev--template (contents _info)
  "Wrap CONTENTS with document frontmatter."
  ;; The inner-template handles slide separators.
  ;; template wraps the whole thing — but frontmatter is already
  ;; prepended in inner-template for the first slide merge case.
  ;; So here we just return contents as-is.
  contents)

(defun ox-slidev--inner-template (contents info)
  "Build the full Slidev document from CONTENTS and INFO."
  (let ((doc-fm (ox-slidev--document-fm info)))
    (if (org-element-map (plist-get info :parse-tree) 'headline
          (lambda (node)
            (= (org-element-property :level node)
               (ox-slidev--slide-level info)))
          info t)
        contents
      (concat (ox-slidev--fm-block doc-fm) contents))))


;;; ============================================================
;;; Headline Translator
;;; ============================================================

(defun ox-slidev--headline (headline contents info)
  "Translate HEADLINE to Slidev markdown."
  (let* ((level (org-element-property :level headline))
         (slide-level (ox-slidev--slide-level info))
         (title (org-export-data (org-element-property :title headline) info))
         (doc-fm (ox-slidev--document-fm info))
         (slide-fm (ox-slidev--headline-fm headline)))
    (cond
     ;; Level above slide-level: section container, no slide boundary.
     ;; Just emit contents (sub-headlines will handle their own slides).
     ((< level slide-level)
      (or contents ""))

     ;; Level == slide-level: new slide boundary.
     ((= level slide-level)
      (let* ((is-first (ox-slidev--first-slide-p headline info))
             (effective-fm (if is-first
                               (ox-slidev--merge-fm doc-fm slide-fm)
                             slide-fm))
             (fm-block (ox-slidev--fm-block effective-fm))
             (heading (if (string-empty-p title)
                          ""
                        (concat "# " title "\n\n")))
             (body (or contents "")))
        (concat
         (if is-first
             ;; First slide: emit merged frontmatter
             (concat fm-block "\n")
           ;; Subsequent slides: emit separator + optional fm
           (concat "\n---\n"
                   (if (null slide-fm) "\n"
                     (concat "\n" fm-block "\n"))))
         heading
         body)))

     ;; Level > slide-level: sub-heading within a slide.
     (t
      (let* ((depth (- level slide-level))
             (hashes (make-string (1+ depth) ?#))
             (heading (concat hashes " " title "\n\n"))
             (body (or contents "")))
        (concat heading body))))))


;;; ============================================================
;;; Keyword Translator (#+SLIDE: new)
;;; ============================================================

(defun ox-slidev--keyword (keyword _contents _info)
  "Handle #+SLIDE: new keywords for manual page breaks."
  (let ((key (org-element-property :key keyword))
        (val (org-element-property :value keyword)))
    (cond
     ;; #+SLIDE: new → insert slide separator
     ((and (string= key "SLIDE")
           (string= (string-trim val) "new"))
      "\n---\n\n")
     ;; #+SLIDE_LEVEL and #+SLIDEV_* keywords: consumed by options, emit nothing
     ((or (string= key "SLIDE_LEVEL")
          (string-prefix-p "SLIDEV_" key))
      "")
     ;; Other keywords: fall through to default md behavior
     (t ""))))


;;; ============================================================
;;; Special Block Translator
;;; ============================================================

(defun ox-slidev--special-block (block contents _info)
  "Translate special BLOCKs: notes, slot, left, right, top, bottom."
  (let* ((type (downcase (org-element-property :type block)))
         (body (or contents "")))
    (cond
     ;; Speaker notes → HTML comment
     ((or (string= type "notes"))
      (concat "\n<!--\n" (string-trim body) "\n-->\n"))

     ;; Named slot: #+begin_slot <name>
     ((string= type "slot")
      (let* ((params (org-element-property :parameters block))
             (slot-name (if (and params (not (string-empty-p (string-trim params))))
                            (string-trim params)
                          "default")))
        (concat "\n::" slot-name "::\n\n" body "\n")))

     ;; Alias slots: left, right, top, bottom
     ((member type '("left" "right" "top" "bottom"))
      (concat "\n::" type "::\n\n" body "\n"))

     ;; Fragment block → v-click wrapper
     ((string= type "fragment")
      (concat "\n<div v-click>\n\n" body "\n</div>\n"))

     ;; Unknown special blocks: pass through as-is
     (t body))))


;;; ============================================================
;;; Export Block Translator (passthrough)
;;; ============================================================

(defun ox-slidev--export-block (block _contents _info)
  "Pass through #+begin_export md/slidev blocks unchanged."
  (let ((backend (downcase (org-element-property :type block)))
        (value (org-element-property :value block)))
    (when (member backend '("md" "slidev" "markdown"))
      (or value ""))))


;;; ============================================================
;;; Source Block Translator
;;; ============================================================

(defun ox-slidev--src-block (src-block _contents _info)
  "Translate SRC-BLOCK to fenced code block, with optional Slidev attrs."
  (let* ((lang (or (org-element-property :language src-block) ""))
         (value (org-element-property :value src-block))
         (attr-slidev (org-export-read-attribute :attr_slidev src-block))
         (code-opts (plist-get attr-slidev :code)))
    (concat
     "```" lang
     (if code-opts (concat " " code-opts) "")
     "\n"
     value
     "```\n")))


;;; ============================================================
;;; Link / Image Translator
;;; ============================================================

;; TECHNICAL DEBT:
;; First-slide detection currently rescans the parse tree for each slide
;; headline. That keeps the exporter stateless and correct for the MVP, but it
;; is not the most efficient approach for large decks. A future refactor can
;; precompute slide metadata once per export and thread it through translators.

(defun ox-slidev--link (link desc info)
  "Translate LINK element, with special handling for image links.
If the link has #+ATTR_SLIDEV: :width, emit <img> instead of ![](...)."
  (let* ((type (org-element-property :type link))
         (path (org-element-property :path link))
         (parent (org-element-property :parent link))
         (attr-slidev (org-export-read-attribute :attr_slidev parent))
         (width (plist-get attr-slidev :width)))
    (if (and (member type '("file" "fuzzy"))
             (ox-slidev--image-p path))
        ;; Image link
        (let ((src (if (string= type "file") path (concat "./" path))))
          (if width
              ;; Has :width → emit HTML img for precise sizing
              (format "<img src=\"%s\" width=\"%s\" />" src width)
            ;; No attributes → plain markdown image
            (format "![%s](%s)" (or desc "") src)))
      ;; Non-image link: fall back to ox-md behavior
      (org-md-link link desc info))))

(defun ox-slidev--image-p (path)
  "Return non-nil if PATH looks like an image file."
  (let ((ext (downcase (or (file-name-extension path) ""))))
    (member ext '("png" "jpg" "jpeg" "gif" "webp" "svg" "avif"))))


;;; ============================================================
;;; Export Commands
;;; ============================================================

;;;###autoload
(defun ox-slidev-export-to-buffer (&optional async subtreep visible-only)
  "Export current Org buffer to a Slidev Markdown buffer.
Optional arguments ASYNC, SUBTREEP, VISIBLE-ONLY are as in `org-export-to-buffer'."
  (interactive)
  (org-export-to-buffer 'slidev "*Org Slidev Export*"
    async subtreep visible-only nil nil
    (lambda () (text-mode))))

;;;###autoload
(defun ox-slidev-export-to-file (&optional async subtreep visible-only)
  "Export current Org buffer to a Slidev Markdown file.
The output file will have the same base name with .md extension.
Optional arguments ASYNC, SUBTREEP, VISIBLE-ONLY are as in `org-export-to-file'."
  (interactive)
  (let ((outfile (concat (file-name-sans-extension (buffer-file-name)) ".md")))
    (org-export-to-file 'slidev outfile async subtreep visible-only)))


;;; ============================================================
;;; Provide
;;; ============================================================

(provide 'ox-slidev)

;;; ox-slidev.el ends here
