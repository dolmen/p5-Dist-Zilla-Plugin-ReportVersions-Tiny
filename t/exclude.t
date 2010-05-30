use strict;
use warnings;

use Test::More 0.88;
use Test::Differences;
use Test::Exception;
use Test::MockObject;
use File::Temp;

unified_diff;                   # format diff output nicely, please.

use vars qw{$prereq};
my $dz_prereq = Test::MockObject->new;
$dz_prereq->set_bound(as_string_hash => \$prereq);

my $dz = Test::MockObject->new;
$dz->set_isa('Dist::Zilla');
$dz->fake_module('Dist::Zilla');
$dz->fake_new('Dist::Zilla');
$dz->set_always(prereqs => $dz_prereq);


# This evaluates at runtime, which is important.
use_ok('Dist::Zilla::Plugin::ReportVersions::Tiny');

my $rv;
lives_ok {
    $rv = Dist::Zilla::Plugin::ReportVersions::Tiny->new(
        exclude     => [qw{Moose Unmatched::Module}],
        plugin_name => 'ReportVersions::Tiny',
        zilla       => $dz,
    );
} "we can create an instance with multiple exclusions";

{
    $prereq = {
        testing => { requires => { baz => 1, quux => 1 } },
        build   => { requires => { baz => 2, foox => 1 } },
    };

    my @modules;
    lives_ok { @modules = $rv->applicable_modules }
        "we can collect the applicable modules for the distribution";

    eq_or_diff \@modules, [qw{baz foox quux}],
        "we collected the first round of modules as expected";
}

done_testing;
