package Kelp::Generator;

use Kelp::Base;
use Path::Tiny;
use Kelp::Template;
use Carp;

attr -templates_dir => sub { path(__FILE__)->parent . '/templates' };

sub list_templates
{
    my ($self) = @_;

    my $dir = $self->templates_dir;
    return map { path($_)->basename } glob "$dir/*";
}

sub get_template_files
{
    my ($self, $template) = @_;

    my $dir = $self->templates_dir;

    # instead of just globbing for files, introduce template files that will
    # list all the files for a template (otherwise any old files will just stay
    # there and be generated in new versions)
    my ($index_file) = map { "$dir/$_/template" }
        grep { $_ eq $template }
        $self->list_templates
        ;
    return unless $index_file;

    my $index = path($index_file);
    return unless $index->is_file;

    my @files = map { s/^\s+//; s/\s+$//; $_ } $index->lines({chomp => 1});
    return map { "$dir/$template/$_" } grep { length } @files;
}

sub get_template
{
    my ($self, $template, $name, %args) = @_;

    my $vars = {'name' => $name, %args};
    my @parts = split(/::/, $name);
    $vars->{module_file} = pop @parts;
    $vars->{module_path} = join('/', @parts);

    my @list = $self->get_template_files($template);
    croak "There's no generation template for $template"
        unless @list > 0;

    my @retval;
    my $tt = Kelp::Template->new();
    for my $path (@list) {
        my $file = path($path);

        # resolve the destination name
        # hyphens become directory separators
        (my $dest_file = $file->basename) =~ s{-}{/}g;
        $dest_file =~ s/NAME/$vars->{name}/g;
        $dest_file =~ s/PATH/$vars->{module_path}/g;
        $dest_file =~ s/FILE/$vars->{module_file}/g;
        $dest_file =~ s/DOT/./g;

        # process the template, if it is .gen (generated)
        my $contents = $file->slurp;
        if ($dest_file =~ /\.gen$/) {
            $dest_file =~ s/\.gen$//;
            $contents = $tt->process(\$contents, $vars);
        }

        push @retval, [$dest_file, $contents];
    }

    return \@retval;
}

1;

=pod

=head1 NAME

Kelp::Generator - Generation templates

=head1 SYNOPSIS

    use Kelp::Generator;

    my $gen = Kelp::Generator->new;
    # get available templates
    my @template = $gen->list_templates;

    # get parsed files (ready to be saved)
    my $files_aref = $gen->get_template($template, 'App::Name');

    for my $file (@$files_aref) {
        my ($file_name, $file_contents) = @$file;
    }

=head1 DESCRIPTION

This is a class for discovery and parsing of generation templates for Kelp. A
generation template is a set of files that can be parsed using
L<Template::Tiny> and inserted into a given directory. This class only handles
the discovery and parsing of these templates. The Kelp script or custom script
should handle saving them in a destination directory.

=head1 TEMPLATE CREATION

=head2 Discovery

This class will look into a directory in its installation tree to discover
available templates. The folder is C<Kelp/templates> by default and can be
changed by constructing the object with different C<templates_dir> attribute.
This means that CPAN modules can add templates to L<Kelp/templates> and they
will be discovered as long as they have been installed in the same root
directory as Kelp without changing the contents of the package variable. Any
template that can be discovered in the default directory will be usable in the
Kelp script.

=head2 Contents

The directory structure of C<Kelp/templates> directory is as follows:

    + templates
    | + template_name
      | - template
      | - file1.pl.gen
      | - NAME.pm.gen
    | + another_template_name
      | - template
      | - file1.tt

Each template directory must have a file named C<template>, which lists all the
files in that template like this:

    file1.pl.gen
    NAME.pm.gen

Any file that is not listed will not be used.

=head2 Template files

Each template file can contain L<Template> code:

    My::App::Name eq [% name %]
    Name eq [% module_file %]
    My/App eq [% module_path %]

It will be replaced accordingly, but only if the file ends with C<.gen>
extension. This extension also allows template files not to be confused with
real files, so should be used most of the time. The only case where the C<.gen>
extension should not be used in when generating template files using the same
syntax as L<Template>, because there's no way to tell which directives should
not be interpreted right away.

Files can also contain NAME, FILE, PATH and DOT in their name, which will be
replaced by C<name>, C<module_file>, C<module_path> and C<.>.

=head1 INTERFACE

=head2 Methods

=head3 new

    my $gen = Kelp::Generator->new(templates_dir => $dir);

Constructs a Kelp::Generator instance. C<templates_dir> is optional.

=head3 templates_dir

Returns the current templates directory. Can be changed by passing an argument
of this name to C<new>

=head3 get_template

    my $template_aref = $gen->get_template($template_name, $application_name, %more_vars);

Finds and parses template with L<Template::Tiny>, returning an array reference of files:

    ['file1.pl', 'contents'],
    ['replaced_name.pm', 'contents'],
    ...

Filenames will have directories and C<.gen> suffix stripped and all
placeholders replaced. File contents will be ready for saving.

C<%more_vars> can be specified to insert more variables into the template.

=head3 list_templates

    my @templates = $gen->list_templates;

Discovers and returns all the generation template names as a list.

=head3 get_template_files

    my @files = $gen->get_template_files($template_name);

Returns the list of template files for a given template. Will return full
paths, not just file names.

=cut

