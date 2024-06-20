$ENV{KELP_REDEFINE} = 1;

use lib 't/lib';
use Kelp;
use Kelp::Base -strict;
use Test::More;

subtest 'testing Template::Null' => sub {
    my $app = Kelp->new(__config => {modules => ['Template::Null']});
    is $app->template(), '';
    is $app->template("something", {bar => 'foo'}), '';
};

subtest 'testing Template::Ducks' => sub {
    my $app = Kelp->new(__config => {modules => ['Template::Ducks']});
    is $app->template(), "All the ducks";
    is $app->template("something", {bar => 'foo'}), "All the ducks";
};

done_testing;

