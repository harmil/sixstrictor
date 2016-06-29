# Sixstrictor: Python 2 in Perl 6

The sixstrictor project aims to produce a complete parser, internal
compiler and runtime for Python 2 (2.7, more specifically) in Perl6.

## FAQ

### Why Perl 6?

Perl 6 provides an incredibly powerful system for parsing text, as a
first-class language feature. This makes it quite attractive as a
platform for implementing any language.

### Why Python?

Python is a popular language and its relatively simple syntax makes it an
attractive target for implementation.

### Why Python 2?

Python 3 is both less commonly used (currently) and already the target
of a lower-level effort called "snake" which is using the Perl 6-like
virtual machine mini-language "NQP" to implement what will probably be
the performance-oriented Python in Perl 6. But there are advantages to
a pure-Perl implementation such as more trivial overriding and
reuse of parts of the grammar.

This project also aims to provide a migration path from Python 2 to
Perl 6 by allowing users to import their existing code and then
begin building around it in Perl 6.

## Status

As of this writing, the project is incomplete. The parser has
probably about 90% of the language now, but there is no compilation
to an internal AST yet ("actions" in the Perl 6 lingo) and there
is also no runtime.

To speed development, I may decide to compile to an intermediate form
that snake can understand and take advantage of their runtime. We
shall see...

