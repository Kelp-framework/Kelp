use Kelp::Base -strict;
use Kelp::Template;
use Test::More;
use Test::Exception;
use IO::File;
use Encode;
use utf8;

my $t = Kelp::Template->new( paths => ['views', 't/views']);
is $t->process( \"[% a %] ☃", { a => 4 } ), encode_utf8('4 ☃'), "Render SCALAR";
is $t->process('home.tt'), encode_utf8("Hello, world! ☃\n"), "Render file";
is $t->process(\*DATA, { what => 'ducks', where => 'water' }), "All the ducks are swimming in the water\n", "Render GLOB";
my $f = IO::File->new("t/views/home.tt", "<:encoding(utf8)") or die $!;
is $t->process($f), encode_utf8("Hello, world! ☃\n"), "Render IO object";

dies_ok { $t->process("missing.tt") } "Dies if template is missing";

done_testing;

__DATA__
All the [% what %] are swimming in the [% where %]
