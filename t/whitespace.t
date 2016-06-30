use v6;

use Test;

use Sixstrictor::Grammar;

plan(4);

$Sixstrictor::Grammar::space = 'top';


for |("a\t", 7), |("\ta\t\t", 8), |("a\ta\t", 7) -> $s,$t {
    my $expanded = Sixstrictor::Grammar::expand-tab($s);
    ok $expanded eq (' ' x $t), "{$s.perl} tab-expansion";
}

ok "\t\f " ~~ /^<Sixstrictor::Grammar::ws>$/, "whitespace = tab, ff, space";

# vim: softtabstop=4 shiftwidth=4 expandtab ai filetype=perl6
