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

;;; Font-lock

(defun pollen-ts-mode--header-font-lock-rules ()
  "Generate font-lock rules for header tags based on `pollen-ts-header-tag-regexp-list'."
  (let ((faces [outline-1 outline-2 outline-3 outline-4 outline-5 outline-6])
        (idx 0)
        rules)
    (dolist (regexp pollen-ts-header-tag-regexp-list)
      (when (< idx 6)
        (push `(:language pollen
                :feature header
                :override append
                ((tag_expression
                  name: (tag_name) @_name
                  body: (tag_body) @,(aref faces idx)
                  (:match ,regexp @_name))))
              rules))
      (setq idx (1+ idx)))
    (nreverse rules)))

(defvar pollen-ts-mode--font-lock-settings
  (when (treesit-available-p)
    (apply
     #'treesit-font-lock-rules
     (append
      (list
       :language 'pollen
       :feature 'comment
       '([(line_comment) (block_comment) (expr_comment)]
         @font-lock-comment-face)

       :language 'pollen
       :feature 'lang-line
       '((lang_line) @font-lock-preprocessor-face)

       :language 'pollen
       :feature 'tag-name
       '((tag_expression
          name: (tag_name) @font-lock-function-call-face)
         (bare_variable_ref
          name: (tag_name) @font-lock-variable-use-face))

       :language 'pollen
       :feature 'attribute
       '((attr_keyword) @font-lock-property-name-face
         (attr_symbol) @font-lock-constant-face
         (attr_keyword_pair
          value: (attr_string) @font-lock-string-face)
         (attr_block
          (attr_string) @font-lock-string-face))

       :language 'pollen
       :feature 'expression
       '((racket_expression) @font-lock-keyword-face
         (pipe_expression) @font-lock-variable-use-face)

       :language 'pollen
       :feature 'code
       :override 'append
       `((tag_expression
          name: (tag_name) @_name
          body: (tag_body) @pollen-ts-mode-code-face
          (:match ,pollen-ts-code-tag-regexp @_name))))

      ;; Header rules (one per level)
      (apply #'append (pollen-ts-mode--header-font-lock-rules))

      (list
       :language 'pollen
       :feature 'delimiter
       :override t
       '("◊" @font-lock-punctuation-face
         "{" @font-lock-bracket-face
         "}" @font-lock-bracket-face
         "[" @font-lock-bracket-face
         "]" @font-lock-bracket-face)))))
  "Tree-sitter font-lock settings for `pollen-ts-mode'.")

(defvar pollen-ts-mode--font-lock-feature-list
  '((comment lang-line)
    (tag-name attribute expression code header)
    (delimiter)
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

    ;; Font-lock.
    (setq-local treesit-font-lock-settings
                pollen-ts-mode--font-lock-settings)
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
