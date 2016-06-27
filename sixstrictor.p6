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

    token ws { <!ww> [ "\\" \n | ' ' ]* | ' '* '#' <-[\n]>*: }

    regex TOP {^
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
    rule blocklike-intro {<function-intro>|<conditional-intro>|<class-intro>}
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
    token variable { <ident>+% '.' }
    rule expr { <term> } # TODO
    rule term { '(' <expr> ')' | <number> | <string> | <value-keyword> }
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
];

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
