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
use Carp;

use Text::CSV;
use DBI;

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

    my $dbh = DBI->connect( 'dbi:SQLite:dbname=tnl1.db', '', '' );
    defined $dbh or croak "Unable to connect to database " . $dbh->errstr;

    my $insertCmd =
      'INSERT INTO person (p_firstname, p_lastname, p_status) VALUES (?, ?, ?)';

    my $sth = $dbh->prepare($insertCmd);
    defined $sth or croak "Failed to prepare statement " . $sth->errstr;

    foreach my $name (@names) {
        my @parts = split( /\s/, $name, 2 );
	if ( @parts != 2 ) {
	  warn "Ignoring: bad data: ", join(', ', @parts);
	  next;
	}
        $sth->execute( @parts, 'Active' )
          or croak "Failed to execute " . $sth->errstr;
    }

    $sth->finish     or croak "Failed to finish " . $sth->errstr;
    $dbh->disconnect or croak "Failed to disconnect " . $dbh->errstr;
}

