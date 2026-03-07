;;; ox-slidev.el --- Slidev Markdown exporter for Org-mode -*- lexical-binding: t; -*-

;; Author: ox-slidev contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (org "9.5"))
;; Keywords: org, export, slidev, presentation
;; URL: https://github.com/LuciusChen/ox-slidev

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
(require 'json)

(defvar ox-slidev--slide-metadata-cache (make-hash-table :test 'eq)
  "Cache of precomputed slide metadata keyed by Org parse tree.")


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

(defcustom ox-slidev-document-frontmatter-functions nil
  "Functions to post-process document frontmatter.
Each function is called with (FM INFO) and should return a new FM alist."
  :type 'hook
  :group 'ox-slidev)

(defcustom ox-slidev-slide-frontmatter-functions nil
  "Functions to post-process per-slide frontmatter.
Each function is called with (FM HEADLINE INFO) and should
return a new FM alist."
  :type 'hook
  :group 'ox-slidev)

(defcustom ox-slidev-slide-body-functions nil
  "Functions to post-process rendered slide body text.
Each function is called with (BODY HEADLINE INFO) and should
return a new BODY string."
  :type 'hook
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
    (table         . ox-slidev--table)
    (special-block . ox-slidev--special-block)
    (export-block  . ox-slidev--export-block)
    (src-block     . ox-slidev--src-block)
    (footnote-reference . ox-slidev--footnote-reference)
    (footnote-definition . ox-slidev--footnote-definition)
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
  (let ((fm '()))
    (dolist (pair '(("SLIDEV_LAYOUT" . "layout")
                    ("SLIDEV_CLASS" . "class")
                    ("SLIDEV_BACKGROUND" . "background")
                    ("SLIDEV_TRANSITION" . "transition")
                    ("SLIDEV_HIDE" . "hide")))
      (when-let* ((val (org-element-property (intern (concat ":" (car pair)))
                                             headline)))
        (push (cons (cdr pair) (string-trim val)) fm)))
    (org-with-point-at (org-element-property :begin headline)
      (save-excursion
        (forward-line 1)
        (when (looking-at-p "[ \t]*:PROPERTIES:[ \t]*$")
          (forward-line 1)
          (while (and (not (eobp))
                      (not (looking-at-p "[ \t]*:END:[ \t]*$")))
            (when (looking-at "[ \t]*:\\(SLIDEV_FM_[^:]+\\):[ \t]*\\(.*\\)$")
              (let ((fm-key (substring (match-string 1) (length "SLIDEV_FM_")))
                    (val (string-trim (match-string 2))))
                (unless (string-empty-p val)
                  (push (cons fm-key val) fm))))
            (forward-line 1)))))
    (nreverse fm)))

(defun ox-slidev--fm-to-string (fm)
  "Convert frontmatter alist FM to YAML string (without delimiters)."
  (mapconcat
   (lambda (pair)
     (let ((key (car pair))
           (val (ox-slidev--yaml-scalar (cdr pair))))
       (format "%s: %s" key val)))
   fm
   "\n"))

(defun ox-slidev--yaml-indented (text &optional indent)
  "Return TEXT with each line indented by INDENT spaces (default 2)."
  (let ((pad (make-string (or indent 2) ?\s)))
    (mapconcat (lambda (line) (concat pad line))
               (split-string text "\n" nil)
               "\n")))

(defun ox-slidev--yaml-needs-quote-p (s)
  "Return non-nil if string S should be quoted for safe YAML output."
  (or (string-empty-p s)
      (string-prefix-p " " s)
      (string-suffix-p " " s)
      (string-match-p "[:#]" s)
      (string-match-p "^[!&*%@`>|?-]" s)
      (string-match-p (rx (any ?{ ?} ?\[ ?\] ?,)) s)))

(defun ox-slidev--yaml-literal-p (s)
  "Return non-nil when S should be emitted as a YAML literal block."
  (string-match-p "\n" s))

(defun ox-slidev--yaml-typed-scalar-p (s)
  "Return non-nil if S should be passed through as a typed YAML scalar."
  (or (string-match-p "\\`\\(?:true\\|false\\|yes\\|no\\|on\\|off\\|null\\|~\\)\\'" s)
      (string-match-p "\\`[-+]?[0-9]+\\(?:\\.[0-9]+\\)?\\'" s)
      (ox-slidev--yaml-json-container-p s)
      (string-match-p "\\`\".*\"\\'" s)
      (string-match-p "\\`'.*'\\'" s)))

(defun ox-slidev--yaml-json-container-p (s)
  "Return non-nil when S is a valid JSON array or object literal."
  (when (and (> (length s) 1)
             (or (and (string-prefix-p "[" s) (string-suffix-p "]" s))
                 (and (string-prefix-p "{" s) (string-suffix-p "}" s))))
    (condition-case nil
        (let ((parsed (json-parse-string s
                                         :object-type 'alist
                                         :array-type 'list
                                         :null-object nil
                                         :false-object :false)))
          (or (listp parsed)
              (vectorp parsed)))
      (error nil))))

(defun ox-slidev--yaml-single-quote (s)
  "Return S quoted as a YAML single-quoted scalar."
  (concat "'" (replace-regexp-in-string "'" "''" s t t) "'"))

(defun ox-slidev--yaml-scalar (value)
  "Convert VALUE to a YAML-safe scalar representation."
  (let ((s (string-trim (format "%s" value))))
    (cond
     ((ox-slidev--yaml-literal-p s)
      (concat "|-\n" (ox-slidev--yaml-indented s 2)))
     ((ox-slidev--yaml-typed-scalar-p s)
      s)
     ((ox-slidev--yaml-needs-quote-p s)
      (ox-slidev--yaml-single-quote s))
     (t s))))

(defun ox-slidev--trim-leading-newlines (s)
  "Trim only leading newlines in S, preserving internal formatting."
  (replace-regexp-in-string "\\`[\n\r]+" "" (or s "")))

(defun ox-slidev--trim-trailing-newlines (s)
  "Trim only trailing newlines in S, preserving internal formatting."
  (replace-regexp-in-string "[\n\r]+\\'" "" (or s "")))

(defun ox-slidev--apply-functions (value functions &rest args)
  "Run FUNCTIONS as a pipeline over VALUE with ARGS."
  (let ((current value))
    (dolist (fn functions)
      (setq current (apply fn current args)))
    current))

(defun ox-slidev--params-to-html-attrs (params)
  "Convert block PARAMS into HTML attrs string.
Tokens like \"foo=bar\" become `foo=\"bar\"`. Bare tokens become boolean attrs."
  (if (or (null params) (string-empty-p (string-trim params)))
      ""
    (ox-slidev--tokens-to-html-attrs
     (split-string-shell-command params))))

(defun ox-slidev--tokens-to-html-attrs (tokens)
  "Convert TOKENS into an HTML attrs string."
  (if (null tokens)
      ""
    (concat
     " "
     (mapconcat
      (lambda (token)
        (if (string-match "\\`\\([^=[:space:]]+\\)=\\(.*\\)\\'" token)
            (format "%s=\"%s\""
                    (match-string 1 token)
                    (ox-slidev--normalize-attr-value (match-string 2 token)))
          token))
      tokens
      " "))))

(defun ox-slidev--normalize-attr-value (value)
  "Normalize attribute VALUE for HTML output."
  (let ((normalized (replace-regexp-in-string "\\\\\"" "\"" value)))
    (setq normalized (replace-regexp-in-string "\\\\'" "'" normalized))
    (replace-regexp-in-string
     "\\`[\"']+\\|[\"']+\\'"
     ""
     normalized)))

(defun ox-slidev--component-block (name params body)
  "Render Slidev/Vue component NAME with PARAMS and BODY."
  (let* ((attrs (ox-slidev--params-to-html-attrs params))
         (trimmed-body (string-trim body)))
    (if (string-empty-p trimmed-body)
        (format "\n<%s%s />\n" name attrs)
      (format "\n<%s%s>\n\n%s\n</%s>\n" name attrs body name))))

(defun ox-slidev--component-alias-block (type params body)
  "Render special block TYPE as a known Slidev component alias."
  (pcase type
    ("toc" (ox-slidev--component-block "Toc" params ""))
    ("arrow" (ox-slidev--component-block "Arrow" params ""))
    ("tweet" (ox-slidev--component-block "Tweet" params ""))
    ("youtube" (ox-slidev--component-block "Youtube" params ""))
    ("powered_by_slidev" (ox-slidev--component-block "PoweredBySlidev" params ""))
    ("poweredbyslidev" (ox-slidev--component-block "PoweredBySlidev" params ""))
    ("link" (ox-slidev--component-block "Link" params body))
    ("transform" (ox-slidev--component-block "Transform" params body))
    ((or "light_or_dark" "lightordark")
     (ox-slidev--component-block "LightOrDark" params body))
    ("light" (ox-slidev--component-block "template" "#light" body))
    ("dark" (ox-slidev--component-block "template" "#dark" body))
    (_ body)))

(defconst ox-slidev--deprecated-layout-wrapper-types
  '("two_cols" "two-cols"
    "two_cols_header" "two-cols-header"
    "cover" "slide_center" "slide-center"
    "slide_quote" "slide-quote"
    "fact" "statement"
    "image_left" "image-left"
    "image_right" "image-right")
  "Special block names that used to infer slide layouts and are now rejected.")

(defun ox-slidev--inline-component (name attrs &optional body)
  "Render inline Slidev/Vue component NAME with ATTRS and optional BODY."
  (let ((trimmed-body (and body (string-trim body))))
    (if (or (null trimmed-body) (string-empty-p trimmed-body))
        (format "<%s%s />" name attrs)
      (format "<%s%s>%s</%s>" name attrs body name))))

(defun ox-slidev--table-cell-text (cell info)
  "Return markdown-friendly text for table CELL in INFO."
  (let ((text (string-trim (org-export-data (org-element-contents cell) info))))
    (replace-regexp-in-string
     "|"
     "\\\\|"
     (replace-regexp-in-string "[\n\r]+" "<br>" text))))

(defun ox-slidev--table-row-cells (row info)
  "Return rendered cell strings for table ROW in INFO."
  (mapcar (lambda (cell) (ox-slidev--table-cell-text cell info))
          (org-element-map row 'table-cell #'identity info)))

(defun ox-slidev--table-align-marker (row info)
  "Return markdown alignment markers for ROW in INFO."
  (mapcar
   (lambda (cell)
     (pcase (org-export-table-cell-alignment cell info)
       (`left ":---")
       (`right "---:")
       (`center ":---:")
       (_ "---")))
   (org-element-map row 'table-cell #'identity info)))

(defun ox-slidev--table-simple-p (table _info)
  "Return non-nil if TABLE can be rendered as a markdown table."
  (let ((rule-count 0)
        (header-rows 0)
        (standard-rows 0))
    (and (eq (org-element-property :type table) 'org)
         (not (org-export-table-has-special-column-p table))
         (progn
           (dolist (row (org-element-contents table))
             (pcase (org-element-type row)
               (`table-row
                (pcase (org-element-property :type row)
                  (`rule (cl-incf rule-count))
                  (`standard
                   (cl-incf standard-rows)
                   (when (zerop rule-count)
                     (cl-incf header-rows)))))))
           (and (> standard-rows 0)
                (<= rule-count 1)
                (or (zerop rule-count)
                    (<= header-rows 1)))))))

(defun ox-slidev--table (table _contents info)
  "Translate TABLE to markdown when possible, otherwise HTML fallback."
  (if (not (ox-slidev--table-simple-p table info))
      (org-md--convert-to-html table nil info)
    (let ((rows nil)
          (rule-seen nil)
          (saw-header nil))
      (dolist (row (org-element-contents table))
        (when (eq (org-element-type row) 'table-row)
          (pcase (org-element-property :type row)
            (`rule
             (setq rule-seen t))
            (`standard
             (push (cons (if (or rule-seen saw-header) 'body 'head)
                         (ox-slidev--table-row-cells row info))
                   rows)
             (setq saw-header t)))))
      (setq rows (nreverse rows))
      (let* ((header-row (or (assoc 'head rows) (car rows)))
             (header (or (cdr header-row) '("")))
             (body-rows (mapcar #'cdr
                                (cl-remove-if-not
                                 (lambda (row) (eq (car row) 'body))
                                 rows)))
             (first-standard-row
              (org-element-map table 'table-row
                (lambda (row)
                  (when (eq (org-element-property :type row) 'standard)
                    row))
                info t))
             (divider (ox-slidev--table-align-marker first-standard-row info))
             (body-text
              (mapconcat
               (lambda (row)
                 (concat "| " (mapconcat #'identity row " | ") " |"))
               body-rows
               "\n")))
        (concat
         "| " (mapconcat #'identity header " | ") " |\n"
         "| " (mapconcat #'identity divider " | ") " |\n"
         body-text
         (when body-rows "\n"))))))


(defun ox-slidev--generic-component-block (params body)
  "Render generic Slidev component block from PARAMS and BODY."
  (let* ((tokens (if (and params (not (string-empty-p (string-trim params))))
                     (split-string-shell-command params)
                   nil))
         (name (car tokens))
         (attrs (ox-slidev--tokens-to-html-attrs (cdr tokens)))
         (trimmed-body (string-trim body)))
    (if (or (null name) (string-empty-p name))
        body
      (if (string-empty-p trimmed-body)
          (format "\n<%s%s />\n" name attrs)
        (format "\n<%s%s>\n\n%s\n</%s>\n" name attrs body name)))))

(defun ox-slidev--vdrag-block (params body)
  "Render a draggable Slidev block from PARAMS and BODY."
  (let* ((tokens (if (and params (not (string-empty-p (string-trim params))))
                     (split-string-shell-command params)
                   nil))
         (drag-value nil)
         (rest tokens))
    (when rest
      (cond
       ((string-match "\\`v?-?drag=\\(.*\\)\\'" (car rest))
        (setq drag-value (match-string 1 (car rest)))
        (setq rest (cdr rest)))
       ((not (string-match-p "\\`[^=[:space:]]+=.*\\'" (car rest)))
        (setq drag-value (car rest))
        (setq rest (cdr rest)))))
    (concat
     "\n<div"
     (if drag-value
         (format " v-drag=\"%s\"" drag-value)
       " v-drag")
     (ox-slidev--tokens-to-html-attrs rest)
     ">\n\n"
     body
     "\n</div>\n")))

(defun ox-slidev--footnote-id (footnote info)
  "Return stable markdown footnote id for FOOTNOTE in INFO."
  (or (org-element-property :label footnote)
      (number-to-string (org-export-get-footnote-number footnote info))))

(defun ox-slidev--slide-metadata (info)
  "Return cached slide metadata for INFO."
  (let* ((tree (plist-get info :parse-tree))
         (cached (gethash tree ox-slidev--slide-metadata-cache 'missing)))
    (if (not (eq cached 'missing))
        cached
      (let ((begins nil)
            (slide-level (ox-slidev--slide-level info)))
        (org-element-map tree 'headline
          (lambda (node)
            (when (= (org-element-property :level node) slide-level)
              (push (org-element-property :begin node) begins))))
        (let* ((ordered-begins (nreverse begins))
               (metadata (list :begins ordered-begins
                               :first-begin (car ordered-begins)
                               :has-slides (not (null ordered-begins)))))
          (puthash tree metadata ox-slidev--slide-metadata-cache)
          metadata)))))

(defun ox-slidev--parse-inline-component-spec (path)
  "Parse inline Slidev component PATH into a plist."
  (let* ((parts (split-string path "::"))
         (name (car parts))
         (raw-attrs (cadr parts))
         (tokens (and raw-attrs
                      (not (string-empty-p raw-attrs))
                      (split-string raw-attrs "|" t))))
    (list :name name
          :attrs (ox-slidev--tokens-to-html-attrs tokens))))

(defun ox-slidev--export-slidev-link (path desc backend _info)
  "Export custom slidev: link PATH with DESC for BACKEND."
  (if (org-export-derived-backend-p backend 'slidev)
      (let* ((spec (ox-slidev--parse-inline-component-spec path))
             (name (plist-get spec :name))
             (attrs (plist-get spec :attrs)))
        (ox-slidev--inline-component name attrs desc))
    (or desc path)))

(defmacro ox-slidev--with-export-context (&rest body)
  "Run BODY with temporary Slidev export-only Org link registration."
  (declare (indent 0) (debug t))
  `(let ((org-link-parameters (copy-tree org-link-parameters)))
     (org-link-set-parameters "slidev" :export #'ox-slidev--export-slidev-link)
     ,@body))

(defun ox-slidev--indent-lines (text prefix)
  "Prefix every line in TEXT with PREFIX."
  (mapconcat (lambda (line) (concat prefix line))
             (split-string text "\n" nil)
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
          (setq result (append result (list pair))))))
    result))

(defun ox-slidev--document-fm (info)
  "Return merged document frontmatter from INFO."
  (let* ((tree (plist-get info :parse-tree))
         (doc-fm (ox-slidev--collect-doc-fm info))
         (generic-fm (ox-slidev--collect-generic-fm tree)))
    (ox-slidev--apply-functions
     (ox-slidev--merge-fm doc-fm generic-fm)
     ox-slidev-document-frontmatter-functions
     info)))

(defun ox-slidev--first-slide-p (headline info)
  "Return non-nil when HEADLINE is the first slide headline in INFO."
  (let ((headline-begin (org-element-property :begin headline)))
    (eq headline-begin
        (plist-get (ox-slidev--slide-metadata info) :first-begin))))


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
  (let ((doc-fm (ox-slidev--document-fm info))
        (clean-contents (ox-slidev--trim-leading-newlines contents)))
    (if (plist-get (ox-slidev--slide-metadata info) :has-slides)
        clean-contents
      (concat (ox-slidev--fm-block doc-fm) clean-contents))))


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
             (effective-fm (ox-slidev--apply-functions
                            (if is-first
                                (ox-slidev--merge-fm doc-fm slide-fm)
                              slide-fm)
                            ox-slidev-slide-frontmatter-functions
                            headline
                            info))
             (fm-block (ox-slidev--fm-block effective-fm))
             (heading (if (string-empty-p title)
                          ""
                        (concat "# " title "\n\n")))
             (body (ox-slidev--apply-functions
                    (ox-slidev--trim-trailing-newlines
                     (ox-slidev--trim-leading-newlines contents))
                    ox-slidev-slide-body-functions
                    headline
                    info)))
        (concat
         (if is-first
             ;; First slide: emit merged frontmatter
           (concat fm-block "\n")
           ;; Subsequent slides: emit separator + optional fm
           (if (null slide-fm)
               "---\n\n"
             ;; For later slides with frontmatter, the opening --- is both the
             ;; slide separator and the frontmatter start.
             (concat (ox-slidev--trim-trailing-newlines fm-block) "\n\n")))
         heading
         body)))

     ;; Level > slide-level: sub-heading within a slide.
     (t
      (let* ((depth (- level slide-level))
             (hashes (make-string (1+ depth) ?#))
             (heading (concat hashes " " title "\n\n"))
             (body (ox-slidev--trim-leading-newlines contents)))
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

     ((member type ox-slidev--deprecated-layout-wrapper-types)
      (user-error
       "Layout wrapper block `%s' is no longer supported; use headline properties like :SLIDEV_LAYOUT: and slot blocks instead"
       type))

     ;; Fragment block → v-click wrapper
     ((string= type "fragment")
      (let* ((params (org-element-property :parameters block))
             (attrs (ox-slidev--fragment-attrs params)))
        (concat "\n<div " attrs ">\n\n" body "\n</div>\n")))

     ;; Clicks block → v-clicks component
     ((string= type "clicks")
      (let ((attrs (ox-slidev--params-to-html-attrs
                    (org-element-property :parameters block))))
        (concat "\n<v-clicks" attrs ">\n\n" body "\n</v-clicks>\n")))

     ;; Common Slidev component aliases
     ((member type '("toc" "arrow" "tweet" "youtube" "link"
                     "powered_by_slidev" "poweredbyslidev"
                     "transform" "light_or_dark" "lightordark"
                     "light" "dark"))
      (ox-slidev--component-alias-block
       type
       (org-element-property :parameters block)
       body))
     ((string= type "component")
      (ox-slidev--generic-component-block
       (org-element-property :parameters block)
       body))
     ((string= type "vdrag")
      (ox-slidev--vdrag-block
       (org-element-property :parameters block)
       body))

     ;; Unknown special blocks: pass through as-is
     (t body))))

(defun ox-slidev--fragment-attrs (params)
  "Build Vue attrs for fragment block PARAMS."
  (let* ((tokens (if params
                     (split-string-and-unquote params)
                   nil))
         (index nil)
         (directive "v-click")
         (once nil))
    (dolist (token tokens)
      (cond
       ((string-prefix-p "at=" token)
        (setq index (substring token 3)))
       ((string-match-p "\\`[0-9]+\\'" token)
        (setq index token))
       ((string= token "once")
        (setq once t))
       ((string= token "after")
        (setq directive "v-after"))
       ((string= token "hide")
        (setq directive "v-click-hide"))
       ((string= token "show")
        (setq directive "v-click"))))
    (when (and once (string= directive "v-click"))
      (setq directive "v-click.once"))
    (concat directive
            (if index (format "=\"%s\"" index) ""))))


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

(defun ox-slidev--footnote-reference (footnote-reference _contents info)
  "Translate FOOTNOTE-REFERENCE to markdown footnote syntax."
  (format "[^%s]" (ox-slidev--footnote-id footnote-reference info)))

(defun ox-slidev--footnote-definition (footnote-definition contents info)
  "Translate FOOTNOTE-DEFINITION to markdown footnote syntax."
  (let* ((id (ox-slidev--footnote-id footnote-definition info))
         (body (string-trim-right
                (ox-slidev--trim-leading-newlines contents)))
         (lines (split-string body "\n" nil)))
    (if (string-empty-p body)
        ""
      (concat
       "\n[^" id "]: " (car lines)
       (if (cdr lines)
           (concat "\n" (ox-slidev--indent-lines (mapconcat #'identity (cdr lines) "\n") "  "))
         "")
       "\n"))))


;;; ============================================================
;;; Link / Image Translator
;;; ============================================================

(defun ox-slidev--link (link desc info)
  "Translate LINK element, with special handling for image links.
If the link has #+ATTR_SLIDEV: :width, emit <img> instead of ![](...)."
  (let* ((type (org-element-property :type link))
         (path (org-element-property :path link))
         (parent (org-element-property :parent link))
         (attr-slidev (org-export-read-attribute :attr_slidev parent))
         (width (plist-get attr-slidev :width)))
    (cond
     ((string= type "slidev")
      (let* ((spec (ox-slidev--parse-inline-component-spec path))
             (name (plist-get spec :name))
             (attrs (plist-get spec :attrs)))
        (ox-slidev--inline-component name attrs desc)))
     ((and (member type '("file" "fuzzy"))
           (ox-slidev--image-p path))
      ;; Image link
      (let ((src (if (string= type "file") path (concat "./" path))))
        (if width
            ;; Has :width → emit HTML img for precise sizing
            (format "<img src=\"%s\" width=\"%s\" />" src width)
          ;; No attributes → plain markdown image
          (format "![%s](%s)" (or desc "") src))))
     (t
      ;; Non-image link: fall back to ox-md behavior
      (org-md-link link desc info)))))

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
Optional arguments ASYNC, SUBTREEP, and VISIBLE-ONLY are as in
`org-export-to-buffer'."
  (interactive)
  (ox-slidev--with-export-context
    (org-export-to-buffer 'slidev "*Org Slidev Export*"
      async subtreep visible-only nil nil
      (lambda () (text-mode)))))

;;;###autoload
(defun ox-slidev-export-to-file (&optional async subtreep visible-only)
  "Export current Org buffer to a Slidev Markdown file.
The output file will have the same base name with .md extension.
Optional arguments ASYNC, SUBTREEP, VISIBLE-ONLY are as in `org-export-to-file'."
  (interactive)
  (let ((outfile (concat (file-name-sans-extension (buffer-file-name)) ".md")))
    (ox-slidev--with-export-context
      (org-export-to-file 'slidev outfile async subtreep visible-only))))


;;; ============================================================
;;; Provide
;;; ============================================================

(provide 'ox-slidev)

;;; ox-slidev.el ends here
