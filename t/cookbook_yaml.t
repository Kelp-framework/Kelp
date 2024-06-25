use Kelp::Base -strict;
use Kelp::Test;
use Kelp;
use Test::More;
use HTTP::Request::Common;
use lib 't/lib';

my $has_yaml = eval {
    require Kelp::Module::YAML;
    1;
};

plan skip_all => 'These tests require Kelp::Module::YAML'
    unless $has_yaml;

{

    package YAML::Request;
    use Kelp::Base 'Kelp::Request';
    use Try::Tiny;

    sub is_yaml
    {
        my $self = shift;
        return 0 unless $self->content_type;
        return $self->content_type =~ m{^text/yaml}i;
    }

    sub yaml_content
    {
        my $self = shift;
        return undef unless $self->is_yaml;

        return try {
            $self->app->get_encoder(yaml => 'internal')->decode($self->content);
        }
        catch {
            undef;
        };
    }
}

{

    package YAML::Response;
    use Kelp::Base 'Kelp::Response';

    sub yaml
    {
        my $self = shift;
        $self->set_content_type('text/yaml', $self->charset || $self->app->charset);
        return $self;
    }

    sub _render_ref
    {
        my ($self, $body) = @_;

        if ($self->content_type =~ m{^text/yaml}i) {
            return $self->app->get_encoder(yaml => 'internal')->encode($body);
        }
        else {
            return $self->SUPER::_render_ref($body);
        }
    }

}

{

    package YAMLApp;
    use Kelp::Base 'Kelp';
    use Kelp::Exception;

    sub build
    {
        my $self = shift;

        $self->load_module('YAML');
        $self->request_obj('YAML::Request');
        $self->response_obj('YAML::Response');

        $self->add_route('/yaml' => 'handler');
    }

    sub handler
    {
        my $self = shift;
        my $yaml_document = $self->req->yaml_content;

        Kelp::Exception->throw(400)
            unless defined $yaml_document;

        $yaml_document->{test} = 'kelp';

        $self->res->yaml;
        return $yaml_document;
    }
}

my $app = YAMLApp->new(mode => 'test');
my $t = Kelp::Test->new(app => $app);

$t->request(POST '/yaml', Content_Type => 'text/yaml', Content => "a: 1\nb: 2")
    ->code_is(200)
    ->content_like(qr{a: 1})
    ->content_like(qr{b: 2})
    ->content_like(qr{test: kelp});

$t->request(POST '/yaml', Content_Type => 'text/plain', Content => "not yaml")
    ->code_is(400);

done_testing;

