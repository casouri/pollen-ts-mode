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

;;; Font-lock

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
    (tag-name attribute expression)
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
