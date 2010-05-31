use strict;
use warnings;

use Test::More 0.88;
use Test::Differences;
use Test::Exception;
use Test::MockObject;
use File::Temp;

use vars qw{$prereq $dz $log};
BEGIN {
    # Done early, hopefully before anything else might load Dist::Zilla.
    my $dz_prereq = Test::MockObject->new;
    $dz_prereq->set_bound(as_string_hash => \$prereq);

    $log = Test::MockObject->new;
    $log->set_always(log => $1);

    my $dz_logger = Test::MockObject->new;
    $dz_logger->set_always(proxy => $log);

    my $dz_chrome = Test::MockObject->new;
    $dz_chrome->set_always(logger => $dz_logger);

    $dz = Test::MockObject->new;
    $dz->fake_module('Dist::Zilla');
    $dz->set_isa('Dist::Zilla');
    $dz->set_always(prereqs => $dz_prereq);
    $dz->set_always(chrome  => $dz_chrome);
}


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
        testing => { requires => { baz => 1, quux => 1, Moose => 5 } },
        build   => { requires => { baz => 2, foox => 1 } },
    };

    my $modules;
    lives_ok { $modules = $rv->applicable_modules }
        "we can collect the applicable modules for the distribution";

    eq_or_diff $modules, { baz => 2, foox => 1, quux => 1 },
        "we collected the first round of modules as expected";

    # Did we get the logging we expected?
    is $log->call_pos(1), 'log', 'logging was called as expected';
    is $log->call_args_pos(1, 2),
        'Will not report version of excluded module Moose.',
            "logging was called with the right arguments.";

    is $log->call_pos(2), undef, 'logging was only called once';
}

done_testing;
