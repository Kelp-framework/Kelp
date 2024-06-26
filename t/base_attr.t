use Kelp::Base -strict;
use Test::More;

{

    package WithAttrs;

    use Kelp::Base -attr;

    attr a1 => 55;
}

ok !WithAttrs->can('new'), 'new ok';
ok !WithAttrs->isa('Kelp::Base'), 'base ok';
can_ok 'WithAttrs', 'a1';

done_testing;

