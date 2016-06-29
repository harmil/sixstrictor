use v6;

use Test;

use Sixstrictor::Grammar;
use Sixstrictor::Grammar::Actions;
use Sixstrictor::Grammar::AST;

plan(1);

my $grammar = Sixstrictor::Grammar;
my $actions = Sixstrictor::Grammar::Actions;
my $ast = $grammar.parse("1", :$actions).made;

ok $ast ~~ Sixstrictor::Grammar::AST, "type of ast";


# vim: softtabstop=4 shiftwidth=4 expandtab ai filetype=perl6
