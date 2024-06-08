use Kelp::Base -strict;
use Benchmark qw(cmpthese);

{
    package TestApp;

    use Kelp::Base 'Kelp';

    sub hello { 'hello' }
    sub hi    { 'hi'    }
}

my $app = TestApp->new;

sub prepare_match {
    my $r = shift;
    return sub { $r->match('/1/2/3') };
}

sub prepare_dispatch {
    my $r = shift;
    my @routes = @{ $r->match('/1/2/3') };

    return sub { $r->dispatch($app, $_) for @routes };
}

my @classes = @ARGV;
@classes = 'Kelp::Router' if !@classes;

my %cases;
foreach my $class (@classes) {
    eval "use $class; 1" or die $@;
    my $r = $class->new(base => 'TestApp');
    $r->add('' => {
        to => sub { 1 },
        tree => [
            '/1' => {
                to => sub { 1 },
                tree => [
                    '/2' => {
                        to => sub { 1 },
                        tree => [
                            '/3' => 'hello',
                        ],
                    },
                ],
            },
            '/2' => 'hi',
        ],
    });

    say "$class matches: " . join ', ', map { $_->name } @{ $r->match('/1/2/3') };
    $cases{"$class->match"} = prepare_match($r);
    $cases{"$class->dispatch"} = prepare_dispatch($r);
}

cmpthese -2, \%cases;

# benchmarks different implementations of Kelp::Routes

