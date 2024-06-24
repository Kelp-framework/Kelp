use Kelp::Base -strict;
use Test::More;
use Kelp::Test -utf8;
use HTTP::Request::Common;
use URI::Escape;
use Kelp;
use utf8;

my $app = Kelp->new(mode => 'test');
my $t = Kelp::Test->new(app => $app);

subtest 'should handle UTF-8 in paths' => sub {
    $t->charset('latin1');    # set charset for tests

    my $text = 'Ha nincs ló, jó a szamár is.';
    $app->add_route(
        '/szamár' => sub {
            my $self = shift;
            $self->res->charset('latin1');
            return $text;
        }
    );

    $t->request(GET '/' . uri_escape_utf8('szamár'))
        ->full_content_type_is('text/html; charset=latin1')
        ->content_is($text);
};

subtest 'should replace manually set charset in response' => sub {
    $t->charset('UTF-32');    # set charset for tests

    my $text = 'Il vaut mieux prévenir que guérir.';
    $app->add_route(
        '/override' => sub {
            my $self = shift;
            $self->res->set_content_type('text/plain; encoding=UTF-16');
            $self->res->charset('UTF-32');
            return $text;
        }
    );

    $t->request(GET '/override')
        ->full_content_type_is('text/plain; charset=UTF-32')
        ->content_is($text);
};

subtest 'should copy charset from request to response' => sub {
    $t->charset('UTF-16');    # set charset for tests

    my $text = "Ten się śmieje, kto się śmieje ostatni.";
    $app->add_route(
        '/copy' => sub {
            my $self = shift;
            $self->res->charset($self->req->charset);
            return $text;
        }
    );

    $t->request(GET '/copy', 'Content-Type' => 'text/plain; charset=UTF-16')
        ->full_content_type_is('text/html; charset=UTF-16')
        ->content_is($text);

};

subtest 'should set but not not override charset' => sub {
    $t->charset('UTF-16');    # set charset for tests
    $app->charset('UTF-8');

    my $text = "Lepszy wróbel w garści, niż gołąb na dachu.";
    $app->add_route(
        '/respect' => sub {
            my $self = shift;
            $self->res->charset('UTF-16');
            $self->res->html;
            $self->res->json;
            $self->res->xml;
            $self->res->text;
            return $text;
        }
    );

    $t->request(GET '/respect', 'Content-Type' => 'text/plain')
        ->full_content_type_is('text/plain; charset=UTF-16')
        ->content_is($text);
};

done_testing;

