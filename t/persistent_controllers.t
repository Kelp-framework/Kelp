$ENV{KELP_REDEFINE} = 1;
use lib 't/lib';
use Kelp::Base -strict;
use MyApp2;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

subtest 'testing without persistence' => sub {

    # Get the app
    my $app = MyApp2->new(
        __config => {
            modules_init => {
                Routes => {
                    rebless => 1,
                    base => 'MyApp2::Controller',
                }
            }
        }
    );

    my $t = Kelp::Test->new(app => $app);

    $t->request_ok(GET '/persistence')
        ->content_is(1);

    $t->request_ok(GET '/persistence')
        ->content_is(1);

    $t->request_ok(GET '/persistence')
        ->content_is(1);
};

subtest 'testing with persistence' => sub {

    # Get the app
    my $app = MyApp2->new(
        __config => {
            persistent_controllers => 1,
            modules_init => {
                Routes => {
                    rebless => 1,
                    base => 'MyApp2::Controller',
                }
            }
        }
    );

    my $t = Kelp::Test->new(app => $app);

    $t->request_ok(GET '/persistence')
        ->content_is(1);

    $t->request_ok(GET '/persistence')
        ->content_is(2);

    $t->request_ok(GET '/persistence')
        ->content_is(3);
};

done_testing;

