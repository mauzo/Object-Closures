#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Object::Closures;
#use Data::Dump          qw/dump/;

BEGIN {
    package t::Object;

    our @ISA = qw/Object::Closures/;

    sub new {
        my ($class, $name) = @_;
        return $class->SUPER::new(
            scal => $name,
            list => [$name, $name, "foo-$name"],
            ref  => \$name,
            code => sub { $name . $_[1] },
            hash => {
                scal => $name,
                code => sub { $name . $_[1] },
            },
        );
    }
}

my $tests;

my $obj = t::Object->new('foo');

BEGIN { $tests += 6 }

isa_ok  $obj,       't::Object',            'object';
isa_ok  $obj,       'Object::Closures',     '...and';
can_ok  $obj,       'scal';
can_ok  $obj,       'clone';
ok      $obj->isa('t::Object'),             '...and ->isa works';
ok      $obj->isa('Object::Closures'),      '...correctly';

BEGIN { $tests += 7 }

is      $obj->scal,             'foo',          'scalar meth';
is      $obj->list,             'foo',          'array meth, scalar ctx';
is      +($obj->list)[1],       'foo-foo',      'array meth, list ctx';
is      $obj->ref,              'foo',          'ref meth';
is      $obj->code('bar'),      'foobar',       'code meth';
is      $obj->hash('scal'),     'foo',          'hash/scalar meth';
is      $obj->hash(code => 'bar'),  'foobar',   'hash/code meth';

$obj->_methods(
    foo     => 'bar',
    '+code' => 'code',
    '+plus'  => 'plus',
    -scal   => 'scal',
    -none   => 'none',
    hash    => {
        baz => 'quux',
    },
);

BEGIN { $tests += 9 }

ok      $obj->can('foo'),                       'added method';
is      eval {$obj->foo },      'bar',          '...correctly';
ok      $obj->can('plus'),                      'added +method';
is      eval { $obj->plus },    'plus',         '...correctly';
is      $obj->code(''),         'foo',          'ignored +method';
is      $obj->scal,             'scal',         'replaced -method';
ok      !$obj->can('none'),                     'ignored -method';
is      $obj->hash('scal'),     'foo',          'hash meth still there';
is      $obj->hash('baz'),      'quux',         'new hash meth';

BEGIN {
    package t::Number;

    our @ISA = qw/Object::Closures/;

    sub new {
        my ($class, $num) = @_;
        return $class->SUPER::new(
            value => sub { $num },
            inc   => sub { $_[0]->clone(sub { $num++ }) },
        );
    }
}

my $num = t::Number->new(4);
my $inc = $num->inc;

BEGIN { $tests += 3 }

isnt    $inc,               $num,       'cloned, not copied';
is      $inc->value,        5,          'new value changed';
is      $num->value,        4,          'old value kept';


BEGIN { plan tests => $tests }
