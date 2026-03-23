module.exports = grammar({
  name: 'pollen',

  extras: $ => [/[ \t]/],

  rules: {
    source_file: $ => seq(
      optional($.lang_line),
      repeat($._node),
    ),

    // Single token so it wins over text by length
    lang_line: $ => /#lang[ \t]+[a-zA-Z][a-zA-Z0-9\/\-]*\n/,

    _node: $ => choice(
      $.tag_expression,
      $.racket_expression,
      $.pipe_expression,
      $.bare_variable_ref,
      $.comment,
      $.text,
      /[{}\[\]]/,  // bare delimiters that appear in text (HTML, etc.)
      /\n/,
    ),

    // Top-level text: excludes ◊, {, }, [, ], newline so delimiters
    // are recognized as separate tokens for tag_expression parsing
    text: $ => /[^◊{}\[\]\n]+/,

    // Tag expression: ◊name[attrs]{body}
    tag_expression: $ => prec(1, seq(
      '◊',
      field('name', $.tag_name),
      optional(field('attrs', $.attr_block)),
      '{',
      optional(field('body', $.tag_body)),
      '}',
    )),

    tag_name: $ => /[a-zA-Z_\-+*\/?!][a-zA-Z0-9_\-+*\/?!]*/,

    // Tag body: sequence of body nodes
    tag_body: $ => repeat1($._body_node),

    _body_node: $ => choice(
      $.tag_expression,
      $.racket_expression,
      $.pipe_expression,
      $.bare_variable_ref,
      $.comment,
      $.body_text,
      $._brace_pair,   // balanced braces in body text (e.g., ASCII art)
      /[\[\]]/,        // bare brackets in body text
    ),

    // Body text: any characters except ◊, {, }, [, ]
    body_text: $ => /[^◊{}\[\]]+/,

    // Balanced brace pair in body text — Pollen allows balanced { } in body
    _brace_pair: $ => seq('{', optional($.tag_body), '}'),

    // Attribute block: [...]
    attr_block: $ => seq(
      '[',
      $._attr_content,
      ']',
    ),

    _attr_content: $ => choice(
      $._attr_keyword_list,
      $._attr_positional_list,
      $.attr_quoted_list,
    ),

    _attr_keyword_list: $ => repeat1($.attr_keyword_pair),

    attr_keyword_pair: $ => seq(
      field('keyword', $.attr_keyword),
      /[ \t]+/,
      field('value', choice($.attr_string, $.attr_symbol)),
    ),

    _attr_positional_list: $ => repeat1(choice($.attr_symbol, $.attr_string, $.attr_quoted_symbol)),

    // Racket quoted symbol: 'symbol (e.g., ['toml] or ['title])
    attr_quoted_symbol: $ => seq("'", $.attr_symbol),

    attr_keyword: $ => /#:[a-zA-Z_\-+*\/?!][a-zA-Z0-9_\-+*\/?!]*/,
    attr_symbol: $ => /[a-zA-Z_\-+*\/?!][a-zA-Z0-9_\-+*\/?!]*/,
    attr_string: $ => /"[^"]*"/,

    attr_quoted_list: $ => seq(
      "'",
      '(',
      repeat(seq(
        '(',
        $.attr_symbol,
        $.attr_string,
        ')',
      )),
      ')',
    ),

    // Racket expression: ◊(...)
    racket_expression: $ => seq(
      '◊',
      '(',
      optional($._racket_content),
      ')',
    ),

    _racket_content: $ => repeat1($._racket_atom),

    _racket_atom: $ => choice(
      /[^()"]+/,           // non-paren, non-quote text
      /"[^"]*"/,           // string literal
      seq('(', optional($._racket_content), ')'),  // nested parens
    ),

    // Pipe expression: ◊|...|
    pipe_expression: $ => seq(
      '◊',
      '|',
      /[^|]+/,
      '|',
    ),

    // Bare variable reference: ◊name (not followed by { or [)
    bare_variable_ref: $ => prec(-1, seq(
      '◊',
      field('name', $.tag_name),
    )),

    // Comments
    comment: $ => choice(
      $.line_comment,
      $.block_comment,
      $.expr_comment,
    ),

    line_comment: $ => seq(
      '◊',
      ';',
      /[^{(\n][^\n]*/,
      /\n/,
    ),

    block_comment: $ => seq(
      '◊',
      ';',
      '{',
      /[^}]*/,
      '}',
    ),

    expr_comment: $ => seq(
      '◊',
      ';',
      '(',
      optional($._racket_content),
      ')',
    ),
  },
});
