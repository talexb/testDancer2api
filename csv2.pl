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

    my ( @names1, @names2 );
    while ( my $line = $csv->getline($fh) ) {
        my (@fields) = ( $line->[0], $line->[7] );
        if ( $fields[0] =~ /\w+\s\w+/ ) { push( @names1, $fields[0] ); }
        if ( $fields[1] =~ /\w+\s\w+/ ) { push( @names2, $fields[1] ); }
    }
    print join( "\n", @names1, @names2 ) . "\n";
}

