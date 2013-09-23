#!/usr/bin/perl

#  Try reading the CSV roster data in preparation for importing it into a
#  database.
#
#  This is fine so far, but now I have to adjust the SQL that creates the
#  database because some of the person fields appear to be mandatory, which is
#  incorrect. --Alex Beamish, September 21, 2013

use strict;
use warnings;
use autodie;

use Text::CSV;

my $dataFile = "api/TNL-Roster-NameOnly-2013-SeptOct.csv";

{
    my $csv = Text::CSV->new( { binary => 1 } );
    open( my $fh, '<encoding(utf8)', $dataFile );

    my (@names);
    while ( my $line = $csv->getline($fh) ) {
        if ( $line->[0] =~ /\w+\s\w+/ ) { push( @names, $line->[0] ); }
        if ( $line->[7] =~ /\w+\s\w+/ ) { push( @names, $line->[7] ); }
    }
    print join( "\n", @names ) . "\n";
}

