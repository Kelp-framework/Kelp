use Kelp::Base -strict;
use Test::More;
use Test::Harness 'execute_tests';
use File::Temp 'tempdir';
use Config;
use FindBin '$Bin';

test_app("Foo");

sub test_app {
    my $params = shift;
    my $kelp_dir = tempdir( CLEANUP => 1 );
    push @INC, "$kelp_dir/lib";
    system("$Config{perlpath} $Bin/../bin/Kelp --path=$kelp_dir --noverbose $params");

    my ( $total, $failed ) = execute_tests( tests => ["$kelp_dir/t/main.t"] );
    ok( $total->{bad} == 0 && $total->{max} > 0, "Generated app tests OK" )
      or diag explain $failed;
}

done_testing;
