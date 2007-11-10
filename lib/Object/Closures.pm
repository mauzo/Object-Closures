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
# we inherit doesn't get stubbed.
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

push @KEYWORDS, qw/inherit self super/;

# XXX now called from build: needs to call parent's build and set
# self->{isa}
sub inherit {
    my $caller = caller;
    no strict 'refs';
    push @{"$caller\::ISA"}, @_;
}

our $SELF;
sub self { $SELF }

# our means that we get the correct $AUTOLOAD
sub Object::Closures::AUTOLOAD {
    $AUTOLOAD =~ s/.*:://;
    local $SELF = $_[0];
    # can't goto & or we lose the local
    &do_auto;
}

sub do_auto {
    my $table = shift;
    my $entry = $table->{$AUTOLOAD};

    unless (defined $entry) {
        my $type = \$table == \$SELF ? 'method' : 'key';
        croak "No such $type '$AUTOLOAD'";
    }

    blessed $entry and return $entry->$AUTOLOAD(@_);

    for (reftype $entry) {
        #warn "# got a $_ entry for $AUTOLOAD";
        defined or last;
        /CODE/              and goto &$entry;
        /SCALAR/ || /REF/   and return $$entry;
        /ARRAY/             and do {
            defined wantarray or return;
            return wantarray ? @{$entry}[1..$#$entry] : ${$entry}[0];
        };
        /HASH/              and do {
            @_ or croak "Missing argument for '$AUTOLOAD'";
            $AUTOLOAD = splice @_, 0, 1, $entry;
            goto &do_auto;
        };

    }
    return $entry;
}

my (%BUILD, %DEMOLISH);

push @KEYWORDS, qw/build clone demolish/;

sub Object::Closures::new {
    my $class = shift;
    local $SELF = bless {}, $class;
    $BUILD{$class}(@_);
    return self;
}

sub build (&) {
    my ($build) = @_;
    my $class   = caller;
    $BUILD{$class} = $build;
    goto &unimport;
}

sub clone { self->clone(@_) }

my @EDITS = qw(method default replace override);
push @KEYWORDS, @EDITS;

for my $sub (@EDITS) {
    no strict 'refs';
    *$sub = sub {
        my $entry = pop;
        my $name  = pop;
        my $table = self 
            or croak "No object to apply '$sub' to";

        for (@_) {
            unless (exists $table->{$_}) {
                $sub eq 'replace' and croak "Key '$_' doesn't exist";
                $table->{$_} = {};
            }

            $table = $table->{$_};

            reftype $table eq 'HASH'
                or croak "Not a HASH reference";
        }

        {
            $sub eq 'override' and last;
            my $ex = exists $table->{$name};
            #warn "# $name does " . ($ex ? '' : 'not ') . "exist";
            $sub eq 'replace' and $ex = !$ex;
            $ex or last;

            $sub eq 'method' and croak "Method '$name' already exists";
            return;
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
