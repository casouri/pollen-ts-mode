# Pollen Syntax Reference

All forms are introduced by the **lozenge** character `◊` (U+25CA, "◊").

---

## 1. Language Declaration

Every Pollen file begins with a `#lang` line.

```
#lang pollen
```

This is the first line of the file. It signals to the Racket runtime which
language to use. For grammar purposes it is a fixed header.

---

## 2. Tag Expression

The primary construct. Invokes a Pollen tag/function.

### 2a. Tag with body only

```
◊tag-name{body content}
```

- `tag-name` is a Racket identifier: letters, digits, hyphens, `+`, `-`, `*`,
  `/`, `?`, `!`, etc.
- Body is arbitrary Pollen content (text + nested expressions).
- Body may span multiple lines.

Examples from examples/:
```
◊em{emphasized text}
◊sc{SMALL CAPS}
◊code{TSTree}
◊sep{}
◊smile{}
◊section{Narrowing and lazy parsing}
◊h2{◊jpns{勇次}}
```

### 2b. Tag with attributes and body

```
◊tag-name[attr-expr ...]{body content}
```

The `[...]` block contains one or more Racket datums. There are three forms:

#### Form 1 — Keyword arguments (most common for HTML attributes)

`#:keyword-name value` pairs, where value is a Racket datum:

```
◊span[#:class "author"]{Prof. Leonard}
◊span[#:class "author" #:id "primary" #:living "true"]{Prof. Leonard}
◊title[#:class "red" #:id "first"]{The Beginning of the End}
```

The `#:` prefix marks a Racket keyword. The value following each keyword is
a string, symbol, or number. These become HTML attributes in the output
X-expression:
```
'(span ((class "author") (id "primary") (living "true")) "Prof. Leonard")
```

Multiple keyword pairs are separated by whitespace.

#### Form 2 — Positional datums (common for `define-meta`, `link`, `fnref`)

One or more bare symbols or quoted strings, without `#:` prefix:

```
◊define-meta[date]{<2025-07-12 Sat 22:35>}
◊define-meta[uuid]{3e8c6fbe-5fab-11f0-ac6b-77f15a8205a7}
◊define-meta[tags]{Emacs}
◊define-meta[lang]{en}
◊link["https://github.com/amaanq"]{Amaan Qureshi}
◊link["/note/2023/tree-sitter-starter-guide/index.html"]{Tree-sitter Starter Guide}
◊fnref["comp-doc"]{complement of the documentation}
◊fndef["comp-doc"]{Well, I've written ...}
```

The attr block may contain:
- Bare symbols: `[date]`, `[lang]`, `[uuid]`
- Quoted strings: `["url"]`, `["ref-name"]`
- Multiple datums: `[attr1 attr2]`

#### Form 3 — Verbose X-expression list (rare)

An explicit association list using Racket quote syntax:

```
◊span['((class "author")(id "primary"))]{Prof. Leonard}
```

This is the underlying representation; the keyword form (Form 1) is
syntactic sugar for it. Rarely written by hand but must be parseable.

### 2c. Tag with attributes only (no body)

Technically the body `{}` is still required in Pollen, but can be empty:
```
◊sep{}
◊smile{}
```

### 2d. Nested tags

Body content can itself contain tag expressions:

```
◊ul{
  ◊li{first item}
  ◊li{second item}
}
◊ruby{渕◊rt{yuān}}
◊meta{
  ◊title{Document Title}
  ◊subtitle{Subtitle}
}
◊lyrics{
  ◊jpns{Japanese text}
  ◊trans{English translation}
}
```

---

## 3. Racket Expression

Embeds arbitrary Racket code directly.

```
◊(racket-s-expression)
```

The parenthesized form is a full Racket s-expression. It may be:
- A simple function call: `◊(rfc3339)`
- A function call with args: `◊(->html doc)`
- A complex nested call:
  ```
  ◊(->html (footer (get-language "en") doc
            (or (select 'title doc) "No title")
            #:rss "/note/atom.xml"))
  ```
- A `define` or `require`:
  ```
  ◊(require "pollen.rkt" pollen/template)
  ◊(define-meta rss-mode "yay")
  ```

The parentheses must be balanced. The expression may span multiple lines.

---

## 4. Variable Reference

There are three forms for inserting a variable's value:

### 4a. Bare variable name

```
◊variable-name
```

When `◊` is followed by an identifier that has no `{...}` or `[...]` after it,
Pollen inserts the variable's value as a string. This looks identical to a tag
name syntactically — the distinction is whether it is followed by `{`. In the
grammar, `◊name` with no trailing `{` or `[` is a `variable_ref`, not a tag.

```
The author is ◊author.
Next is ◊variable-name and more text.
```

### 4b. Pipe-delimited variable

```
◊|variable-name|
```

Pipe delimiters make the boundary explicit, useful when the variable name is
adjacent to text with no whitespace separator:

```
<name>◊|author-en|</name>
margin: ◊|edge|px;
```

Example from atom.xml.pp:
```
<name>◊|author-en|</name>
```

### 4c. Pipe-delimited expression

```
◊|racket-expression|
```

The pipes can also contain an arbitrary Racket expression (not just a name):

```
p { margin-left: ◊|(* inner 2)|em; }
```

This is distinct from `◊(expr)` in that the result is inserted inline without
whitespace ambiguity at the call site.

---

## 5. Comments

All comment forms begin with `◊;`.

### 5a. Line comment

```
◊; this entire line is a comment
```

`◊;` followed by a space (or any non-`{`/non-`(` character) comments out to
the end of the line, analogous to `;` in Racket.

### 5b. Block comment (curly-brace delimited)

```
◊;{This text is a comment and will not appear in output}
```

The `{...}` form can span multiple lines.

### 5c. Expression comment (paren-delimited)

```
◊;(->html (like-button))
```

`◊;` followed immediately by `(...)` comments out a balanced Racket
s-expression. From examples/template.html.p:

```
◊;(->html (like-button))
```

### Summary

| Form | Syntax | Scope |
|------|--------|-------|
| Line | `◊; text` | to end of line |
| Block | `◊;{...}` | `{}`-delimited, may be multi-line |
| Expression | `◊;(...)` | balanced parens |

---

## 6. Plain Text / Body Text

Everything that is not a `◊`-prefixed form is plain text. In `.pm` files
paragraphs are separated by blank lines (like Markdown). In `.p` template
files the plain text is mostly HTML.

Plain text may contain:
- Unicode characters (CJK, accented, etc.)
- HTML tags (`<br>`, `<span>`, etc.) when in `.p` files
- XML/HTML attributes containing `◊(...)` expressions
- Anything except unescaped `◊`

---

## 7. Host Language Content (`.p` and `.pp` files)

`.p` template files mix HTML with Pollen:

```html
<!DOCTYPE html>
<html lang="◊(get-language "en")">
  <head>
    <title>◊(->html (select 'title doc))</title>
  </head>
  <body>
    ◊(->html (header-line))
    <main>◊(doc->html doc)</main>
  </body>
</html>
```

`.pp` preprocessor files may mix XML:

```xml
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <updated>◊(rfc3339)</updated>
  ◊(->html (note-feed-entry "2025/boritina"))
</feed>
```

For grammar purposes the host language content is treated as undifferentiated
text; only `◊`-prefixed forms are parsed structurally.

---

## 8. Summary: Token Shapes

| Token | Pattern | Used in |
|-------|---------|---------|
| Lozenge | `◊` (U+25CA) | all command forms |
| Identifier | `[a-zA-Z_\-+*/?!][a-zA-Z0-9_\-+*/?!]*` | tag names, var names, attr symbols |
| `{` / `}` | literal | body delimiters |
| `[` / `]` | literal | attribute block delimiters |
| `(` / `)` | balanced | Racket expression delimiters |
| `\|` / `\|` | literal | pipe variable/expression delimiters |
| `#:` prefix | literal | keyword argument marker in attr block |
| `#lang pollen` | fixed string | language declaration (first line) |
| `◊;` | literal | comment introducer |
| `'` | literal | quote in verbose attr form |
| Quoted string | `"[^"]*"` | attr values, Racket string literals |
| Plain text | any non-`◊` sequence | body text, top-level text |

---

## 9. Edge Cases

- **Tag vs variable ambiguity:** `◊name` is a variable ref if not followed by
  `{` or `[`, and a tag call if followed by `{` (optionally preceded by `[...]`).
  The grammar must look ahead one token to distinguish them.
- **Bare `◊` in text:** must be followed by an identifier, `(`, `|`, or `;`.
  A bare `◊` followed by whitespace is a Pollen error; the grammar should
  produce an ERROR node rather than silently consuming it.
- **Escaped lozenge:** `◊"◊"` outputs a literal lozenge (via Racket string
  expression). This is just a `racket_expression` and needs no special casing.
- **Nested braces in body:** `{` and `}` inside a body are only special as
  delimiters of inner tag expressions. A bare `{` in body text is an error.
- **Empty body** `◊tag{}`: valid — produces an element with no children.
- **Body with only whitespace** `◊tag{ }`: valid.
- **Keyword value types in attr block:** after `#:keyword` the value must be
  a Racket datum — a quoted string `"..."`, a symbol, a number, or `#t`/`#f`.
  The grammar needs to handle at minimum: strings and symbols.
- **Verbose attr form with quote:** `◊span['((class "x"))]{...}` — the `'`
  introduces a Racket quoted list. This form is uncommon but syntactically
  valid; model it as a `quoted_attr_list` node.
