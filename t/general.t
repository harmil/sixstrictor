use v6;

use Test;

use Sixstrictor::Grammar;

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
    'trivial-integer' => '10',
    'integers' => '(1, 01, 0b1, 0xa9b2, 100L)',
    'trivial-float' => '1.0',
    'floats' => '(10.0, 10., .1, 1e10, 10.0e-10, 0e0)',
    'imaginaries' => '(1.0j, 1.j, 1j, .1j, 1e10j, 1.1e-10j)',
    'trivial-imaginary' => '1j',
    'trivial-assignment' => 'a = b',
    'list-assignment' => 'a,b,c = 1,2,3',
    'index' => 'a[10]',
    'dict-index' => 'a["pie"]',
    'slice' => 'a[0:10]',
    'slice-assign' => 'a[0:10] = "pie"',
    'slice-newline' => "a[\n0 :\n10]",
    'multi-line-string' => "'this\nis\na\nstring'",
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
    simple-parse($code, $name);
}

sub simple-parse($python, $msg) {
    ok Sixstrictor::Grammar.parse($python), $msg;
}

# vim: softtabstop=4 shiftwidth=4 expandtab ai filetype=perl6
