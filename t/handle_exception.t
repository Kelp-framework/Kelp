use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Plack::Test;
use Plack::Builder;
use Test::More;

{

    package CustomApp;
    use Kelp::Base 'Kelp';

    sub handle_exception
    {
        my ($self, $exception) = @_;

        $self->res->set_code(418)->text->render("custom: $exception");
        return $self->finalize;
    }

    sub build
    {
        my $self = shift;
        $self->add_route('/die', sub { die "oops\n" });
    }
}

{

    package RethrowApp;
    use Kelp::Base 'Kelp';

    sub handle_exception
    {
        my ($self, $exception) = @_;
        die $exception;
    }

    sub build
    {
        my $self = shift;
        $self->add_route('/die', sub { die "oops\n" });
        $self->add_route('/http', sub { Kelp::Exception->throw(403) });
    }
}

use Kelp::Exception;

subtest 'custom rendering' => sub {
    my $t = Kelp::Test->new(app => CustomApp->new(mode => 'test'));

    $t->request(GET '/die')
        ->code_is(418)
        ->content_is("custom: oops\n");
};

subtest 'rethrowing everything to a middleware' => sub {
    my $logged;
    my $app = builder {
        enable sub {
            my $next = shift;
            sub {
                my $env = shift;
                my $res = eval { $next->($env) };
                if (my $err = $@) {
                    $logged = $err;
                    chomp $logged;
                    return [
                        503,
                        ['Content-Type' => 'text/plain'],
                        ["handled by middleware: $logged"]
                    ];
                }
                return $res;
            };
        };
        RethrowApp->new(mode => 'test')->run;
    };

    test_psgi $app, sub {
        my $cb = shift;

        my $res = $cb->(GET '/die');
        is $res->code, 503, 'plain die reaches the middleware';
        is $res->content, 'handled by middleware: oops', 'with the original error';

        $res = $cb->(GET '/http');
        is $res->code, 503, 'Kelp::Exception reaches the middleware too';
        isa_ok $logged, 'Kelp::Exception', 'original object';
    };
};

done_testing;
