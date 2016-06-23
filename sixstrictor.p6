use v6;
use v6;

grammar Python::Core {
    sub indentfail($indent, $expected) {
        if $indent.size > $expected.size {
            die "Unexpected indent";
        }
        fail "Outdent";
    }
    sub debug($/, $msg) {
        say "$msg before {$/.postmatch.substr(0,10).subst("\n", "")}";
    }
    my $cur-ind = '';
    token ws { <!ww> [ "\\" \n | ' ' ]* }
    rule TOP {^[<statement> {$cur-ind eq ''}]* $}
    rule statement {[' '*\n]*:<set-indent>:{debug($/,"Before before")}<!before ' '>{debug($/,"Indent for new statement")}<statement-body> [\n|<before $>]}
    rule statement-body {<blocklike> |<expr> }
    rule blocklike {<blocklike-intro>{debug($/,"Block intro matched")} ':' \n{debug($/,"End of block intro matched")}<statement>{debug($/."First statement of block matched")}<continuing-statement>*}
    rule blocklike-intro {<function-intro>|<conditional-intro>|<class-intro>}
    rule conditional-intro {<conditional-keyword> [<expr> || {fail "$/<conditional-keyword> expr"}] }
    token conditional-keyword { 'if' | 'while' }
    rule function-intro { 'TODO' }
    rule class-intro { 'TODO' }
    rule continuing-statement {<?before <indent>\S{ $<indent> eq $cur-ind or indentfail($cur-ind) }>[<statement> || {fail "Statement parse failed" }]}
    rule expr { <term> } # TODO
    rule term { '(' <expr> ')' | <number> | <string> | <value-keyword> }
    token number { {debug($/, "match number?")} \d+ {debug($/,"Number $/ matched") } } # TODO
    regex string { <unicode-marker>? <raw-marker>? <quote> (.*?) <quote> {$<quote>[0] eq $<quote>[1] or fail} }
    token unicode-marker { 'u' }
    token raw-marker { 'r' }
    token quote { '"""' | "'''" | '"' | "'" }
    token value-keyword { 'True' | 'False' | 'None' }
    token set-indent { :our $cur-ind = <indent> }
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

plan(1);

my $python = '
if 1:
    True
    if 0:
        False
';

ok Python::Core.parse($python), "Parse python";

# vim: softtabstop=4 shiftwidth=4 expandtab ai filetype=perl6
