
use Kelp;
use Kelp::Base -strict;
use Test::More;

# Basic
my $app = Kelp->new( __config => { modules => ['Template::Null'] } );
is $app->template(), "All the ducks";
is $app->template("something", { bar => 'foo' }), "All the ducks";

done_testing;
