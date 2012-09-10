package Dist::Zilla::Plugin::ReportVersions::Tiny;
use Moose;
with 'Dist::Zilla::Role::FileGatherer';
with 'Dist::Zilla::Role::TextTemplate';

use Dist::Zilla::File::FromCode;
use version;

sub mvp_multivalue_args { qw{exclude include} };
has exclude => (is => 'ro', isa => 'ArrayRef', default => sub { [] });
has include => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

our $template = q{use strict;
use warnings;
use Test::More 0.88;

use Module::Metadata;
use Module::Load::Conditional qw( can_load check_install );
# This is a relatively nice way to avoid Test::NoWarnings breaking our
# expectations by adding extra tests, without using no_plan.  It also helps
# avoid any other test module that feels introducing random tests, or even
# test plans, is a nice idea.
our $success = 0;
END { $success && done_testing; }

# List our own version used to generate this
my $v = "\nGenerated by {{$my_package}} v{{$my_version}}\n";

eval {
	# report our Perl details
	my $want = {{ $perl }};
	my $pv = ($^V || $]);
	$v .= "perl: $pv (wanted $want) on $^O from $^X\n\n";
};

defined($@) and diag("$@");

# Now, our module version dependencies:
sub pmver {
    my ($module, $wanted) = @_;

    my $info = Module::Metadata->new_from_module( $module );

    my $pmver;
    if ( $info && $info->version ) {
        $pmver = $info->version;
    }
    elsif ( ! check_install( $module ) ) {
        $pmver = 'module not found.';
    }
    elsif ( ! can_load( modules => $module ) ) {
        $pmver = 'died during require.';
    }
    else {
         $pmver = '<undef>';
    }

    # So, we should be good, right?
    return sprintf('%-45s => %-10s%-15s%s', $module, $pmver, $wanted, "\n");
}

{{$module_code}}


# All done.
$v .= <<'EOT';

Thanks for using my code.  I hope it works for you.
If not, please try and include this output in the bug report.
That will help me reproduce the issue and solve your problem.

EOT

diag($v);
ok(1, "we really didn't test anything, just reporting data");
$success = 1;
};

sub applicable_modules {
    my ($self) = @_;

    # Extract the set of modules we depend on.
    my %modules;
    my $prereq = $self->zilla->prereqs->as_string_hash;

    # Identify the set of modules, and the highest version required.
    for my $phase (keys %{ $prereq || {} }) {
        for my $type (keys %{ $prereq->{$phase} || {} }) {
            for my $module (keys %{ $prereq->{$phase}->{$type} || {} }) {
                next if exists $modules{$module} and
                    $modules{$module} > version->parse($prereq->{$phase}->{$type}->{$module});

                $modules{$module} = version->parse( $prereq->{$phase}->{$type}->{$module} );
            }
        }
    }

    # Cleanup
    for my $module ( keys %modules ) {
        if (grep { $module =~ m{$_} } @{ $self->exclude }) {
            $self->log("Will not report version of excluded module ${module}.");
            delete $modules{$module};
        }
    }

    # Add any "interesting" modules you might want reported
    for my $include ( @{ $self->include } ){
        # split by whitespace; also allow equal sign between "Mod::Name = 1.1"
        my ( $module, $version ) = (split(/[ =]+/, $include), 0);
        $self->log("Will also report version of included module ${module}.");
        $modules{$module} = $version;
    }

    # Turn objects back to strings.
    for my $module ( keys %modules ) {
        next unless ref $modules{$module};
        $modules{$module} = "$modules{$module}";
    }

    return \%modules;
}

sub generate_eval_stubs {
    my ( $self, $modules ) = @_;

    return join qq{\n}, map {
        my $ver = $modules->{$_};
        $ver = 'any version' if version->parse($ver) == 0;
        sprintf q[eval { $v .= pmver('%s','%s') };],  $_, $ver ;
    } sort keys %{$modules};
};

sub wanted_perl {
    my ( $self, $modules ) = @_;
    my $perl_version = delete $modules->{perl};
    defined($perl_version) ? "'${perl_version}'" : '"any version"';
}

sub generate_test_from_prereqs {
    my ($self) = @_;

    my $modules = $self->applicable_modules;

    my $perl = $self->wanted_perl( $modules );
    my $module_code = $self->generate_eval_stubs( $modules );
    
    my $content = $self->fill_in_string($template, {
        perl    => $perl,
        module_code => $module_code,
        my_version => __PACKAGE__->VERSION,
        my_package => __PACKAGE__,
    });

    return $content;
}

sub gather_files {
  my ($self) = @_;

  my $file = Dist::Zilla::File::FromCode->new({
      name => 't/000-report-versions-tiny.t',
      mode => 0644,
      code => sub { $self->generate_test_from_prereqs }
  });

  $self->add_file($file);
  return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

=pod

=encoding utf8

=head1 NAME

Dist::Zilla::Plugin::ReportVersions::Tiny - reports dependency versions during testing

=head1 SYNOPSIS

In your F<dist.ini>, include C<[ReportVersions::Tiny]> to load the plugin.

=head1 DESCRIPTION

This module integrates with L<Dist::Zilla> to automatically add an additional
test to your released software.  Rather than testing features of the software,
this reports the versions of all static module dependencies, and of Perl, at
the time the tests are run.

The value of this is that when someone submits a test failure report you can
see which versions of the modules were installed and, hopefully, be able to
reproduce problems that are dependent on a specific set of module versions.

=head1 Differences from Dist::Zilla::Plugin::ReportVersions

This module has the same goal as L<Dist::Zilla::Plugin::ReportVersions>, but
takes a much lighter weight approach: the module that inspired my code bundles
a copy of YAML::Tiny, reads META.yml, then reports from that.

This gives the most accurate picture, since any requirements added at install
time will be detected, but is overkill for the vast majority of modules that
use a simple, static list of dependencies.

This module, rather, generates the list of modules to test at the time the
distribution is being built, and reports from that static list.

The biggest advantage of this is that I no longer have to bundle a large
volume of code that isn't really needed, and have a simpler test suite with
less places that things can go wrong.

=head1 ARGUMENTS

=over

=item B<exclude>

Exclude an individual items from version reporting.

This is most commonly required if some module otherwise interferes with the
normal operation of the tests, such as L<Module::Install>, which does not
behave as you might expect if normally C<use>d.

=item B<include>

  [ReportVersions::Tiny]
  include = JSON:PP 2.27103
  include = Path::Class
  include = Some::Thing = 1.1

Include extra modules in version reporting.
This can be specified multiple times.  The module name and version can be
separated by spaces (and/or an equal sign).  If no version is specified
"0" will be used.

This can be useful to help track down issues in installation or testing
environments.  Perhaps a module used by one of your prereqs is broken
and/or has a missing (or insufficient) dependency.  You can use this option
to specify multiple extra modules whose versions you would like reported.
They aren't modules that you need to declare as prerequisites
since you don't use them directly, but you've found installation issues
and it would be nice to show which version (if any) is in fact installed.

This option is inspired by advice from Andreas J. König (ANDK)
who suggested adding a list of "interesting modules" to the
F<Makefile.PL> and checking their version so that the test reports can show
which version (if any) is in fact installed
(see the L<CPAN> dist for an example).

=back

=head1 AUTHORS

Maintainer since 1.04: Olivier MenguE<eacute> L<mailto:dolmen@cpan.org>.

Original author: Daniel Pittman <daniel@rimspace.net>.

Contributors:

=over 4

=item Kent Fredric

=item Randy Stauner

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2012 by Olivier MenguE<eacute> L<mailto:dolmen@cpan.org>
All Rights Reserved.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
