#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Object::Closures;
use Scalar::Util        qw/blessed/;
use Data::Dump          qw/dump/;

BEGIN {
    package t::Object;

    use Object::Closures;

    BEGIN { our @method = "xxx" }

    method new => sub { construct(@_) };

    build {
        my ($name) = @_;

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
            replace scal => 'scal';
            replace none => "none";
            method  hash => baz => 'quux';
            method  hash => cluck => sub { Carp::cluck("woohoo") };
        };
            
    };
}

my $tests;

diag "CLASS: " . dump \%Object::Closures::CLASS;
diag "BUILD: " . dump \%Object::Closures::BUILD;

my $obj = t::Object->new('foo');

BEGIN { $tests += 2 }

ok      !defined &t::Object::method,        'keywords removed';
is      $t::Object::method[0],  'xxx',      '...leaving other types';

BEGIN { $tests += 4 }

is      blessed($obj),  "t::Object",        "object in the correct class";
isa_ok  $obj,       't::Object',            'object';
ok      !$obj->isa("Object::Closures"),     '...isn\'ta Object::Closures';
can_ok  $obj,       'scal';

BEGIN { $tests += 6 }

is      $obj->scal,             'foo',          'scalar meth';
is      $obj->ref,              'foo',          'ref meth';
is      $obj->code('bar'),      'foobar',       'code meth';
is      $obj->hash('scal'),     'foo',          'hash/scalar meth';
is      $obj->hash(code => 'bar'),  'foobar',   'hash/code meth';
is      $obj->self,             $obj,           'self';

diag 'all change';
$obj->allchange;
$obj->hash("cluck");

BEGIN { $tests += 6 }

ok      $obj->can('foo'),                       'added method';
is      eval {$obj->foo },      'bar',          '...correctly';
is      $obj->scal,             'scal',         'replaced method';
ok      !$obj->can('none'),                     'replacement ignored';
is      $obj->hash('scal'),     'foo',          'hash meth still there';
is      $obj->hash('baz'),      'quux',         'new hash meth';

BEGIN {
    package t::Number;

    use Object::Closures;

    method new => sub { construct(@_) };

    build {
        my ($num) = @_;

        method clone => sub { Object::Closures::clone(self, @_) };
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
