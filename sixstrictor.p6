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

grammar Python::Core {
    sub debug($/, $msg) {
        say "$msg reading '{summary($/.postmatch)}'";
    }

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

    our $space;

    token spacer { ' ' | <?{$space eq 'nest'}> \n }

    token ws { <!ww> [ "\\" \n | <spacer> ]* | ' '* '#' <-[\n]>*: }

    regex TOP {^
        :temp $space = 'top';
        #{ say "evaluating program:\n---\n{$/.orig}\n---" }
        <blank>*:
        [
            <before \S> <block> $ ||
            <before ' '>
            # { debug($/, "TOP indent");fail "Unexpected indent" }
        ]
    }
    regex block {
        <.blank>* (<indent>||'') <statement>:
        #{debug($/,"Block starts '{summary($<statement>)}'")}
        {} # For getting around <$0> bug
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
            #{debug($/,"Block continues '{summary($<statement>[1])}'")}
        ]*
        <.ws> <.blank>*
    }
    rule statement {<blocklike> |[<expr>|<special-stmt>] <before \n|$>}
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
    token function-param {
        [ '*' ** {1..2} ] <ident> | <ident> <param-default>?
    }
    token param-default { '=' <.ws> <expr> }
    rule class-intro { 'class' <ident>['(' <class-signature> ')']? }
    rule class-signature { <variable> +% ',' }
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
    rule expr00 { <term>['(' <invocation-parameters> ')']? }
    rule term {
        '(' <nest-expr> ')' | <variable> | <literal>
    }
    rule nest-expr {
        :temp $space = 'nest'; <expr>
    }
    rule literal {
        <number> | <string> | <value-keyword> | <collection>
    }
    rule invocation-parameters { <invocation-parameter> *% ',' }
    rule invocation-parameter {
        (['*'**{1..2}]?)<nest-expr> |
        <ident>'=' <nest-expr>
    }
    rule collection { <literal-list> | <literal-dict-set> | <literal-tuple> }
    rule literal-list { '[' ~ ']' ( <nest-expr> *% ',' ','?) }
    rule literal-dict-set { '{' ~ '}' <dict-set-items> }
    rule literal-tuple { '(' ~ ')' ( <nest-expr> *% ',' ','?) }
    rule dict-set-items { <dict-set-item> *% ',' }
    rule dict-set-item { <nest-expr> ( ':' <nest-expr> )? }
    rule lambda { 'lambda' <function-param> *% ',' ':' <expr12> }
    token variable { <ident>+% '.' }
    token number { \d+ } # TODO

    regex string {
        <unicode-marker>?
        <raw-marker>?
        <quote>
        #{debug($/, "Started quote")}
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

class Python::Ast {
    has $.type;
    has $.node;
    has $.children
}

sub ast(:$type, :$node = Nil, :$children = []) { Python::Ast.new(:$type, :$node, :$children) }

class Python::Core::Actions {
    method TOP { make ast(:type<top>, :children($<statement>>>.made)) }
}

use Test;

my $code-examples = [
    'simple statement' => "True",
    'indent cascade' => "if 1:\n    True\n    if 0:\n        False\n",
    'outdent' => "if 1:\n    True\n    if 0:\n        False\n3\n",
    'comment' => "True # Truth",
    'quotes' => qq{'''a'''\n"""b"""\n'c'\n"d"\n},
    'function' => "def foo(a, b, c=1, **kwargs):\n    True\n",
    'basic_class' => "class A:\n    pass\n",
    'meaty_class' => "class A(object):\n    def foo(self, i):\n        pass",
    'expr' => '10 * 3**4 + 20 - ( 5//3 ^ 6 )',
    'lambda' => 'lambda x,y: x+y',
    'list' => '[ 1, 2, 1+2, [4, 5], ]',
    'dict' => '{ "a": 1, "b": 2, "c": 3 }',
    'set' => '{ 1, 2, 3, 4, 5 }',
    'function-call' => qq{def foo(a,b,c):\n     pass\nfoo(1,b=2,**{'c':3})\n},
    'newline-in-expr' => qq{if (\n1):\n    pass\n},
];

if @*ARGS {
    my %ex = |$code-examples;
    my @todo;
    for @*ARGS -> $name {
        if %ex{$name}:exists {
            @todo.push: $name => %ex{$name};
        } else {
            die "No such test '$name'";
        }
    }
    $code-examples := @todo;
}
plan($code-examples.elems);

for |$code-examples -> $test {
    my $code = $test.value;
    my $name = $test.key;
    #say "Test '$name': {summary($code)}";
    simple-parse($code, $name);
}

sub simple-parse($python, $msg) {
    ok Python::Core.parse($python), $msg;
}

# vim: softtabstop=4 shiftwidth=4 expandtab ai filetype=perl6
