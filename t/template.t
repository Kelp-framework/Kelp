use Kelp::Base -strict;
use Kelp::Template;
use Test::More;
use Test::Exception;
use IO::File;
use utf8;

my $text = "Hello, world! ☃\nLine Two\n\n";

my $t = Kelp::Template->new(paths => ['views', 't/views']);
is $t->process(\$text), $text, "Render SCALAR";
is $t->process(\$text), $text, "Render SCALAR again";
is $t->process('home.tt'), $text, "Render file";
is $t->process('home.tt'), $text, "Render file again";
is $t->process(\*DATA), $text, "Render GLOB";
is $t->process(\*DATA), $text, "Render GLOB again";
is $t->process(\*DATA), $text, "Render GLOB third time (DATA is tricky)";
my $f = IO::File->new("t/views/home.tt", "<:encoding(utf8)") or die $!;
is $t->process($f), $text, "Render IO object";
is $t->process($f), $text, "Render IO object again";

dies_ok { $t->process("missing.tt") } "Dies if template is missing";

done_testing;

__DATA__
Hello, world! ☃
Line Two

