use Kelp::Base -strict;
use Kelp::Template;
use Test::More;
use Test::Exception;
use utf8;

my $t = Kelp::Template->new( paths => ['views', 't/views']);
is $t->process( \"[% a %] ☃", { a => 4 } ), '4 ☃', "Render SCALAR";
like $t->process('home.tt'), qr'Hello, world! ☃', "Render file";
like $t->process(\*DATA, { what => 'ducks', where => 'water' }), qr"All the ducks are swimming in the water", "Render GLOB";

dies_ok { $t->process("missing.tt") } "Dies if template is missing";

done_testing;

__DATA__
All the [% what %] are swimming in the [% where %]
