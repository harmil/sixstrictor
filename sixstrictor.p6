use v6;

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

    token ws { <!ww> [ "\\" \n | ' ' ]* | ' '* '#' <-[\n]>*: }

    regex TOP {^
        <blank>*:
        [
            <before \S><block> $ ||
            <before ' '> {
                debug($/, "TOP indent");fail "Unexpected indent"
            }]
    }
    regex block {
        <blank>* (<indent>||'') <statement>: <.ws>
        {debug($/,"First statement '{summary($<statement>)}'")}
        {} # For getting around <$0> bug
        [
            <blank>+
            <?{
                # Due to:
                #   bug #128492: <$0> does not work for empty match
                # we must do this manually, but once that bug is fixed,
                # this and the following <indent> can be removed and
                # replaced with <$0>
                my $next := $/.postmatch;
                my $ofrom = $0.from // 0;
                my $oto = $0.to // 0;
                my $len = $oto - $ofrom;
                my $orig := $0.orig || '';
                my $found := $next.substr(0,$len);
                my $template := $orig.substr($ofrom,$len);
                $found eq $template and (
                    $next.chars == $found.chars or
                        $next.substr($len,1) ne ' ');
            }><.indent>
            <statement>:
            {debug($/,"Secondary statement '{summary($<statement>[1])}'")}
        ]*
        <.ws> <.blank>*
    }
    rule statement {<blocklike> |<expr> <before \n|$>}
    rule blocklike {<blocklike-intro> ':': \n<block>}
    rule blocklike-intro {<function-intro>|<conditional-intro>|<class-intro>}
    regex conditional-intro {
        <conditional-keyword>
        <.ws>
        [<expr> || {fail err($/, 'conditional-keyword')}]
        <.ws>
    }
    token conditional-keyword { 'if' | 'while' }
    rule function-intro { 'TODO' }
    rule class-intro { 'TODO' }
    rule expr { <term> } # TODO
    rule term { '(' <expr> ')' | <number> | <string> | <value-keyword> }
    token number { \d+ } # TODO
    token string { <unicode-marker>? <raw-marker>? (<quote>): (.*?) <!after '\\'> {True} <$0> }
    token unicode-marker { 'u' }
    token raw-marker { 'r' }
    token quote { '"""' | "'''" | '"' | "'" }
    token value-keyword { 'True' | 'False' | 'None' }
    token indent { ' '* }
    rule blank { \n}
}

class Pyton::Ast {
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
    'outdent' => "if 1:\n    True\n    if 0:\n        False\nTrue\n",
    'comment' => "True # Truth",
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
