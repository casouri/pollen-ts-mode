# Tree-sitter Pollen Grammar — Progress

## Phase 0: Project Skeleton
- [x] Create project directory and files
- [x] Initial grammar.js
- [x] Skeleton test passes

## Phase 1: Language Declaration
- [x] `#lang pollen` recognized
- [x] Test passes

## Phase 2: Plain Text
- [x] Text lines captured as `text` nodes
- [x] Test passes

## Phase 3: Empty Tag
- [x] `◊tag-name{}` recognized
- [x] Test passes

## Phase 4: Tag with Text Body
- [x] `◊tag{text}` recognized
- [x] Test passes

## Phase 5: Tag with Attribute Block
- [x] Positional attrs: `◊define-meta[date]{val}`
- [x] String attrs: `◊link["url"]{text}`
- [x] Keyword attrs: `◊span[#:class "author"]{text}`
- [x] Verbose quoted list: `◊span['((class "author"))]{text}`
- [x] Quoted symbol attrs: `◊bcode-hl['toml]{...}`
- [x] Test passes

## Phase 6: Racket Expression
- [x] `◊(s-expression)` with balanced parens
- [x] Test passes

## Phase 7: Variable Reference
- [x] `◊|name|` pipe-delimited
- [x] `◊|(expr)|` pipe expression
- [x] `◊name` bare variable ref
- [x] Test passes

## Phase 8: Comments
- [x] `◊; line comment`
- [x] `◊;{block comment}`
- [x] `◊;(expr comment)`
- [x] Test passes

## Phase 9: Nested Tags
- [x] Tags inside tag bodies
- [x] Test passes

## Phase 10: Multi-line Bodies & Inline Mixing
- [x] Multi-line tag bodies
- [x] Inline expressions within text lines
- [x] Balanced brace pairs in body text
- [x] Test passes

## Phase 11: Mixed HTML + Pollen
- [x] `.p` template files parse correctly
- [x] Test passes

## Phase 12: Complex Multi-line Racket Expressions
- [x] Deeply nested multi-line `◊(...)` expressions
- [x] Test passes

## Phase 13: Full Example File Parsing
- [x] `examples/ts.html.pm` — 0 errors
- [x] `examples/ot.html.pm` — 1 error (source typo: `◊code◊{o1}`)
- [x] `examples/rock48.html.pm` — 0 errors
- [x] `examples/rust.html.pm` — 0 errors
- [x] `examples/atom.xml.pp` — 0 errors
- [x] `examples/template.html.p` — 0 errors
- [x] `examples/index-template.html.p` — 0 errors

## Summary
- 45/45 corpus tests pass
- 6/7 example files parse with 0 ERROR nodes
- 1 file (ot.html.pm) has 1 ERROR from a source typo, not a grammar bug
- Grammar generates without conflicts
