
# Allow the redefining of globs at Kelp::Module
BEGIN {
    $ENV{KELP_REDEFINE} = 1;
}

use Kelp::Base -strict;
use Kelp;
use Kelp::Test;
use Test::More;
use HTTP::Request::Common;
use Path::Tiny qw(tempfile);

subtest 'testing log levels' => sub {
    my $app = Kelp->new(mode => 'nomod');
    my $m = $app->load_module('Logger');

    isa_ok $m, "Kelp::Module::Logger";
    can_ok $app, $_ for qw/error debug info logger/;

    my $t = Kelp::Test->new(app => $app);
    $app->add_route(
        '/log',
        sub {
            my $self = shift;
            $self->debug("Debug message");
            $self->error("Error message");
            $self->info("Info message");
            $self->logger('critical', "Critical message");
            "ok";
        }
    );
    $t->request(GET '/log')->code_is(200);
};

subtest 'testing log output' => sub {
    my $app = Kelp->new(mode => 'nomod');
    my $file = tempfile;
    my $m = $app->load_module(
        'Logger',
        outputs => [
            [
                'File',
                min_level => 'debug',
                filename => "$file",
            ],
        ]
    );

    $app->logger(info => 'test logging output');
    my $contents = $file->slurp;
    like $contents, qr/test logging output/, 'log message ok';
    note $contents;
};

done_testing;

