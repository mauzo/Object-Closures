package Object::Closures;

=head1 NAME

Object::Closures - Classless objects built out of closures

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use version; our $VERSION = '0.00';

use strict;
use warnings;

use Carp                    qw/carp croak/;
use Scalar::Util            qw/reftype blessed/;
use Symbol                  qw/gensym/;
use Sub::Name               qw/subname/;
use Sub::Identify           qw/stash_name/;
use namespace::clean        ();
use Data::Dump              qw/dump/;

our (%BUILD, %COMPOSE, %CLASS);
our ($SELF, @SUPER);
my  @KEYWORDS;

# MAGIC PACKAGES
#
# THESE ARE NOT CLASSES. They are magic strings that SVs can be blessed
# into to signify certain properties.
#
# ::default             may be replaced by method
# ::ambiguous           ambiguous defaults: croak when built
# ::mro                 a list of supermethods
# ::delegate            a ref to an object

{
    my $MG = __PACKAGE__ . "::";
    no warnings "uninitialized";

    sub _mg  { $MG . $_[0] }

    sub ismg { 
        my $pkg = blessed $_[0];
        @_ == 1 
            ? $pkg =~ /^\Q$MG/ 
            : grep $pkg eq $_, map _mg($_), @_;
    }

    sub mkmg {
        my $o   = $_[0];
        my $pkg = _mg $_[1];
        ismg $o and croak "tried to mkmg an ismg";
        ref $o or $o = \do{ my $tmp = $o };
        bless $o, $pkg;
    }
}

sub _ctx {
    my $sub = shift;
    my $ctx = (caller 1)[5];
    return $ctx
        ? $sub->(@_)
        : defined $ctx
            ? scalar $sub->(@_)
            : do { $sub->(@_); () };
}

sub invoke;
sub construct;
sub class;

sub import {
    my $pkg = caller;
    strict->import;
    warnings->import;

    # We must stub everything UNIVERSAL implements, or it won't be
    # autoloaded. The exception is VERSION, which *should* come from
    # UNIVERSAL.
    my @stubs = qw/isa DOES/;
    my %exports;

    $exports{can} = subname "$pkg\::can", sub {
        my ($self, $meth) = @_;
        # this should only apply to ->VERSION
        my $code = $self->UNIVERSAL::can($meth);
        $code and return $code;
        ref $self or $self = class $self;
        exists $self->{$meth} and return \&$meth;
    };

    # perl uses $AUTOLOAD in the package where AUTOLOAD was defined.
    our $AUTOLOAD;

    $exports{AUTOLOAD} = subname "AUTOLOAD", sub {
        my ($pkg, $name) = $AUTOLOAD =~ /(.*)::(.*)/;
        local $SELF = shift;
        warn "AUTOLOAD for $SELF";
        ref $SELF or $SELF = class $SELF;
        invoke $pkg, $name, @_;
    };

    {
        no strict "refs";
        *{"$pkg\::$_"} = $exports{$_}       for keys %exports;
        *{"$pkg\::$_"} = \&{"$pkg\::$_"}    for @stubs;
        *{"$pkg\::$_"} = \&$_               for @KEYWORDS;
    }

    namespace::clean->import(-cleanee => $pkg, @KEYWORDS);
}

push @KEYWORDS, qw/self class super/;

sub self () { $SELF }
sub class   { 
    my $pkg = @_ ? $_[0] : caller;
    warn "getting class $pkg";
    $CLASS{$pkg} ||= do {
        package Object::Closures::Class;
        Object::Closures::construct;
    };
}
sub super   { my $super = shift @SUPER; goto &$super; }

# resolve a list of names out of a tree of hashes
# returns ($entry, $title, @_)
# $entry is undef on failure
sub resolve {
    my $e = self;
    my $t;
    local $" = "|";
    warn "resolving [@_] for $e";
    while (my $k = shift) {
        $t = $t ? "$t/$k" : $k;
        exists $e->{$k} or return (undef, $t, @_);
        $e = $e->{$k};
        
        no warnings "uninitialized";
        reftype $e eq "HASH" and
            (not blessed $e or ismg $e)
                or return ($e, $t, @_);
    }
}

sub invoke;
sub invoke {
    my $caller = shift;
    my ($entry, $name, @args) = resolve @_;

    unless (defined $entry) {
        $name =~ m!/! and return;
        croak "No such method $caller->$name";
    }

    ref $entry or $entry = \do { my $tmp = $entry };
 
    warn "$caller->$name: got " . dump $entry;

    if (ismg $entry, "mro") {
        local @SUPER = @$entry;
        return super @args;
    }

    if (ismg $entry, "delegate") {
        return $$entry->$name(@args);
    }

    my $type = reftype $entry;

    if ($type eq "CODE") {
        @_ = @args;
        goto &$entry;
    }

    if ($type eq "HASH") {
        croak "Missing key for $caller->$name";
    }

    # there should be nothing left but scalar refs now
    return $$entry;
}

push @KEYWORDS, qw/build construct compose inherit with clone/;

use subs qw/method replace _get_mods _apply_mods/;

sub _no_dups {
    $BUILD{$_[0]}   and croak "$_[0] is already defined as a class";
    $COMPOSE{$_[0]} and croak "$_[0] is already defined as a role";
}

sub build (&) {
    my $class = caller;
    _no_dups $class;
    $BUILD{$class} = subname "$class\::*BUILD*", shift;
}

sub compose (&) {
    my $role = caller;
    _no_dups $role;
    $COMPOSE{$role} = subname "$role\::*COMPOSE*", shift;
}

sub construct {
    my $class = caller;
    local $SELF = bless {}, $class;
    for ($class, "UNIVERSAL") {
        method isa  => $_ => 1;
        method DOES => $_ => 1;
    }
    $SELF->{DESTROY} = mkmg 1, "default";
    $BUILD{$class}(@_);
    return self;
}

sub inherit {
    my $from = shift;
    my @mods = _get_mods \@_;

    ref $SELF or croak "inherit must be called from within build";

    $COMPOSE{$from}
        and croak "$from is a role, use 'with' instead of 'inherit'";

    method isa => $from => 1;
    $BUILD{$from} and $BUILD{$from}->(@_);
    _apply_mods @mods;
}

sub with {
    my $role = shift;
    my @mods = _get_mods \@_;

    ref $SELF or
        croak "with must be called from within build or compose";

    replace DOES => $role => 1;
    $COMPOSE{$role} and $COMPOSE{$role}->();
    _apply_mods @mods;
}

my @EDITS = qw/method replace before after override/;
push @KEYWORDS, @EDITS;

use subs qw/_do_edit/;

for my $sub (@EDITS) {
    no strict 'refs';
    *$sub = subname $sub, sub { _do_edit scalar caller, $sub, @_ };
}

# CREATION KEYWORDS
#
# method        croak if exists; in a role, ignore if exists
# replace       croak if !exists
# around        around, croak if !exists
# before        before, croak if !exists
# after         after, croak if !exists

# CALLER, TYPE, NAME..., ENTRY
sub _do_edit {

    my $caller = shift;
    my $type   = shift;
    my $entry  = pop;

    my $self  = self || class $caller;
    my $table = $self;
    my ($title, $name);

    my $create = $type eq "method";
    $type eq "method" and $COMPOSE{$caller} and $type = "default";

    while (1) {
        $name = shift;
        $title = $title ? "$title/$name" : $name;
        @_ or last;

        unless (exists $table->{$name}) {
            $create or croak "Method '$title' does not exist";
            $table->{$name} = {};
        }

        $table = $table->{$name};

        reftype $table eq 'HASH'
            or croak "Not a HASH reference";
    }
    Carp::cluck "$type $self->$title";

    my ($orig, $stash, $mg);

    if (exists $table->{$name}) {
        $orig = $table->{$name};
        $stash = reftype $orig eq "CODE" 
            ? stash_name $orig
            : undef;

        if ($type eq "default") {

            # you are allowed to defer resolving ambiguous defaults
            # until construction time
            if (ismg $orig, "default") {
                $table->{$name} = mkmg {
                    $stash  => $orig,
                    $caller => $entry,
                }, "ambiguous";
            }

            if (ismg $orig, "ambiguous") {
                ${$orig}{$caller} = $entry;
            }

            return;
        }

        if ($type eq "method") {
            croak "Method conflict with $stash->$title";
        }
    }
    else {
        $type eq "replace" and return;
        $create or croak "Method '$title' does not exist";
    }

    # ambiguous defaults have already been dealt with, so we can just
    # clear those magic entries
    if (ismg $orig, "ambiguous", "default") {
        delete $stash->{$name};
        undef $_ for $orig, $stash, $mg;
    }

    if ($type eq "override") {
        my @mro = ismg $orig, "mro" ? @$orig : $orig;
        $entry = mkmg [$entry, @mro], "mro";
    }
    if ($type eq "default") {
        $entry = mkmg $entry, "default";
    }

    {
        no warnings "uninitialized";
        reftype $entry eq "CODE" and
            subname "$caller\::$title", $entry;
    }
    $table->{$name} = $entry;
}

sub _get_mods {}
sub _apply_mods {}

sub clone {
    my ($old, $cbk) = @_;

    require Clone::Closure;

    # we must clone both in one operation
    my $new = Clone::Closure::clone([$old, $cbk]);
    ($new, $cbk) = @$new;

    $cbk and $cbk->($new);
    return $new;
}

require Object::Closures::Class;

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
