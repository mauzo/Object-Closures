#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Builder;

my $t;

our $build = "foo";
our @build = qw/foo/;
our %build = (foo => "bar");

BEGIN { $t += 1 }
use_ok 'Object::Closures';

my (@keywords, @methods, @stubs, %protos);

BEGIN { 
    @keywords = qw{
        build compose
        method replace override before after
        self super
        construct inherit with
    };
    @methods = qw/AUTOLOAD can/;
    @stubs   = qw/isa DOES/;
    %protos  = (
        build   => "&",
        compose => "&",
    );
}

BEGIN { $t += @keywords }

for (@keywords) {
    no strict "refs";
    ok defined(&$_),    "keyword '$_' imported";
}

BEGIN { $t += @methods }

for (@methods) {
    no strict "refs";
    ok defined(&$_),    "method '$_' imported";
    
}

BEGIN { $t += @stubs * 2 }

for (@stubs) {
    no strict "refs";
    ok exists(&$_),     "method '$_' stubbed";
    ok !defined(&$_),   "...without definition";
}

BEGIN { $t += keys %protos }

for (keys %protos) {
    no strict "refs";
    is prototype(\&$_), $protos{$_},    "$_ has correct prototype";
}

Object::Closures->unimport;

BEGIN { $t += @methods + @stubs }

for (@methods) {
    no strict "refs";
    ok defined(&$_),    "unimport leaves method '$_'";
}

for (@stubs) {
    no strict "refs";
    ok exists(&$_),     "unimport leaves stub '$_'";
}

BEGIN { $t += @keywords }

for (@keywords) {
    no strict "refs";
    ok !defined(&$_),   "unimport removes keyword '$_'";
}

BEGIN { $t += 3 }

is $build,  "foo",      "SCALAR slot unaffected";
is $build[0], "foo",    "ARRAY slot unaffected";
is $build{foo}, "bar",  "HASH slot unaffected";

BAIL_OUT('module does not load correctly!')
    if grep !$_, Test::Builder->new->summary;

BEGIN { plan tests => $t }
