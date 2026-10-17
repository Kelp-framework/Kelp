use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use Kelp::Exception;
use HTTP::Request::Common;
use Plack::Test;
use Plack::Builder;
use Test::More;

{
    package PsgiException;

    sub new { my ($class, %args) = @_; bless {%args}, $class }
    sub throw { my $self = shift; die ref $self ? $self : $self->new(@_) }

    sub as_psgi {
        my $self = shift;
        return [302, ['Location' => $self->{location}], []];
    }
}

{
    package PlainException;

    sub new { bless {}, shift }
}

my $logged;
my $app = Kelp->new(mode => 'test');
$app->add_route('/redirect', sub {
    PsgiException->throw(location => '/elsewhere');
});
$app->add_route('/after', sub {
    my $after = 0;
    PsgiException->throw(location => '/elsewhere');
    $after = 1;    # must not be reached
    return "after: $after";
});
$app->add_route('/plain', sub { die PlainException->new });
$app->add_route('/kelp', sub { Kelp::Exception->throw(403) });
$app->add_route('/die', sub { die 'died' });

my $psgi_app = $app->run;

subtest 'exception rethrown to the middleware' => sub {
    my $wrapped = builder {
        enable 'HTTPExceptions';
        $psgi_app;
    };

    test_psgi $wrapped, sub {
        my $cb = shift;

        my $res = $cb->(GET '/redirect');
        is $res->code, 302, 'as_psgi response is used';
        is $res->header('Location'), '/elsewhere', 'Location is the one of the exception';

        $res = $cb->(GET '/after');
        is $res->code, 302, 'route execution is stopped by the exception';
    };
};

subtest 'other exceptions are still handled by Kelp' => sub {
    my $t = Kelp::Test->new(app => $app);

    $t->request(GET '/plain')
        ->code_is(500);

    $t->request(GET '/kelp')
        ->code_is(403);

    $t->request(GET '/die')
        ->code_is(500)
        ->content_like(qr/died/);
};

subtest 'without a middleware the exception reaches the server' => sub {
    my $caught = do {
        local $@;
        eval {
            $psgi_app->({
                SCRIPT_NAME       => '',
                REQUEST_METHOD    => 'GET',
                SERVER_NAME       => 'localhost',
                SERVER_PORT       => 80,
                PATH_INFO         => '/redirect',
                'psgi.url_scheme' => 'http',
                'psgi.input'      => \*STDIN,
                'psgi.errors'     => \*STDERR,
            });
        };
        $@;
    };

    isa_ok $caught, 'PsgiException', 'rethrown exception';
};

done_testing;
