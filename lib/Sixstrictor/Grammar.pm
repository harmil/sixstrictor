use v6;

#use Grammar::Tracer;

sub summary($s is copy, $max=20) {
    $s ~~ s:g/\n/\\n/;
    if $s.chars > $max-3 {
        $s.substr(0, $max-3) ~ '...';
    } else {
        $s;
    }
}

grammar Sixstrictor::Grammar {
    #sub debug($/, $msg) {
    #   say "$msg reading '{summary($/.postmatch)}'";
    #}

    sub err($/, $key) {
        "<$key>/{$/{$key}}: parse failure at '{summary($/.postmatch)}'";
    }

    sub do_match_on($/, $prev, &matcher) {
        # Due to:
        #   bug #128492: <$0> does not work for empty match
        # we must do this manually, but once that bug is fixed,
        # this and the following <indent> can be removed and
        # replaced with <$0>
        my $next := $/.postmatch;
        my $ofrom = $0.from // 0;
        my $oto = $0.to // 0;
        my $len = $oto - $ofrom;
        my $orig := $0.orig // '';
        my $found := $next.substr(0,$len);
        my $template := $orig.substr($ofrom,$len);
        matcher($found, $template, $len, $next);
    }

    # Whitespace is special in Perl6 rules. In "rule" delclarations,
    # all whitespace in the rule implicitly matches as <.ws> while
    # in regex and token declarations, whitepaces is simply ignored.
    #
    # Our <ws> has two modes: top and nest. Top mode matches
    # backslashed newlines, spaces and word-boundaries. It also
    # matches comments. But in nest mode it also matches newlines.
    # This gives us the Python behavior of allowing newlines in
    # statements as long as it's within matching backeting
    # tokens (e.g. parens, brackets, braces)
    our $space;

    token spacer { ' ' | <?{$space eq 'nest'}> \n }
    token ws { <!ww> [ "\\" \n | <spacer> ]* | ' '* '#' <-[\n]>*: }

    regex TOP {^
        :temp $space = 'top';
        #{ say "evaluating program:\n---\n{$/.orig}\n---" }
        <blank>*:
        [
            <before \S> <block> $ ||
            <before ' '> { fail "Unexpected indent" }
        ]
    }
    regex block {
        <.blank>* (<indent>||'') <statement>:
        [
            <.blank>* <after \n>
            <?{
                do_match_on($/, $0, -> $found, $template, $len, $next {
                    $found eq $template and (
                        $next.chars == $found.chars or
                            $next.substr($len,1) ne ' ');
                });
            }> <.indent>
            <statement>:
        ]*
        <.ws> <.blank>*
    }
    rule statement {<blocklike> |[<stmt-expr>|<special-stmt>] <before \n|$>}
    rule stmt-expr { <assignment> | <expr> }
    rule special-stmt { 'pass' | <print-stmt> }
    rule print-stmt { 'print' [ <expr> +% ',' ] (','?) }
    regex blocklike { <blocklike-intro> <.ws> ':' <.ws> \n <block> }
    regex blocklike-intro {
        <function-intro> | <conditional-intro> |
        <class-intro> | <for-intro>
    }
    rule for-intro {'for' <variable> 'in' <expr>}
    regex conditional-intro {
        <conditional-keyword>
        <.ws>
        [<expr> || {fail err($/, 'conditional-keyword')}]
        <.ws>
    }
    token conditional-keyword { 'if' | 'while' }
    rule function-intro {'def' <ident>'(' <function-signature> ')' }
    rule function-signature { <function-param> *% ',' }
    token function-param { <param-prefix><ident> | <ident> <param-default>? }
    token param-default { '=' <.ws> <expr> }
    rule class-intro { 'class' <ident>['(' <class-signature> ')']? }
    rule class-signature { <variable> +% ',' }
    rule assignment { [ <target-list> '=' ]+ <expression-list> }
    rule target-list { <target> *% ',' ','? }
    rule target {
        <variable><sliceish>? |
        '(' ~ ')' <nest-target-list> |
        '[' ~ ']' <nest-target-list>
    }
    rule nest-target-list { :temp $space = 'nest'; <target-list> }
    rule expression-list { <expr> +% ',' }
    rule expr { <expr12> | <lambda> }
    rule expr12 { <expr11> +% 'or' }
    rule expr11 { <expr10> +% 'and' }
    rule expr10 { ('not' )* <expr09> }
    rule expr09 { <expr08> +% <op09> }
    token op09 {
        '==' | '!=' | '>' '='? | '<' '='? | 'is'[<.ws>'not']? |
        ['not'<.ws>]? 'in'
    }
    rule expr08 { <expr07> +% '|' }
    rule expr07 { <expr06> +% '^' }
    rule expr06 { <expr05> +% '&' }
    rule expr05 { <expr04> +% <op05> }
    token op05 { '<<' | '>>' }
    rule expr04 { <expr03> +% <op04> }
    token op04 { '+' | '-' }
    rule expr03 { <expr02> +% <op03> }
    token op03 { '*' | '/' '/'? | '%' }
    rule expr02 { <op02>* <expr01> }
    token op02 { '+' | '-' | '~' }
    rule expr01 { <expr00> +% '**' }
    rule expr00 { <term><postfix-operation>* }
    rule term {
        '(' <nest-expr> ')' | <variable> | <literal>
    }
    rule nest-expr {
        :temp $space = 'nest'; <expr>
    }
    rule literal {
        <number> | <string> | <value-keyword> | <collection>
    }
    regex postfix-operation { <invocation> | <sliceish> }
    regex invocation {'(' <invocation-parameters> ')'}
    rule invocation-parameters {
        :temp $space = 'nest';
        <invocation-parameter> *% ','
    }
    rule invocation-parameter {
        <param-prefix>?<expr> |
        <ident>'=' <expr>
    }
    token param-prefix { '*' | '**' }
    rule sliceish {'[' ~ ']' <slice-expr>}
    rule slice-expr { <nest-expr> [ ':': <nest-expr> ]? }
    rule collection { <literal-list> | <literal-dict-set> | <literal-tuple> }
    rule literal-list { '[' ~ ']' ( <nest-expr> *% ',' ','?) }
    rule literal-dict-set { '{' ~ '}' <dict-set-items> }
    rule literal-tuple { '(' ~ ')' ( <nest-expr> *% ',' ','?) }
    rule dict-set-items { <dict-set-item> *% ',' }
    rule dict-set-item { <nest-expr> ( ':' <nest-expr> )? }
    rule lambda { 'lambda' <function-param> *% ',' ':' <expr12> }
    token variable { <ident>+% '.' }
    token number { <literal-integer> | <literal-float> | <literal-imaginary> }
    token literal-integer {
        [
            <binary-integer> |
            <octal-integer> |
            <decimal-integer> |
            <hexidecimal-integer>
        ] <longsuffix>?
    }
    token binary-integer { '0' <[bB]> <[0..1]>+ }
    token octal-integer { '0' <[oO]>? <[0..7]>+ }
    token decimal-integer { '0' | <!before '0'> <[0..9]>+ }
    token hexidecimal-integer { '0' <[xX]> <[0..9]+[a..f]+[A..F]>+ }
    token longsuffix { 'l' | 'L' }
    token literal-float { <point-float> | <exponent-float> }
    token point-float {
        <float-intpart>? '.' <float-intpart> | <float-intpart> '.'
    }
    token float-intpart { <[0..9]>+ }
    token exponent-float { [ <float-intpart> | <point-float> ] <exponent> }
    token exponent { (<[eE]>) (<[+-]>)? <float-intpart> }
    token literal-imaginary { [<literal-float> | <float-intpart>] <[jJ]> }

    regex string {
        <unicode-marker>?
        <raw-marker>?
        # TODO Other markers
        <quote>
        [ '\\' . | <-[\\]> ]*?
        <quote>
        <?{~$<quote>[0] eq ~$<quote>[1] }>
    }
    token unicode-marker { 'u' }
    token raw-marker { 'r' }
    regex quote { '"""' | "'''" | '"' | "'" }
    token value-keyword { 'True' | 'False' | 'None' }
    token indent { ' '* }
    rule blank { \n}
}
