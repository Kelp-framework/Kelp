use Kelp::Base -strict;

use Kelp;
use Test::More;
use FindBin '$Bin';

$ENV{KELP_CONFIG_DIR} = "$Bin/conf/encoders";
my $app = Kelp->new(mode => 'test');

subtest 'testing default encoder' => sub {
    my $default_encoder = $app->get_encoder('json');
    my $encoder = $app->get_encoder(json => 'default');

    ok !$encoder->get_indent, 'encoder no indent ok';
    is $default_encoder, $encoder, 'encoder default key is default ok';

    ok !$encoder->get_space_before, 'space_before after modification ok';
    $encoder->space_before;
    ok $app->get_encoder('json')->get_space_before, 'space_before after modification ok';
};

subtest 'testing default encoder' => sub {
    my $encoder = $app->get_encoder(json => 'indented');
    ok $encoder->get_indent, 'encoder extra config ok';
    ok !$encoder->get_space_before, 'encoder no default config ok';
};

done_testing;

