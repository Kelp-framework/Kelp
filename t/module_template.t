
# Allow the redefining of globs at Kelp::Module
BEGIN {
    use FindBin '$Bin';
    $ENV{KELP_REDEFINE} = 1;
    $ENV{KELP_CONFIG_DIR} = "$Bin/../conf";
}

use Kelp::Base -strict;
use Kelp;
use Test::More;
use utf8;

# Basic
my $app = Kelp->new( mode => 'nomod' );
my $m = $app->load_module('Template');
isa_ok $m, 'Kelp::Module::Template';
can_ok $app, $_ for qw/template/;
is $app->template( \"[% a %] ☃", { a => 4 } ), '4 ☃', "Process";


# Test automatic appending of default extension to template names
my $ext = 'foo';
is $m->ext($ext), $ext, 'set default template ext';
is $m->ext, $ext, 'get default template ext';
is $m->_rename('home'), "home.$ext", 'if no extension, default appended';
is $m->_rename('home.tt'), 'home.tt', 'if extension, default not appended';
$m->ext('');
is $m->_rename('home'), 'home', 'if no default defined, no change';
$m->ext('tt');


done_testing;

