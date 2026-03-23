# Implementation Phases (Red/Green TDD)

Each phase follows the cycle:

1. **Red** — write a failing corpus test that describes the new behavior
2. **Green** — extend `grammar.js` until `tree-sitter test` passes
3. **Refactor** — clean up the grammar, keep tests green
4. **Verify** — run `tree-sitter parse` on real example files

Phases are cumulative: each builds on the previous.

---

## Phase 0 — Project Skeleton

**Goal:** project initializes, empty grammar generates, trivial test passes.

### Setup steps

```bash
mkdir tree-sitter-pollen && cd tree-sitter-pollen
git init
npm init -y
npm install --save-dev tree-sitter-cli
npm install nan
```

Create `grammar.js`:
```js
module.exports = grammar({
  name: 'pollen',
  rules: {
    source_file: $ => repeat($._node),
    _node: $ => $.text,
    text: $ => /[^\n]+\n?/,
  }
});
```

```bash
tree-sitter generate
```

### Red test — `test/corpus/00_skeleton.txt`

```
===========================================
Empty file
===========================================

---
(source_file)

===========================================
Whitespace only
===========================================


---
(source_file
  (text))
```

**Expected:** `tree-sitter test` fails (grammar not yet correct).

### Green

Adjust `text` rule to handle empty files and whitespace lines.

### Verify

```bash
tree-sitter parse /dev/null   # should produce (source_file)
```

---

## Phase 1 — Language Declaration

**Goal:** Recognize `#lang pollen` as the first line.

### Grammar changes

Add `lang_line` rule:

```js
lang_line: $ => seq('#lang', /\s+/, 'pollen', /\n/),
source_file: $ => seq(
  optional($.lang_line),
  repeat($._node),
),
```

### Red test — `test/corpus/01_lang_declaration.txt`

```
===========================================
Lang line alone
===========================================
#lang pollen
---
(source_file
  (lang_line))

===========================================
Lang line followed by blank line
===========================================
#lang pollen

---
(source_file
  (lang_line))
```

### Green

Implement `lang_line` in grammar, regenerate, verify tests pass.

### Verify

```bash
echo '#lang pollen' | tree-sitter parse /dev/stdin
```

---

## Phase 2 — Plain Text

**Goal:** Lines of ordinary text (no `◊`) are captured as `text` nodes.

### Grammar changes

```js
text: $ => /[^◊\n][^\n]*\n?|[^\n]*\n/,
```

Or more precisely — text is any sequence of characters that does not begin
with `◊` and does not cross a line boundary at this stage. We'll revisit once
we introduce inline expressions.

### Red test — `test/corpus/02_plain_text.txt`

```
===========================================
Single line of text
===========================================
#lang pollen
Hello, world.
---
(source_file
  (lang_line)
  (text))

===========================================
Multiple lines
===========================================
#lang pollen
Line one.
Line two.
---
(source_file
  (lang_line)
  (text)
  (text))

===========================================
Unicode text
===========================================
#lang pollen
这是中文。日本語のテキスト。
---
(source_file
  (lang_line)
  (text))
```

### Green

Ensure `text` rule matches arbitrary Unicode lines.

---

## Phase 3 — Empty Tag

**Goal:** Recognize `◊tag-name{}` (tag with empty body).

### Grammar changes

```js
tag_name: $ => /[a-zA-Z_\-+*\/?!][a-zA-Z0-9_\-+*\/?!]*/,

tag_expression: $ => seq(
  '◊',
  field('name', $.tag_name),
  '{',
  '}',
),
```

Update `_node` to include `tag_expression`.

### Red test — `test/corpus/03_empty_tag.txt`

```
===========================================
Empty tag
===========================================
◊sep{}
---
(source_file
  (tag_expression
    (tag_name)))

===========================================
Empty tag with no preceding lang line
===========================================
◊smile{}
---
(source_file
  (tag_expression
    (tag_name)))

===========================================
Multiple empty tags
===========================================
◊sep{}
◊br{}
---
(source_file
  (tag_expression
    (tag_name))
  (tag_expression
    (tag_name)))
```

### Green

Implement and generate.

---

## Phase 4 — Tag with Text Body

**Goal:** Recognize `◊tag{text content}` where the body is plain text.

### Grammar changes

```js
tag_body: $ => repeat1($._body_node),
_body_node: $ => choice($.text, $.tag_expression, $.racket_expression),

tag_expression: $ => seq(
  '◊',
  field('name', $.tag_name),
  '{',
  optional(field('body', $.tag_body)),
  '}',
),

// text inside body: any chars except ◊, {, }
body_text: $ => /[^◊{}]+/,
```

Note: we need two text rules — `text` for top-level lines, `body_text` for
inside `{}` (where `{` and `}` are delimiters).

### Red test — `test/corpus/04_tag_with_body.txt`

```
===========================================
Tag with simple text body
===========================================
◊em{emphasized text}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (body_text))))

===========================================
Tag with body containing spaces
===========================================
◊sc{SMALL CAPS}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (body_text))))

===========================================
Section tag
===========================================
◊section{Narrowing and lazy parsing}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (body_text))))
```

### Green

Add `body_text` and update `tag_body` and `_body_node`. Regenerate and test.

---

## Phase 5 — Tag with Attribute Block

**Goal:** Recognize all three attribute block forms:
- Positional datums: `◊define-meta[date]{val}`, `◊link["url"]{text}`
- Keyword pairs: `◊span[#:class "author" #:id "primary"]{text}`
- Verbose quoted list: `◊span['((class "author"))]{text}`

### Grammar changes

```js
// Shared identifier pattern
_identifier: $ => /[a-zA-Z_\-+*\/?!][a-zA-Z0-9_\-+*\/?!]*/,

attr_symbol: $ => alias($._identifier, $.attr_symbol),
attr_string: $ => /"[^"]*"/,

// #:keyword value  (keyword argument form)
attr_keyword: $ => /#:[a-zA-Z_\-+*\/?!][a-zA-Z0-9_\-+*\/?!]*/,
attr_keyword_pair: $ => seq(
  field('keyword', $.attr_keyword),
  /\s+/,
  field('value', choice($.attr_string, $.attr_symbol)),
),

// '((key "val") ...) verbose form
attr_quoted_list: $ => seq(
  "'",
  '(',
  repeat(seq(
    '(',
    $.attr_symbol,
    /\s+/,
    $.attr_string,
    ')',
  )),
  ')',
),

attr_block: $ => seq(
  '[',
  choice(
    repeat1(seq(/\s*/, $.attr_keyword_pair)),   // keyword form
    repeat1(seq(/\s*/, choice($.attr_symbol, $.attr_string))),  // positional form
    $.attr_quoted_list,                          // verbose form
  ),
  /\s*/,
  ']',
),

tag_expression: $ => seq(
  '◊',
  field('name', $.tag_name),
  optional(field('attrs', $.attr_block)),
  '{',
  optional(field('body', $.tag_body)),
  '}',
),
```

### Red test — `test/corpus/05_tag_with_attrs.txt`

```
===========================================
define-meta with symbol attr
===========================================
◊define-meta[date]{2025-07-12}
---
(source_file
  (tag_expression
    (tag_name)
    (attr_block
      (attr_symbol))
    (tag_body
      (body_text))))

===========================================
link with string attr
===========================================
◊link["https://example.com"]{click here}
---
(source_file
  (tag_expression
    (tag_name)
    (attr_block
      (attr_string))
    (tag_body
      (body_text))))

===========================================
fnref with string attr
===========================================
◊fnref["comp-doc"]{complement of the documentation}
---
(source_file
  (tag_expression
    (tag_name)
    (attr_block
      (attr_string))
    (tag_body
      (body_text))))

===========================================
keyword attribute — single pair
===========================================
◊span[#:class "author"]{Prof. Leonard}
---
(source_file
  (tag_expression
    (tag_name)
    (attr_block
      (attr_keyword_pair
        (attr_keyword)
        (attr_string)))
    (tag_body
      (body_text))))

===========================================
keyword attributes — multiple pairs
===========================================
◊span[#:class "author" #:id "primary" #:living "true"]{Prof. Leonard}
---
(source_file
  (tag_expression
    (tag_name)
    (attr_block
      (attr_keyword_pair
        (attr_keyword)
        (attr_string))
      (attr_keyword_pair
        (attr_keyword)
        (attr_string))
      (attr_keyword_pair
        (attr_keyword)
        (attr_string)))
    (tag_body
      (body_text))))

===========================================
verbose quoted attr list
===========================================
◊span['((class "author")(id "primary"))]{Prof. Leonard}
---
(source_file
  (tag_expression
    (tag_name)
    (attr_block
      (attr_quoted_list
        (attr_symbol)
        (attr_string)
        (attr_symbol)
        (attr_string)))
    (tag_body
      (body_text))))
```

### Green

Implement `attr_block` with all three sub-forms: `attr_keyword_pair`,
positional `attr_symbol`/`attr_string`, and `attr_quoted_list`.

---

## Phase 6 — Racket Expression

**Goal:** Recognize `◊(s-expression)` with balanced parentheses.

This is the trickiest rule because Racket expressions can be arbitrarily
nested and multi-line.

### Grammar changes

Tree-sitter cannot natively count balanced parens in a context-free grammar,
but we can use an `external` scanner (C code) or approximate with a recursive
rule. For a correct implementation, use an external scanner:

```js
externals: $ => [
  $._racket_expr_content,
],
```

The external scanner reads characters, tracks paren depth, and emits the
whole expression as a single token.

Alternatively, use a recursive grammar rule if depth is bounded (not ideal).

Simple approximation using regex (works for most cases, not deeply nested):

```js
racket_expression: $ => seq(
  '◊',
  '(',
  $._racket_content,
  ')',
),

_racket_content: $ => repeat($._racket_atom),
_racket_atom: $ => choice(
  /[^()"\n]+/,            // non-paren text
  /"[^"]*"/,              // string
  seq('(', $._racket_content, ')'),  // nested parens
),
```

The external scanner approach is recommended for Phase 9 (complex
multi-line expressions); start with the recursive approach here.

### Red test — `test/corpus/06_racket_expr.txt`

```
===========================================
Simple function call
===========================================
◊(rfc3339)
---
(source_file
  (racket_expression))

===========================================
Function call with argument
===========================================
◊(->html doc)
---
(source_file
  (racket_expression))

===========================================
Function call with string argument
===========================================
◊(->html (note-feed-entry "2025/boritina"))
---
(source_file
  (racket_expression))

===========================================
require expression
===========================================
◊(require "pollen.rkt" pollen/template)
---
(source_file
  (racket_expression))

===========================================
define-meta in preprocessor style
===========================================
◊(define-meta rss-mode "yay")
---
(source_file
  (racket_expression))
```

### Green

Implement `racket_expression` with recursive `_racket_content`.

---

## Phase 7 — Variable Reference

**Goal:** Recognize all three variable reference forms:
- `◊|name|` — pipe-delimited name
- `◊|(expr)|` — pipe-delimited expression
- `◊name` — bare name (no braces/brackets following)

### Grammar changes

```js
// Pipe-delimited: ◊|foo| or ◊|(* x 2)|
pipe_expression: $ => seq(
  '◊',
  '|',
  field('content', /[^|]+/),  // anything between pipes
  '|',
),

// Bare variable: ◊foo (identifier NOT followed by { or [)
// This conflicts with tag_expression — resolve via lookahead / precedence.
// tag_expression requires ◊ name ( optional_attr ) {
// bare_variable_ref requires ◊ name (end of token / non-{ non-[ follows)
bare_variable_ref: $ => seq(
  '◊',
  field('name', $.tag_name),
  // no { or [ follows — enforced by conflict resolution or external scanner
),
```

**Conflict resolution:** `tag_expression` and `bare_variable_ref` both start
with `◊ identifier`. Use `prec` or a GLR conflict to resolve: prefer
`tag_expression` when `[` or `{` follows, prefer `bare_variable_ref` otherwise.

```js
conflicts: $ => [
  [$.tag_expression, $.bare_variable_ref],
],
```

Update `_node` and `_body_node` to include `pipe_expression` and
`bare_variable_ref`.

### Red test — `test/corpus/07_variable_ref.txt`

```
===========================================
Pipe-delimited variable reference
===========================================
◊|author-en|
---
(source_file
  (pipe_expression))

===========================================
Pipe-delimited variable inside HTML
===========================================
<name>◊|author-en|</name>
---
(source_file
  (text)
  (pipe_expression)
  (text))

===========================================
Pipe-delimited expression (computed value)
===========================================
margin: ◊|(* inner 2)|em;
---
(source_file
  (text)
  (pipe_expression)
  (text))

===========================================
Bare variable reference
===========================================
The author is ◊author.
---
(source_file
  (text)
  (bare_variable_ref
    (tag_name))
  (text))

===========================================
Bare variable reference adjacent to punctuation
===========================================
Next is ◊pi.
---
(source_file
  (text)
  (bare_variable_ref
    (tag_name))
  (text))
```

### Green

Implement `pipe_expression` (straightforward) and `bare_variable_ref`
(requires conflict resolution with `tag_expression`). Adjust precedence
until `tree-sitter test` passes and `tree-sitter generate` reports no
unresolved conflicts.

---

## Phase 8 — Comments

**Goal:** Recognize all three comment forms:
- `◊; text to end of line` — line comment
- `◊;{block comment}` — block comment
- `◊;(expr)` — expression comment

### Grammar changes

```js
line_comment: $ => seq(
  '◊',
  ';',
  /[^({][^\n]*/,   // not followed by { or ( — runs to EOL
  /\n/,
),

block_comment: $ => seq(
  '◊',
  ';',
  '{',
  /[^}]*/,    // does not handle nested braces; extend if needed
  '}',
),

expr_comment: $ => seq(
  '◊',
  ';',
  '(',
  $._racket_content,
  ')',
),

comment: $ => choice(
  $.line_comment,
  $.block_comment,
  $.expr_comment,
),
```

Comments are added to `extras` so they can appear anywhere in the document
without requiring explicit handling in every rule:

```js
extras: $ => [
  /[ \t]/,     // horizontal whitespace only (newlines are significant)
  $.comment,
],
```

### Red test — `test/corpus/08_comments.txt`

```
===========================================
Line comment
===========================================
◊; this entire line is ignored
◊em{visible}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (body_text))))

===========================================
Block comment
===========================================
◊;{This is a comment}
---
(source_file)

===========================================
Expression comment
===========================================
◊;(->html (like-button))
---
(source_file)

===========================================
Comment inside tag body
===========================================
◊section{
  ◊;{TODO: write this section}
  Some text.
}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (body_text))))

===========================================
Expression comment from template.html.p
===========================================
◊;(->html (like-button))
◊(->html (footer doc))
---
(source_file
  (racket_expression))
```

Note: since comments are in `extras`, they are invisible in the parse tree.
If syntax-highlighting queries need to match comment nodes, remove from
`extras` and add to `_node` / `_body_node` explicitly, and adjust all tests
to include `(comment)` nodes.

### Green

Implement all three comment rules. Decide `extras` vs. named nodes. Verify
no ambiguity between `line_comment` and other `◊;` forms via the lookahead
character after `;`.

---

## Phase 9 — Nested Tags

**Goal:** Tags inside tag bodies work correctly.

By Phase 4 `_body_node` already includes `tag_expression`, so this phase
focuses on ensuring complex nesting parses correctly and writing explicit
tests.

### Red test — `test/corpus/09_nested_tags.txt`

```
===========================================
Tag inside tag
===========================================
◊h2{◊jpns{勇次}}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (tag_expression
        (tag_name)
        (tag_body
          (body_text))))))

===========================================
Multiple children in body
===========================================
◊ul{
  ◊li{first}
  ◊li{second}
}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (tag_expression
        (tag_name)
        (tag_body
          (body_text)))
      (tag_expression
        (tag_name)
        (tag_body
          (body_text))))))

===========================================
Ruby annotation
===========================================
◊ruby{渕◊rt{yuān}}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (body_text)
      (tag_expression
        (tag_name)
        (tag_body
          (body_text))))))

===========================================
meta block
===========================================
◊meta{
  ◊title{In-depth Review}
  ◊subtitle{foundation}
}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (tag_expression
        (tag_name)
        (tag_body
          (body_text)))
      (tag_expression
        (tag_name)
        (tag_body
          (body_text))))))
```

### Green

Verify existing grammar handles these. Add tests, fix any parse conflicts.

---

## Phase 10 — Multi-line Bodies

**Goal:** Tag bodies spanning multiple lines parse correctly.

The `body_text` rule must allow newlines. Top-level `text` and `body_text`
need to be distinguished properly.

### Grammar changes

Update `body_text` to be multi-character including newlines, stopping at
`◊`, `{`, or `}`:

```js
body_text: $ => /[^◊{}]+/,  // already matches newlines in tree-sitter
```

Tree-sitter's regex `.` does NOT match newlines by default, but character
classes like `[^◊{}]` DO match newlines. Verify this works.

### Red test — `test/corpus/10_multiline_body.txt`

```
===========================================
Multi-line tag body
===========================================
◊bquote{
First line.
Second line.
Third line.
}
---
(source_file
  (tag_expression
    (tag_name)
    (tag_body
      (body_text))))

===========================================
Inline expression in paragraph
===========================================
The tree-sitter integration is ◊em{settled} and works well.
---
(source_file
  (text)
  (tag_expression
    (tag_name)
    (tag_body
      (body_text)))
  (text))
```

Note: inline expressions within a text line require splitting `text` at `◊`
boundaries. This is the key challenge of Phase 10 — the top-level must
interleave `text` and `tag_expression` on the same line.

### Grammar changes for inline mixing

Refactor `source_file` body:

```js
// A paragraph is a sequence of inline nodes
_inline: $ => choice(
  $.tag_expression,
  $.racket_expression,
  $.pipe_expression,
  $.bare_variable_ref,
  $.body_text,
),

// A top-level node is either a blank line, a full-text line (no ◊), or an inline sequence
```

This is the most complex change. Consider treating the entire document body
as a stream of interleaved text chunks and expressions.

### Green

Iterate on `text` vs `body_text` rules until inline mixing works. Use
`tree-sitter parse` on the real example files to guide the iteration.

---

## Phase 11 — Mixed HTML + Pollen

**Goal:** `.p` template files with HTML interspersed with `◊(...)` parse
without ERROR nodes.

HTML is simply plain text from the grammar's perspective. The challenge is
that `<`, `>`, `"`, etc. appear in what the grammar calls `text` or
`body_text`.

### Red test — `test/corpus/11_mixed_html.txt`

```
===========================================
HTML attribute with Pollen expression
===========================================
<html lang="◊(get-language "en")">
---
(source_file
  (text)
  (racket_expression)
  (text))

===========================================
Full template snippet
===========================================
<title>◊(->html (select 'title doc))</title>
---
(source_file
  (text)
  (racket_expression)
  (text))

===========================================
Comment inside template
===========================================
◊;(->html (like-button))
◊(->html (footer doc))
---
(source_file
  (racket_expression))
```

### Green

Ensure `text` consumes HTML characters. Verify `tree-sitter parse
examples/template.html.p` has no ERROR nodes.

---

## Phase 12 — Complex Multi-line Racket Expressions

**Goal:** Deeply nested and multi-line `◊(...)` expressions parse correctly.

From examples/template.html.p:
```
◊(->html (footer (get-language "en") doc
(or (select 'title doc) "No title")
#:rss "/note/atom.xml"))
```

The recursive `_racket_content` rule should handle this if `body_text` allows
newlines. Verify and add explicit tests.

### Red test — `test/corpus/12_complex_exprs.txt`

```
===========================================
Multi-line racket expression
===========================================
◊(->html (footer (get-language "en") doc
  (or (select 'title doc) "No title")
  #:rss "/note/atom.xml"))
---
(source_file
  (racket_expression))

===========================================
Racket expression with quoted strings containing parens
===========================================
◊(link "https://example.com/page(1)" "title")
---
(source_file
  (racket_expression))

===========================================
define-meta as racket expression
===========================================
◊(define-meta rss-mode "yay")
---
(source_file
  (racket_expression))
```

### Green

Confirm recursive `_racket_content` handles these. If not, implement the
external scanner for balanced parens.

---

## Phase 13 — Full Example File Parsing

**Goal:** Zero ERROR nodes in all six example files.

### Verification commands

```bash
for f in examples/*.pm examples/*.pp examples/*.p; do
  echo "=== $f ==="
  tree-sitter parse "$f" | grep -c ERROR || echo "0 errors"
done
```

Expected output: `0 errors` for every file.

### Files to verify

| File | Challenge |
|------|-----------|
| `examples/ts.html.pm` | Dense prose with `◊em`, `◊link`, `◊fnref`, `◊fndef`, `◊section`, `◊code`, `◊bcode` |
| `examples/ot.html.pm` | Long academic article, footnotes, sections |
| `examples/rock48.html.pm` | CJK text, `◊ruby`, `◊rt`, `◊lyrics`, `◊jpns`, `◊trans` |
| `examples/atom.xml.pp` | XML + `◊(...)` expressions, `◊\|var\|` |
| `examples/template.html.p` | HTML template with inline `◊(...)` |
| `examples/index-template.html.p` | Same pattern |

---

## Node Type Summary (Final Grammar)

```
source_file
  lang_line
  tag_expression
    tag_name
    attr_block                       (optional)
      attr_keyword_pair              (◊tag[#:key "val"]{})
        attr_keyword                 (#:class)
        attr_string | attr_symbol    ("value" or symbol)
      attr_symbol                    (positional bare symbol)
      attr_string                    (positional quoted string)
      attr_quoted_list               (verbose '((key "val")) form)
        attr_symbol
        attr_string
    tag_body                         (optional)
      body_text
      tag_expression                 (recursive)
      racket_expression
      pipe_expression
      bare_variable_ref
  racket_expression                  (◊(expr))
  pipe_expression                    (◊|name| or ◊|(expr)|)
  bare_variable_ref                  (◊name with no following { or [)
    tag_name
  comment                            (in extras — hidden from tree)
    line_comment                     (◊; text to EOL)
    block_comment                    (◊;{...})
    expr_comment                     (◊;(...))
  text                               (top-level plain text / HTML)
  body_text                          (plain text inside tag body)
```

---

## Test Execution Checklist

After each phase:

- [ ] `tree-sitter generate` — no grammar conflicts
- [ ] `tree-sitter test` — all corpus tests pass
- [ ] `tree-sitter test -i "<phase name>"` — new tests pass specifically
- [ ] `tree-sitter parse examples/<relevant-file>` — no ERROR nodes in the file(s) relevant to this phase

After Phase 13 (final):

- [ ] `tree-sitter test` — 100% pass
- [ ] All 6 example files: 0 ERROR nodes
- [ ] `npm test` works end-to-end
- [ ] Grammar generates without warnings about conflicts
