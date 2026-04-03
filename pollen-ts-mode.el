;;; pollen-ts-mode.el --- Major mode for Pollen with tree-sitter support -*- lexical-binding: t; -*-

;; Author: Yuan Fu
;; Keywords: pollen languages tree-sitter
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; This package provides `pollen-ts-mode' which is a major mode for editing
;; Pollen files that uses Tree-sitter to parse the language.
;;
;; Pollen is a publishing system built on Racket.  Its markup syntax uses
;; the lozenge character ◊ (U+25CA) as a command prefix.
;;
;; This mode supports .pm (markup), .pp (preprocessor), and .p (template)
;; file extensions.

;;; Code:

(require 'treesit)
(require 'seq)
(eval-when-compile (require 'rx))
(treesit-declare-unavailable-functions)

(defgroup pollen-ts nil
  "Major mode for editing Pollen code."
  :prefix "pollen-ts-"
  :group 'languages)

(defcustom pollen-ts-indent-offset 2
  "Indentation of Pollen tag body content."
  :type 'integer
  :safe 'integerp
  :group 'pollen-ts)

(defcustom pollen-ts-header-tag-regexp-list
  (list (rx bos "section" eos)
        (rx bos "subsection" eos))
  "List of regexps matching tag names for header levels 1 through 6.
Each element corresponds to one outline level.  The tag body is
fontified with the corresponding `outline-N' face."
  :type '(repeat regexp)
  :group 'pollen-ts)

(defcustom pollen-ts-code-tag-regexp
  (rx bos (or "code" "bcode" "bcode-hl") eos)
  "Regexp matching tag names whose body should be rendered in monospace.
Matched against the text of `tag_name' nodes in the parse tree."
  :type 'regexp
  :group 'pollen-ts)

(defcustom pollen-ts-highlight-code-tag-regexp
  (rx bos "bcode-hl" eos)
  "Regexp matching tag names for syntax-highlighted code blocks.
Tags matching this regexp with a quoted symbol attribute specifying
the language (e.g., ◊bcode-hl[\\='c]{...}) get language injection."
  :type 'regexp
  :group 'pollen-ts)

;;; Syntax table

(defvar pollen-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    ;; The lozenge ◊ is punctuation
    (modify-syntax-entry ?◊ "." table)
    ;; Braces are paired delimiters
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    ;; Double quotes are string delimiters
    (modify-syntax-entry ?\" "\"" table)
    table)
  "Syntax table for `pollen-ts-mode'.")

;;; Indentation

(defvar pollen-ts-mode--indent-rules
  `((pollen
     ((parent-is "source_file") column-0 0)
     ((node-is "}") parent-bol 0)
     ((parent-is "tag_body") parent-bol ,pollen-ts-indent-offset)
     ((parent-is "tag_expression") parent-bol ,pollen-ts-indent-offset)
     ((parent-is "attr_block") parent-bol ,pollen-ts-indent-offset)
     (no-node parent-bol 0)))
  "Tree-sitter indent rules for `pollen-ts-mode'.")

;;; Faces

(defface pollen-ts-mode-code-face
  '((t :inherit fixed-pitch))
  "Face for the body of code tags (◊code, ◊bcode, ◊bcode-hl)."
  :group 'pollen-ts)

;;; Language injection for ◊bcode-hl

(defvar pollen-ts--code-block-language-map
  '(("c++" . cpp)
    ("c#" . c-sharp)
    ("sh" . bash))
  "Alist mapping code block language names to tree-sitter languages.
Keys are strings (as written in the Pollen attr), values are
tree-sitter language symbols.")

(defvar pollen-ts-code-block-source-mode-map
  '((bash . bash-ts-mode)
    (c . c-ts-mode)
    (c-sharp . csharp-ts-mode)
    (cmake . cmake-ts-mode)
    (cpp . c++-ts-mode)
    (css . css-ts-mode)
    (dockerfile . dockerfile-ts-mode)
    (elixir . elixir-ts-mode)
    (go . go-ts-mode)
    (html . html-ts-mode)
    (java . java-ts-mode)
    (javascript . js-ts-mode)
    (json . json-ts-mode)
    (lua . lua-ts-mode)
    (python . python-ts-mode)
    (ruby . ruby-ts-mode)
    (rust . rust-ts-mode)
    (toml . toml-ts-mode)
    (tsx . tsx-ts-mode)
    (typescript . typescript-ts-mode)
    (yaml . yaml-ts-mode))
  "Alist mapping tree-sitter languages to their major modes.")

(defvar-local pollen-ts--configured-languages nil
  "List of languages whose configs have been loaded in this buffer.")

(defun pollen-ts--harvest-treesit-configs (mode)
  "Harvest tree-sitter configs from MODE.
Return a plist with :font-lock, :simple-indent, and :range."
  (with-temp-buffer
    (funcall mode)
    (list :font-lock treesit-font-lock-settings
          :simple-indent treesit-simple-indent-rules
          :range treesit-range-settings)))

(defun pollen-ts--add-config-for-mode (language mode)
  "Add font-lock and indent configs for LANGUAGE from MODE to current buffer."
  (let ((configs (pollen-ts--harvest-treesit-configs mode)))
    (ignore language)
    (setq treesit-font-lock-settings
          (append treesit-font-lock-settings
                  (plist-get configs :font-lock)))
    (setq treesit-range-settings
          (append treesit-range-settings
                  ;; Filter out function queries since they’re usually
                  ;; some hack and can escape the code block.
                  (seq-filter (lambda (setting)
                                (not (functionp (car setting))))
                              (plist-get configs :range))))
    (setq-local indent-line-function #'treesit-indent)
    (setq-local indent-region-function #'treesit-indent-region)))

(defun pollen-ts--code-block-language (node)
  "Return the tree-sitter language for a code block language NODE.
NODE is the `attr_symbol' node inside the `attr_quoted_symbol'.
Returns a language symbol, or nil to skip injection.
Only injects when the enclosing tag name matches
`pollen-ts-highlight-code-tag'."
  ;; Walk up: attr_symbol -> attr_quoted_symbol -> attr_block -> tag_expression
  (let* ((tag-expr (treesit-node-parent
                    (treesit-node-parent
                     (treesit-node-parent node))))
         (tag-name-node (treesit-node-child-by-field-name
                         tag-expr "name"))
         (tag-name (and tag-name-node
                        (treesit-node-text tag-name-node t))))
    (when (and tag-name (string-match-p
                         pollen-ts-highlight-code-tag-regexp tag-name))
      (let* ((lang-string (treesit-node-text node t))
             (lang-mapped (alist-get lang-string
                                     pollen-ts--code-block-language-map
                                     lang-string nil #'equal))
             (lang (if (symbolp lang-mapped)
                       lang-mapped
                     (intern (downcase lang-mapped)))))
        (let ((mode (alist-get lang
                               pollen-ts-code-block-source-mode-map)))
          (if (not (and mode (fboundp mode)))
              nil
            (when (not (memq lang pollen-ts--configured-languages))
              (pollen-ts--add-config-for-mode lang mode)
              (push lang pollen-ts--configured-languages))
            lang))))))

(defvar pollen-ts-mode--range-settings
  (treesit-range-rules
   :embed #'pollen-ts--code-block-language
   :host 'pollen
   :local t
   '((tag_expression
      attrs: (attr_block
              (attr_quoted_symbol (attr_symbol) @language))
      body: (tag_body) @content)))
  "Range settings for language injection in code blocks.")

;;; Font-lock

(defun pollen-ts-mode--header-font-lock-settings ()
  "Compute font-lock settings for header tags.
Returns a list of `treesit-font-lock-rules' settings based on
`pollen-ts-header-tag-regexp-list', one rule per header level."
  (let ((faces (mapcar (lambda (face)
                         (intern (format "@%s" (symbol-name face))))
                       '( outline-1 outline-2 outline-3 outline-4
                          outline-5 outline-6)))
        (idx 0)
        settings)
    (dolist (regexp pollen-ts-header-tag-regexp-list)
      (setq settings
            (append settings
                    (treesit-font-lock-rules
                     :language 'pollen
                     :feature 'header
                     :override 'append
                     `(((tag_expression
                         name: (tag_name) @_name
                         body: (tag_body) ,(nth idx faces))
                        (:match ,regexp @_name))))))
      (setq idx (min (1+ idx) 5)))
    settings))

(defvar pollen-ts-mode--font-lock-settings
  (when (treesit-available-p)
    (treesit-font-lock-rules
     :language 'pollen
     :feature 'comment
     '([(line_comment) (block_comment) (expr_comment)]
       @font-lock-comment-face)

     :language 'pollen
     :feature 'lang-line
     '((lang_line) @font-lock-preprocessor-face)

     :language 'pollen
     :feature 'lang-line
     :override 'append
     '((lang_line) @pollen-ts-mode-code-face)

     :language 'pollen
     :feature 'tag-name
     '((tag_expression
        name: (tag_name) @font-lock-function-call-face)
       (bare_variable_ref
        name: (tag_name) @font-lock-variable-use-face))

     :language 'pollen
     :feature 'tag-name
     :override 'append
     '((tag_expression
        name: (tag_name) @pollen-ts-mode-code-face)
       (bare_variable_ref
        name: (tag_name) @pollen-ts-mode-code-face))

     :language 'pollen
     :feature 'attribute
     '((attr_keyword) @font-lock-property-name-face
       (attr_symbol) @font-lock-constant-face
       (attr_keyword_pair
        value: (attr_string) @font-lock-string-face)
       (attr_block
        (attr_string) @font-lock-string-face))

     :language 'pollen
     :feature 'attribute
     :override 'append
     '((attr_block) @pollen-ts-mode-code-face)

     :language 'pollen
     :feature 'expression
     '((racket_expression) @font-lock-keyword-face
       (pipe_expression) @font-lock-variable-use-face)

     :language 'pollen
     :feature 'expression
     :override 'append
     '((racket_expression) @pollen-ts-mode-code-face
       (pipe_expression) @pollen-ts-mode-code-face)

     ;; :language 'pollen
     ;; :feature 'code
     ;; `(((tag_expression
     ;;     name: (tag_name) @_name
     ;;     body: (tag_body) @pollen-ts-mode-code-face)
     ;;    (:match ,pollen-ts-code-tag-regexp @_name)))

     :language 'pollen
     :feature 'delimiter
     :override t
     '("◊" @font-lock-punctuation-face
       "{" @font-lock-bracket-face
       "}" @font-lock-bracket-face
       "[" @font-lock-bracket-face
       "]" @font-lock-bracket-face)))
  "Tree-sitter font-lock settings for `pollen-ts-mode'.")

(defvar pollen-ts-mode--font-lock-feature-list
  '((comment lang-line)
    (header)
    (tag-name attribute expression delimiter code)
    ())
  "Tree-sitter font-lock feature list for `pollen-ts-mode'.")

;;; Mode definition

;;;###autoload
(define-derived-mode pollen-ts-mode text-mode "Pollen"
  "Major mode for editing Pollen files, powered by tree-sitter."
  :group 'pollen-ts
  :syntax-table pollen-ts-mode--syntax-table

  (when (treesit-ensure-installed 'pollen)
    (setq treesit-primary-parser (treesit-parser-create 'pollen))

    ;; Comments.
    (setq-local comment-start "◊; ")
    (setq-local comment-end "")

    ;; Indent.
    (setq-local treesit-simple-indent-rules
                pollen-ts-mode--indent-rules)

    ;; Language injection for code blocks.
    (setq-local treesit-range-settings
                pollen-ts-mode--range-settings)

    ;; Font-lock.
    (setq-local treesit-font-lock-settings
                (append pollen-ts-mode--font-lock-settings
                        (pollen-ts-mode--header-font-lock-settings)))
    (setq-local treesit-font-lock-feature-list
                pollen-ts-mode--font-lock-feature-list)

    (visual-line-mode)
    (variable-pitch-mode)

    (treesit-major-mode-setup)))

;;;###autoload
(progn
  (add-to-list 'auto-mode-alist '("\\.pm\\'" . pollen-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.pp\\'" . pollen-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.p\\'" . pollen-ts-mode)))

(provide 'pollen-ts-mode)
;;; pollen-ts-mode.el ends here
