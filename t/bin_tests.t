use Kelp::Base -strict;
use Test::More;
use Test::Harness 'execute_tests';
use File::Temp 'tempdir';
use Config;
use FindBin '$Bin';

test_app("Foo");

sub test_app
{
    my $params = shift;
    my $kelp_dir = tempdir(CLEANUP => 1);
    push @INC, "$kelp_dir/lib";
    system("$Config{perlpath} $Bin/../bin/kelp-generator --path=$kelp_dir --noverbose $params");

    my ($total, $failed) = execute_tests(tests => ["$kelp_dir/t/main.t"]);
    ok($total->{bad} == 0 && $total->{max} > 0, "Generated app tests OK")
        or diag explain $failed;
}

my $help = `$Config{perlpath} $Bin/../bin/kelp-generator --help`;
like $help, qr/\Qkelp-generator [options] <Application::Package>\E/, 'help head ok';
like $help, qr/\QAvailable application types:\E/, 'help templates ok';

my $bad_call = `$Config{perlpath} $Bin/../bin/kelp-generator application-name 2>&1`;
like $bad_call, qr/\Qnot a Perl package name\E/, 'bad call ok';

done_testing;

