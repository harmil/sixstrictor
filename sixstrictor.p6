use v6;

grammar Python::Core {
    sub indentfail($indent, $expected) {
        if $indent.size > $expected.size {
            die "Unexpected indent";
        }
        fail "Outdent";
    }
    sub summary($s is copy, $max=10) {
        $s ~~ s:g/\n/\\n/;
        if $s.chars > $max-3 {
            $s.substr(0, $max-3) ~ '...';
        } else {
            $s;
        }
    }
    sub debug($/, $msg) {
        say "$msg reading '{summary($/.postmatch)}'";
    }
    my $cur-ind = Nil;
    my @ind-stack;
    sub set-ind($s) {
        !$cur-ind.defined or $s.chars != $cur-ind.chars or return False;
        @ind-stack.push($cur-ind);
        $cur-ind = $s;
        return True;
    }
    sub pop-ind {
        $cur-ind = @ind-stack.pop;
    }
    token ws { <!ww> [ "\\" \n | ' ' ]* | '#' <-[\n]>*: }
    rule TOP {^{debug($/,"moo")}[<statement> {$cur-ind eq ''}]* $}
    rule statement {[ \n]*<set-indent>:<statement-body> [\n|<before $>]}
    rule statement-body {<blocklike> |<expr> }
    rule blocklike {<blocklike-intro> ':': \n<statement><continuing-statement>*{pop-ind}}
    rule blocklike-intro {<function-intro>|<conditional-intro>|<class-intro>}
    rule conditional-intro {<conditional-keyword> [<expr> || {fail "$/<conditional-keyword> expr"}] }
    token conditional-keyword { 'if' | 'while' }
    rule function-intro { 'TODO' }
    rule class-intro { 'TODO' }
    rule continuing-statement {<indent>: <?{$<indent>.chars == $cur-ind.chars}>[<statement-body> || {fail "Statement parse failed" }]}
    rule expr { <term> } # TODO
    rule term { '(' <expr> ')' | <number> | <string> | <value-keyword> }
    token number { \d+ } # TODO
    regex string { <unicode-marker>? <raw-marker>? <quote> (.*?) <quote> {$<quote>[0] eq $<quote>[1] or fail} }
    token unicode-marker { 'u' }
    token raw-marker { 'r' }
    token quote { '"""' | "'''" | '"' | "'" }
    token value-keyword { 'True' | 'False' | 'None' }
    token set-indent { <after ^|\n> <indent> <?{set-ind $<indent>}> }
    token indent { ' '* }
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
    'indent cascade' => "if 1:\n    True\n    if 0:\n        False\n",
    'outdent' => "if 1:\n    True\n    if 0:\n        False\nTrue\n",
    'comment' => "True # Truth",
];

plan($code-examples.elems);

for |$code-examples -> $test {
    my $code = $test.value;
    my $name = $test.key;
    simple-parse($code, $name);
}

sub simple-parse($python, $msg) {
    ok Python::Core.parse($python), $msg;
}

# vim: softtabstop=4 shiftwidth=4 expandtab ai filetype=perl6
