use v6;

use Sixstrictor::Grammar::AST;

# Just a short alias
our $AST := ::Sixstrictor::Grammar::AST;

class Sixstrictor::Grammar::Actions {
    method TOP($/) { make $AST.new() } # TODO
}


# vim: softtabstop=4 shiftwidth=4 expandtab ai filetype=perl6
