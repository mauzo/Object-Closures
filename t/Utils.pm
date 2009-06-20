package t::Utils;

use Exporter "import";
use B;
use Test::More;

our @EXPORT = ( @Test::More::EXPORT, qw/
    does_ok b
/);

sub does_ok {
    my ($obj, $pkg) = @_;
    my $B = Test::More->builder;
    $B->ok($obj->DOES($pkg), "$obj DOES $pkg");
}

{
    # Test::More's can_ok is *WRONG*. It calls ->can on the class
    # instead of the object.
    no warnings "redefine";

    sub can_ok {
        my ($obj, $meth) = @_;
        my $B = Test::More->builder;
        $B->ok($obj->can($meth), "$obj can $meth");
    }
}

sub b { B::svref_2object($_[0]) }

1;
