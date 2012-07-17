use strict;
use warnings;

package  # no-index
    MockZilla;

use Test::MockObject;

# FILENAME: MockZilla.pm
# CREATED: 18/03/12 02:39:10 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Mock Dist::Zilla
#
# Code extraced from 'exclude.t' and refactored to be self-contained.

my $prereqs;

my $objects = {

};

sub set_prereqs {
    my ( $self, $pr ) = @_;
    $prereqs = $pr;
    return $self;
}

sub dzil {
    my ($self) = @_;
    return $objects->{dz};
}

sub logger {
    my ($self) = @_;
    return $objects->{'log'};
}

sub import {
    $objects->{dzil} or _setup();
    return 1;
}

sub _setup {
    
    require Test::MockObject;

    $objects->{prereqs} = Test::MockObject->new();
    $objects->{prereqs}->set_bound( as_string_hash => \$prereqs );

    $objects->{'log'} = Test::MockObject->new;
    $objects->{'log'}->set_always( 'log' => $1 );

    $objects->{logger} = Test::MockObject->new;
    $objects->{logger}->set_always( proxy => $objects->{log} );

    $objects->{chrome} = Test::MockObject->new;
    $objects->{chrome}->set_always( logger => $objects->{logger} );

    $objects->{dz} = Test::MockObject->new;
    $objects->{dz}->fake_module('Dist::Zilla');
    $objects->{dz}->set_isa('Dist::Zilla');
    $objects->{dz}->set_always( prereqs => $objects->{prereqs} );
    $objects->{dz}->set_always( chrome  => $objects->{chrome} );

}

1;

