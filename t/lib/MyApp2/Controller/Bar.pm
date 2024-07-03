package MyApp2::Controller::Bar;
use Kelp::Base 'MyApp2::Controller';

attr last_value => 1;

sub naughty_secret { "I control the Bar" }

sub test_inherit { "OK" }

sub test_template
{
    return $_[0]->template('0');
}

sub test_res_template
{
    $_[0]->res->template('0');
}

sub before_finalize
{
    my $self = shift;
    $self->res->header('X-Controller' => 'Bar');
}

sub test_persistence
{
    my $self = shift;
    my $last = $self->last_value;
    $self->last_value($last + 1);

    return $last;
}

sub build
{
    my $self = shift;
    my $r = $self->routes;

    $r->add("/blessed_bar", "Bar::blessed");
    $r->add("/blessed_bar2", "bar#blessed");
}

1;

