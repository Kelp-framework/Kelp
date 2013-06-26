use Kelp::Base -strict;
use Test::More;
use Kelp;

my $app = Kelp->new;
ok($app->loaded_modules->{$_}) for (qw/Template JSON/);
isa_ok $app->loaded_modules->{Template}, 'Kelp::Module::Template';

done_testing;

