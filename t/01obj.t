#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Object::Closures;

BEGIN {
    package t::Object;

    use Object::Closures;

    BEGIN { our @method = "xxx" }

    sub new { construct(@_) }

    build {
        my ($name) = @_;

        inherit 'Object::Closures';

        method scal => $name;
        method ref  => \$name;
        method code => sub { $name . $_[0] };
        method hash => {
            scal => $name,
            code => sub { $name . $_[0] },
        };
        method self => sub { self };

        method allchange => sub {
            method  foo  => 'bar';
            default code => 'code';
            default plus => 'plus';
            replace scal => 'scal';
            replace none => 'none';
            method  hash => baz => 'quux';
        };
            
    };
}

my $tests;

my $obj = t::Object->new('foo');

BEGIN { $tests += 2 }

ok      !defined &t::Object::method,        'keywords removed';
is      $t::Object::method[0],  'xxx',      '...leaving other types';

BEGIN { $tests += 6 }

isa_ok  $obj,       't::Object',            'object';
isa_ok  $obj,       'Object::Closures',     '...and';
can_ok  $obj,       'scal';
can_ok  $obj,       'clone';
ok      $obj->isa('t::Object'),             '...and ->isa works';
ok      $obj->isa('Object::Closures'),      '...correctly';

BEGIN { $tests += 6 }

is      $obj->scal,             'foo',          'scalar meth';
is      $obj->ref,              'foo',          'ref meth';
is      $obj->code('bar'),      'foobar',       'code meth';
is      $obj->hash('scal'),     'foo',          'hash/scalar meth';
is      $obj->hash(code => 'bar'),  'foobar',   'hash/code meth';
is      $obj->self,             $obj,           'self';

diag 'all change';
$obj->allchange;

BEGIN { $tests += 9 }

ok      $obj->can('foo'),                       'added method';
is      eval {$obj->foo },      'bar',          '...correctly';
ok      $obj->can('plus'),                      'default applied';
is      eval { $obj->plus },    'plus',         '...correctly';
is      $obj->code(''),         'foo',          'default ignored';
is      $obj->scal,             'scal',         'replaced method';
ok      !$obj->can('none'),                     'replacement ignored';
is      $obj->hash('scal'),     'foo',          'hash meth still there';
is      $obj->hash('baz'),      'quux',         'new hash meth';

BEGIN {
    package t::Number;

    use Object::Closures;

    sub new { construct(@_) }

    build {
        my ($num) = @_;

        inherit 'Object::Closures';

        method value => sub { $num };
        method inc   => sub { self->clone(sub { $num++ }) };
    };
}

my $num = t::Number->new(4);
my $inc = $num->inc;

BEGIN { $tests += 3 }

isnt    $inc,               $num,       'cloned, not copied';
is      $num->value,        4,          'old value kept';
is      $inc->value,        5,          'new value changed';


BEGIN { plan tests => $tests }
