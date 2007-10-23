#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Builder;

my $tests;

BEGIN { $tests += 1 }
use_ok 'Object::Closures';

BAIL_OUT('module will not load!')
    if grep !$_, Test::Builder->new->summary;

BEGIN { plan tests => $tests }
