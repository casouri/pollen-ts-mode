# Tree-sitter Grammar for Pollen: Build Plan

## Overview

[Pollen](https://docs.racket-lang.org/pollen/) is a publishing system for Racket. Its markup syntax is characterized by the lozenge character `◊` (U+25CA) as a command prefix, with content in curly braces `{}`, optional attributes in square brackets `[]`, and embedded Racket s-expressions in parentheses `()`.

This plan describes how to build a tree-sitter grammar for Pollen using red/green TDD, from environment setup through a fully tested, published grammar.

---

## Documents

- [environment.md](environment.md) — toolchain setup and project initialization
- [syntax.md](syntax.md) — complete Pollen syntax reference with examples
- [phases.md](phases.md) — phased TDD implementation plan with corpus tests

---

## Deliverables

The finished grammar will recognize:

| Construct | Example |
|-----------|---------|
| Language declaration | `#lang pollen` |
| Plain text (body content) | `Hello, world.` |
| Tag (empty body) | `◊sep{}` |
| Tag with text body | `◊em{emphasized}` |
| Tag with positional attr | `◊define-meta[date]{2025-01-01}` |
| Tag with string attr | `◊link["https://…"]{click here}` |
| Tag with keyword attrs | `◊span[#:class "author" #:id "x"]{text}` |
| Tag with verbose attr list | `◊span['((class "author"))]{text}` |
| Nested tags | `◊ul{◊li{item}}` |
| Racket expression | `◊(->html doc)` |
| Multi-line Racket expression | `◊(func arg1\n  arg2)` |
| Pipe variable reference | `◊\|author-en\|` |
| Pipe expression | `◊\|(* x 2)\|` |
| Bare variable reference | `◊author` (no braces follows) |
| Line comment | `◊; text to end of line` |
| Block comment | `◊;{block comment}` |
| Expression comment | `◊;(commented-out-expr)` |
| Mixed HTML + Pollen | `.p` template files |
| Multi-line tag bodies | paragraphs spanning lines |

---

## Success Criteria

1. All corpus tests pass (`tree-sitter test`)
2. All six example files parse without ERROR nodes (`tree-sitter parse examples/*.p*`)
3. The grammar correctly identifies all node types listed above
4. No catastrophic backtracking or ambiguity warnings during `tree-sitter generate`

---

## File Extensions

| Extension | Meaning |
|-----------|---------|
| `.pm` | Pollen markup — main content files |
| `.pp` | Pollen preprocessor — usually outputs non-HTML |
| `.p` | Pollen template — HTML mixed with `◊(...)` calls |

All three share the same `◊` syntax; they differ only in what the host language expects.
