package Kelp::Generator;

use Kelp::Base;
use Path::Tiny;
use Kelp::Template;
use Carp;

our $scenarios_dir = path(__FILE__)->parent . '/templates';

sub list_scenarios {
    return map { path($_)->basename } glob "$scenarios_dir/*";
}

sub get_scenario_files {
    my ($self, $scenario) = @_;

    return glob "$scenarios_dir/$scenario/*";
}

sub get_template {
    my ($self, $scenario, $vars) = @_;
    $vars->{$_} // croak "variable `$_` is required"
        for qw(name module_path module_file);

    my @list = $self->get_scenario_files($scenario);
    croak "There's no generation template for $scenario"
        unless @list > 0;

    my @retval;
    my $template = Kelp::Template->new();
    for my $path (@list) {
        my $file = path($path);

        # resolve the destination name
        # hyphens become directory separators
        (my $dest_file = $file->basename) =~ s{-}{/}g;
        $dest_file =~ s/NAME/$vars->{name}/ge;
        $dest_file =~ s/PATH/$vars->{module_path}/ge;
        $dest_file =~ s/FILE/$vars->{module_file}/ge;

        # process the template, if it is .ttt (to distinguish from .tt)
        my $contents = $file->slurp;
        if ($dest_file =~ /\.ttt$/) {
            $dest_file =~ s/\.ttt$//;
            $contents = $template->process(\$contents, $vars);
        }

        push @retval, [$dest_file, $contents];
    }

    return \@retval;
}

1;
