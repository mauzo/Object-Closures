#!/usr/bin/perl

use strict;
use warnings;

use t::Utils;

our (%BUILD, %COMPOSE);
*BUILD      = \%Object::Closures::BUILD;
*COMPOSE    = \%Object::Closures::COMPOSE;

my $t;

{
    BEGIN { $t += 4 }

    my $build;
    ok eval {
        package t::Class;
        use Object::Closures;
        build {
            $build++;
        };
        1;
    },                              "build succeeds";
    ok  $BUILD{"t::Class"},         "build sets \%BUILD";

    my $b = b $BUILD{"t::Class"};
    is $b->GV->NAME, "*BUILD*",     "*BUILD* correctly named";
    is $b->STASH->NAME, "t::Class", "*BUILD* in correct stash";

    BEGIN { $t += 4 }

    ok  !eval { 
        package t::Class; 
        use Object::Closures;
        build { 1 } ;
    },                              "build can't be called twice";
    like $@, qr/as a class/,        "...correct error";

    ok  !eval { 
        package t::Class; 
        use Object::Closures;
        compose { 1 }; 
    },                              "compose can't be called after build";
    like $@, qr/as a class/,        "...correct error";

    BEGIN { $t += 1 }

    $build = 0;
    my $obj = do { 
        package t::Class; 
        use Object::Closures;
        construct;
    };

    is  $build, 1,                  "construct calls *BUILD*";

    my @universal;
    BEGIN {
        @universal = (
            qw/AUTOLOAD DESTROY/,
            grep UNIVERSAL->can($_),
            keys %UNIVERSAL::,
        );
        $t += @universal * 2;
    }

    for (@universal) {
        my $can = $obj->can($_);
        ok $can,                        "object can ->$_";
        my $uni = UNIVERSAL->can($_);
        if ($_ eq "VERSION") {
            is $can, $uni,              "->$_ is from UNIVERSAL";
        }
        else {
            isnt $can, $uni,            "->$_ not from UNIVERSAL";
        }
    }

    BEGIN { $t += 4 }

    isa_ok  $obj, "t::Class";
    isa_ok  $obj, "UNIVERSAL";
    does_ok $obj, "t::Class";
    does_ok $obj, "UNIVERSAL";
}

{
    BEGIN { $t += 4 }

    my $compose;
    ok eval {
        package t::Role;
        use Object::Closures;
        compose {
           $compose++;
        };
        1;
    },                              "compose succeeds";
    ok  $COMPOSE{"t::Role"},        "compose sets \%COMPOSE";

    my $b = b $COMPOSE{"t::Role"};
    is $b->GV->NAME, "*COMPOSE*",   "*COMPOSE* correctly named";
    is $b->STASH->NAME, "t::Role",  "*COMPOSE* in correct stash";

    BEGIN { $t += 4 }

    ok  !eval { 
        package t::Role; 
        use Object::Closures;
        compose { 1 };
    },                              "compose can't be called twice";
    like $@, qr/as a role/,         "...correct error";

    ok  !eval { 
        package t::Role; 
        use Object::Closures;
        build { 1 };
    },                              "build can't be called after compose";
    like $@, qr/as a role/,         "...correct error";
}

BEGIN { plan tests => $t }
