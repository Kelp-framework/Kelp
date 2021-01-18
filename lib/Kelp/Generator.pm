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

    # instead of just globbing for files, introduce scenario files that will
    # list all the files for a scenario (otherwise any old files will just stay
    # there and be generated in new versions)
    my ($index_file) = map { "$scenarios_dir/$_/template" }
        grep { $_ eq $scenario }
        list_scenarios
    ;
    return unless $index_file;

    my $index = path($index_file);
    return unless $index->is_file;

    return map { s/^\s+//; s/\s+$//; "$scenarios_dir/$scenario/$_" }
        $index->lines({chomp => 1});
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

        # process the template, if it is .gen (generated)
        my $contents = $file->slurp;
        if ($dest_file =~ /\.gen$/) {
            $dest_file =~ s/\.gen$//;
            $contents = $template->process(\$contents, $vars);
        }

        push @retval, [$dest_file, $contents];
    }

    return \@retval;
}

1;

# TODO: Document template plugin mechanism for module authors
