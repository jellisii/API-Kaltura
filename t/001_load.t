# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN {
    use_ok( 'API::Kaltura' );
    use_ok('API::Kaltura::CuePoint')
}

my $kt = API::Kaltura->new ();
isa_ok ($kt, 'API::Kaltura');

my $cuepoint = API::Kaltura::CuePoint->new();
isa_ok($cuepoint, 'API::Kaltura::CuePoint');
