package Object::Closures;

=head1 NAME

Object::Closures - Classless objects built out of closures

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

our $VERSION = '0.00';
$VERSION = eval $VERSION;

our $AUTOLOAD;

use strict ();
use warnings ();
use Clone::Closure ();

sub import {
    my $pkg = caller;
    push @{"$pkg\::ISA"}, __PACKAGE__;
    strict->import;
    warnings->import;
    goto &Object::Closures::Util::import;
}

# we must create stubs here, as AUTOLOAD is here and doesn't (or
# shouldn't) inherit past a stub. They don't cause problems, as anything
# we inherit or implement doesn't get stubbed.
sub can {
    my ($self, $meth) = @_;
    my $code = $self->UNIVERSAL::can($meth);
    $code and return $code;
    ref $self or return;
    exists $self->{$meth} and return \&$meth;
}

sub clone {
    my ($old, $cbk) = @_;

    # we must clone both in one operation
    my $new = Clone::Closure::clone [$old, $cbk];
    ($new, $cbk) = @$new;

    $cbk and $cbk->($new);
    return $new;
}

# we use another package so as not to create any false methods

package Object::Closures::Util;

use strict;
use warnings;

use Carp                    qw/croak/;
use Clone::Closure          ();
use Scalar::Util            qw/reftype blessed/;
use Hash::Util::FieldHash   qw/fieldhash/;
use Symbol                  qw/gensym/;

my @KEYWORDS;

sub import {
    my $to = caller;

    no strict 'refs';
    *{"$to\::$_"} = \&$_ for @KEYWORDS;
}

sub unimport {
    my $from = caller;

    for (@KEYWORDS) {
        no strict 'refs';
        no warnings 'misc';

        my $old = "$from\::$_";

        if (*$old{CODE} == \&$_) {
            # we have to copy each piece individually
            my $new = gensym;
            *$new = *$old{SCALAR};
            *$new = *$old{ARRAY};
            *$new = *$old{HASH};
            *$new = *$old{IO};
            *$new = *$old{FORMAT};
            delete ${"$from\::"}{$_};
            *$old = $new;
        }
    }
}

push @KEYWORDS, qw/inherit with self/;

our $SELF;
sub self { $SELF }

sub inherit {
    my $from = shift;

    $COMPOSE{$from}
        and croak "$from is a role, use 'with' instead of 'inherit'"

    method isa => $from => 1;
    $BUILD{$from} and $BUILD{$from}->(@_);
}

sub with {
    my ($role) = @_;
    replace DOES => $role => 1;
    $COMPOSE{$role} and $COMPOSE{$role}->(@_);
}

sub invoke {
    my ($name, $entry, $args) = @_;

    blessed $entry and return $entry->$name(@$args);

    for (reftype $entry) {
        #warn "# got a $_ entry for $name";
        defined or last;
        /CODE/              and do {
            @_ = @$args;
            goto &$entry;
        };
        /SCALAR/ || /REF/   and return $$entry;
        /ARRAY/             and do {
            my ($before, $meth, $after) = @$entry;
            my ($rv, @rv);

            $_->(@$args) for @$before;

            wantarray
                ? @rv = invoke $name, $meth, $args
                : defined wantarray
                    ? $rv = invoke $name, $meth, $args
                    : invoke $name, $meth, $args;
            
            $_->(@$args) for @$after;

            return wantarray
                ? @rv : defined wantarray
                    ? $rv : ();
        };
        /HASH/              and do {
            @$args or croak "Missing argument for '$name'";
            my $key  = shift @$args;
            my $meth = $entry->{$key} or return;
            @_ = ($key, $meth, $args);
            goto &invoke;
        };

    }
    return $entry;
}

# our means that we get the correct $AUTOLOAD
sub Object::Closures::AUTOLOAD {
    $AUTOLOAD =~ s/.*:://;
    local $SELF = shift;
    exists $SELF->{$AUTOLOAD}
        or croak "No such method '$AUTOLOAD'";
    invoke $AUTOLOAD, $SELF->{$AUTOLOAD}, \@_;
}

my (%BUILD, %COMPOSE);

push @KEYWORDS, qw/build construct compose clone/;

# XXX
sub construct {
    my $class = shift;
    local $SELF = bless {}, $class;
    $BUILD{$class}(@_);
    return self;
}

sub build (&) {
    my $class = caller;

    $COMPOSE{$class}
        and croak "$class is already defined as a role";
    $BUILD{$class} = shift;

    goto &unimport;
}

sub compose (&) {
    my $role = caller;

    $BUILD{$role}
        and croak "$role is already defined as a class";
    $COMPOSE{$role} = shift;

    goto &unimport;
}

sub clone { self->clone(@_) }

push @KEYWORDS, qw/super/;

our $SUPER;
sub super { $SUPER->(@_) }

my @EDITS = qw/method replace default before after around/;
push @KEYWORDS, @EDITS;

sub parse_change {
    my $create = shift;
    my $entry  = pop;
    my $name   = pop;
    my $method;
    my $table  = self
        or croak "No object in scope";

    for (@_) {
        unless (exists $table->{$_}) {
            $create or croak $method
                ? "Method '$method' does not have key '$_'"
                : "Method '$_' is not defined";

            $table->{$_} = {};
        }

        $table = $table->{$_};

        reftype $table eq 'HASH'
            or croak "Not a HASH reference";

        $method ||= $_;
    }

    my $ex = exists $table->{$name};
}    

for my $sub (@EDITS) {
    no strict 'refs';
    *$sub = sub {
        use strict 'refs';

        my $entry = pop;
        my $name  = pop;
        my $table = self 
            or croak "No object to apply '$sub' to";

        my $want = 
            $sub eq 'around' || 
            $sub eq 'before' || 
            $sub eq 'after';

        $sub eq 'method' and $ex
            and croak "Method '$name' already exists";

        $sub eq 'default' and $ex and return;

        if ($want) {
            $ex or croak "Method '$name' not defined";
            my $new = $entry;
            my $old = $table->{$name};
            
            if ($sub eq 'around') {
                $entry  = sub {
                    local $SUPER = $old;
                    invoke $name, $new, \@_;
                };
            }
            else {
                $entry = [[], 
        }

        $table->{$name} = $entry;
    };
}

1;

__END__

=head1 BUGS

=head1 AUTHOR

Copyright 2007 Ben Morrow, <ben@morrow.me.uk>.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Class::Classless|Class::Classless>

=cut
