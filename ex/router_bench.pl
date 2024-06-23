use Kelp::Base -strict;
use Kelp::Util;
use Benchmark qw(cmpthese);

# the depth of the path, but the number of bridges will be +1
my $depth = @ARGV && $ARGV[0] =~ /^\d+$/ ? shift @ARGV : 0;
my $path = join '', map { "/$_" } 1 .. $depth, 'handler';

{

    package TestApp;

    use Kelp::Base 'Kelp';

    sub hello { 'hello' }
    sub hi { 'hi' }
}

my $app = TestApp->new;

sub prepare_match
{
    my $r = shift;
    return sub { $r->match($path) };
}

sub prepare_dispatch
{
    my $r = shift;
    my @routes = @{$r->match($path)};

    return sub { $r->dispatch($app, $_) for @routes };
}

my @classes = @ARGV;
@classes = 'Kelp::Routes' if !@classes;

my %cases;
foreach my $class (@classes) {
    my $r = Kelp::Util::load_package($class)->new(base => 'TestApp');

    my $tree_base = my $tree = [];

    for (1 .. $depth) {
        my $new_tree = [];
        push @{$tree}, "/$_" => {
            to => sub { 1 },
            tree => $new_tree,
        };

        $tree = $new_tree;
    }

    @{$tree} = (
        '/handler' => 'hello',
    );

    $r->add(
        '' => {
            to => sub { 1 },
            tree => $tree_base,
        }
    );

    say "$class matches: " . join ', ', map { '"' . $_->name . '"' } @{$r->match($path)};
    $cases{"$class->match"} = prepare_match($r);
    $cases{"$class->dispatch"} = prepare_dispatch($r);
}

cmpthese - 2, \%cases;

# benchmarks different implementations of Kelp::Routes
# usage: ex/router_bench.pl [<depth> <classname1> <classname2> ...]

