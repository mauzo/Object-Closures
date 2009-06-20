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
use_ok 'Object::Closures'
    or BAIL_OUT "module will not load!";

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

my @all = (@keywords, @methods, @stubs);

my %imports;

eval q{ # {}
    package t::Test;

    our $VERSION = "1.0";

    use Object::Closures;
    no strict "refs";

    BEGIN {
        for (@all) {
            $imports{$_}{compile}   = defined &$_;
            $imports{$_}{proto}     = prototype \&$_;
        }
    }

    for (@all) {
        my $cv = t::Test->UNIVERSAL::can($_);
        $imports{$_}{stub}  = $cv;
    }
};

BEGIN { $t += @keywords * 2 }

for (@keywords) {
    ok  $imports{$_}{compile},      "keyword $_ visible at compile time";
    ok !$imports{$_}{run},          "keyword $_ not visible at runtime";
}

BEGIN { $t += @methods * 2 }

for (@methods) {
    my $cv = $imports{$_}{stub};
    ok   $cv,                       "method $_ visible at runtime";
    isnt $cv, UNIVERSAL->can($_),   "method $_ not from UNIVERSAL";
}

BEGIN { $t += @stubs * 3 }

for (@stubs) {
    my $cv = $imports{$_}{stub};
    ok   $cv,                       "method $_ visible at runtime";
    isnt $cv, UNIVERSAL->can($_),   "method $_ not from UNIVERSAL";
    ok  !defined(&$cv),             "method $_ is stubbed";
}

BEGIN { $t += 3 }

my $cv = t::Test->can("VERSION");
ok $cv,                             "->VERSION still visible";
is $cv, UNIVERSAL->can("VERSION"),  "->VERSION still from UNIVERSAL";
is t::Test->VERSION, "1.0",         "->VERSION still works";

BEGIN { $t += keys %protos }

for (keys %protos) {
    is $imports{$_}{proto}, $protos{$_},    "correct prototype for $_";
}

BAIL_OUT('module does not load correctly!')
    if grep !$_, Test::Builder->new->summary;

BEGIN { plan tests => $t }
