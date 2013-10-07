#!/usr/bin/perl

#  First test script to connect to the tnl1 database via DBIx::Class. --Alex
#  Beamish, October 6, 2013

use strict;
use warnings;
use Carp;

use lib './lib';

use TNLattendance::Schema;

{
    my $schema = TNLattendance::Schema->connect('dbi:SQLite:tnl1.db');
    defined $schema or croak "Unable to connect to database";

    my $result = $schema->resultset('Person')->search(undef,{});
    defined $result or croak "Unable to get resultset from DBIC";

    foreach my $person ( $result->all ) {

        print "Person: "
          . $person->p_firstname . " "
          . $person->p_lastname . "\n";
    }
}
