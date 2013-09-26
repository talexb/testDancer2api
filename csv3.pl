
#!/usr/bin/perl

#  Read the Roster CSV containing information up to Sept 23 (for somereason the
#  filename ends with 0930 -- no idea why).

#  This will assume that the year is 2013, and will check for the existence of
#  the events in the database. if they're missing, we'll exit (for now). If all
#  of the events exist, we'll enter the attendance information. And this
#  reminds me that we also need to enter hiatus information, and perhaps show
#  that as a separate field in the roster that I track attendance. --Alex
#  Beamish, September 26, 2013

use strict;
use warnings;
use autodie;
use Carp;

use Text::CSV;
use DBI;

my $dataFile = "api/TNL-Roster-NameOnly-2013-SeptOct-930.csv";

{
    my $csv = Text::CSV->new( { binary => 1 } );
    open( my $fh, '<encoding(utf8)', $dataFile );

    #  Look at the first line, which will have the 'Name' column header,
    #  followed by the five dates that this attendance roster is for.

    my $firstLine = $csv->getline($fh);
    my @dates = map { "2013-$firstLine->[$_]" } ( 1 .. 5 );

    my $dbh = DBI->connect( 'dbi:SQLite:dbname=tnl1.db', '', '' );
    defined $dbh or croak "Unable to connect to database " . $dbh->errstr;

    my $searchEventCmd = "SELECT e_id FROM event WHERE e_date=?";

    my $sthSearchEvent = $dbh->prepare($searchEventCmd);
    defined $sthSearchEvent
      or croak "Failed to prepare statement " . $sthSearchEvent->errstr;

    my $insertCmd = "INSERT INTO event (e_type, e_status, e_date, e_startTime, e_endTime) VALUES (?,?,?,?,?)";

    my $sthInsert = $dbh->prepare($insertCmd);
    defined $sthInsert
      or croak "Failed to prepare statement " . $sthInsert->errstr;

    my ( @errors, %dateEvent );
    foreach my $date (@dates) {

        $sthSearchEvent->execute($date)
          or croak "Failed to execute " . $sthSearchEvent->errstr;
        my $href = $sthSearchEvent->fetchrow_hashref;
        if ( defined $href ) {

            $dateEvent{$date} = $href->{e_id};

        }
        else {

            $sthInsert->execute('Rehearsal','Confirmed',$date,'1900','2200')
              or croak "Failed to execute " . $sthInsert->errstr;
	    $dateEvent{$date} = $dbh->last_insert_id(undef,undef,'event','e_id');
        }
    }
    $sthSearchEvent->finish
      or croak "Failed to finish " . $sthSearchEvent->errstr;
    $sthInsert->finish
      or croak "Failed to finish " . $sthInsert->errstr;

    foreach my $date ( keys %dateEvent ) {

        print "Date $date -> $dateEvent{ $date }\n";
    }
    exit;

    #  OK -- all of the events on the roster exist in the database. Now we can
    #  cycle through the names and check that the people exist in the database.

    my $searchPersonCmd =
      "SELECT p_id FROM person WHERE p_firstName=? AND p_lastName=?";

    my $sthSearchPerson = $dbh->prepare($searchPersonCmd);
    defined $sthSearchPerson
      or croak "Failed to prepare statement " . $sthSearchPerson->errstr;

    while ( my $line = $csv->getline($fh) ) {

        my (@names) = map { $line->[$_] } ( 0, 7 );
        foreach my $name (@names) {

            my @subNames = split( /\s/, $name, 2 );
            $sthSearchPerson->execute(@subNames)
              or croak "Failed to execute " . $sthSearchPerson->errstr;

            my $href = $sthSearchPerson->fetchrow_hashref;
            if ( !defined $href ) {

                print "ERROR: Did not find $name in database.\n";
            }
        }
    }

    $sthSearchPerson->finish
      or croak "Failed to finish " . $sthSearchPerson->errstr;
    $dbh->disconnect or croak "Failed to disconnect " . $dbh->errstr;

    close($fh);
}
