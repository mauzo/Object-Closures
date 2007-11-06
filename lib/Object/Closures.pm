package Object::Closures;

=head1 NAME

Object::Closures - Classless objects built out of closures

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

our $VERSION = '0.00';
$VERSION = eval $VERSION;

our $AUTOLOAD;

# we use another package so as not to create any false methods

package Object::Closures::Util;

use strict;
use warnings;

use Carp            qw/croak/;
use Clone::Closure  qw/clone/;
use Scalar::Util    qw/reftype blessed/;

# our means that we get the correct $AUTOLOAD

sub Object::Closures::AUTOLOAD {
    $AUTOLOAD =~ s/.*:://;
    my $meth = $_[0]->can($AUTOLOAD)
        or croak qq{Can't locate method "$AUTOLOAD" for $_[0]};
    goto &$meth;
}

sub Object::Closures::DESTROY {
    my $d = $_[0]->{DESTROY};
    $d and $_[0]->$d;
}

sub Object::Closures::new {
    my $class = shift;
    return bless { @_ }, $class;
}

sub Object::Closures::clone {
    my ($old, $cbk) = @_;

    # we must clone both in one operation
    my $new = clone [$old, $cbk];
    ($new, $cbk) = @$new;

    $cbk and $cbk->($new);
    return $new;
}

sub do_can;
sub do_can {
    my ($table, $meth) = @_;
    my $entry = $table->{$meth};

    $entry or return;
    blessed $entry and return sub { $entry->$meth(@_) };

    for (reftype $entry) {
        defined or last;
        /CODE/              and return $entry;
        /SCALAR/ || /REF/   and return sub { $$entry };
        /ARRAY/             and return sub {
            defined wantarray or return;
            my @list   = @$entry;
            my $scalar = shift @list;
            return wantarray ? @list : $scalar;
        };
        /HASH/              and return sub {
            @_ >= 2 or croak "Missing argument to '$meth'";
            my $self = shift;
            my $key  = shift;
            do_can($entry, $key)->($self, @_);
        };
    }
    return sub { $entry };
};

sub Object::Closures::can {
    my ($self, $meth) = @_;
    my $code = $self->UNIVERSAL::can($meth);
    $code and return $code;
    goto &do_can;
}

sub do_methods;
sub do_methods {
    my ($old, $table) = @_;

    for (keys %$table) {
        my ($t, $m) = /^(\W?)(\w+)$/
            or croak "invalid method name '$_'";
        my $new = $table->{$_};

        ref $new and ref $old->{$m}
            and reftype $new eq 'HASH'
            and reftype $old->{$m} eq 'HASH'
            and do {
                do_methods $old->{$m}, $new;
                next;
            };

        if (!defined $t or $t eq '') {
            exists $old->{$m}
                and croak "Method '$m' already exists";
            $old->{$m} = $new;
        }
        elsif ($t eq '+') {
            $old->{$m} ||= $new;
        }
        elsif ($t eq '-') {
            $old->{$m} &&= $new;
        }
        else {
            croak "invalid method name '$_'";
        }
    }
};

sub Object::Closures::_methods {
    my ($self, %meths) = @_;
    do_methods $self, \%meths;
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
