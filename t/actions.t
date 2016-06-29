use v6;

use Test;

use Sixstrictor::Grammar;
use Sixstrictor::Grammar::Actions;

plan(1);

my $grammar = Sixstrictor::Grammar;
my $actions = Sixstrictor::Grammar::Actions;
ok $grammar.parse("1", :$actions), "Trivial file";


# vim: softtabstop=4 shiftwidth=4 expandtab ai filetype=perl6
