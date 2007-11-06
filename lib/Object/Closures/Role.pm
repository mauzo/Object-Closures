package Object::Closures::Role;

use warnings;
use strict;

use Carp ();

sub import {
    my $pkg = caller;
    my (@does, @reqd, %pvde);
    my %exports = (
        requires => sub { push @reqd, @_; },
        provides => sub { $pvde{$_[0]} = $_[1]; },
        does     => sub { push @does, @_; },
        apply    => sub {
            my ($self, $to) = @_;
            for (@does) {
                $to->DOES($self) or $_->apply($to);
            }
            for (@reqd) {
                $to->{$_} or Carp::croak qq{$self requires method "$_"};
            }
            for (keys %pvde) {
                $to->{$_} ||= $pvde{$_};
            }
            $to->{DOES}{$self} = 1;
        },
        DOES     => sub { 
            ! ! grep { $_ eq $_[1] } __PACKAGE__, $_[0], @does;
        },
    );
    {
        no strict 'refs';
        @{"$pkg\::ISA"} = __PACKAGE__;
        for (keys %exports) {
            *{"$pkg\::$_"} = $exports{$_};
        }
    }

    warnings->import;
    strict->import;
}

1;
