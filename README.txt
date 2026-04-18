Pollen tree-sitter grammar with a Emacs major mode for writing pollen.
Disclosure: completely vibe-coded.
Disclaimer: use at your own risk.


Supports headers like

◊section{header level 1}
◊subsection{header level 2}

The tag name for headers can be customized with
pollen-ts-header-tag-regexp-list.



Supports inline code and code blocks like

◊code{inline code}

◊bcode{
  code block
}

Tag names can be customized with pollen-ts-code-tag-regexp.



Supports syntax highlighting for embedded code blocks with this
syntax:

◊bcode-hl['c]{
  <c code>
}

Change bcode-hl to some other tag by
pollen-ts-highlight-code-tag-regexp.
