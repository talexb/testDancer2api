
#!/usr/bin/perl

#  Read the Roster CSV containing information up to Sept 30 (the filename ends
#  with 1001 because I got the name of last week's file wrong.  Sigh.)

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

my $dataFile = "api/TNL-Roster-NameOnly-2013-SeptOct-1001.csv";

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

    my $insertCmd =
"INSERT INTO event (e_type, e_status, e_date, e_startTime, e_endTime) VALUES (?,?,?,?,?)";

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

            $sthInsert->execute( 'Rehearsal', 'Confirmed', $date, '1900',
                '2200' )
              or croak "Failed to execute " . $sthInsert->errstr;
            $dateEvent{$date} =
              $dbh->last_insert_id( undef, undef, 'event', 'e_id' );
        }
    }
    $sthSearchEvent->finish
      or croak "Failed to finish " . $sthSearchEvent->errstr;
    $sthInsert->finish
      or croak "Failed to finish " . $sthInsert->errstr;

    #  OK -- all of the events on the roster exist in the database. Now we can
    #  cycle through the names and check that the people exist in the database.

    my $searchPersonCmd =
      "SELECT p_id, p_status FROM person WHERE p_firstName=? AND p_lastName=?";

    my $sthSearchPerson = $dbh->prepare($searchPersonCmd);
    defined $sthSearchPerson
      or croak "Failed to prepare statement " . $sthSearchPerson->errstr;

    my $searchLikeCmd =
        "SELECT p_id, p_firstName, p_lastName, p_status FROM person "
      . "WHERE p_firstName like ? and p_lastName like ?";

    my $sthLike = $dbh->prepare($searchLikeCmd);
    defined $sthLike
      or croak "Failed to prepare statement " . $sthLike->errstr;

    #  Database stuff for the inner loop ..

    my $cleanPersonEventCmd =
      "DELETE FROM person_event WHERE pe_p_id=? and pe_e_id=?";

    my $sthCleanPersonEvent = $dbh->prepare($cleanPersonEventCmd);
    defined $sthCleanPersonEvent
      or croak "Failed to prepare statement " . $sthCleanPersonEvent->errstr;

    my $addPersonEventCmd = "INSERT INTO person_event values(?,?,?,?)";

    my $sthAddPersonEvent = $dbh->prepare($addPersonEventCmd);
    defined $sthAddPersonEvent
      or croak "Failed to prepare statement " . $sthAddPersonEvent->errstr;

    while ( my $line = $csv->getline($fh) ) {

        my $offset = 1;
        my (@names) = map { $line->[$_] } ( 0, 7 );
        foreach my $name (@names) {

            if ( $name =~ /gone/i || $name =~ /hiatus/i ) { next; }

            my @subNames = split( /\s/, $name, 2 );
            $sthSearchPerson->execute(@subNames)
              or croak "Failed to execute (with $name) "
              . $sthSearchPerson->errstr;

            my $href = $sthSearchPerson->fetchrow_hashref;
            if ( !defined $href ) {

		#  Code copied blatantly from csv4.pl @113.
                print ", -- NOT FOUND --\n-->Possible matches:\n";
                my (@first) = split( //, $subNames[0] );
                my (@last)  = split( //, $subNames[1] );
    
                $sthLike->execute( "$first[0]$first[1]%", "$last[0]$last[1]%" )
                  or croak "Failed to execute " . $sthLike->errstr;
                my @possibleMatches;
                while ( my $hrefLike = $sthLike->fetchrow_hashref ) {
                    print "--> $hrefLike->{p_firstName} / $hrefLike->{p_lastName}";
                    print " (p_id=$hrefLike->{p_id})";
                    push( @possibleMatches, $hrefLike );
                }
                if ( @possibleMatches == 1 ) {
                    $href = $possibleMatches[0];
                    print "--> Going with $href->{p_id} ..";
                }
                else {
                    print
                      "--> Couldn't find a single match, skipping this entry.\n";
                    next;
                }
            }

            #  OK, we have the person, now we need to match up the dates with
            #  the event ids, and add entries to the person_event table. We're
            #  not going to check that there isn't already something in the
            #  database; in fact, we'll do a delete beforehand to so as to
            #  prevent duplicates.  We'll add a record with response (what I
            #  hope to call 'intent' in the future) set to Yes for Active and
            #  Prospective members, otherwise No, and actual set to 'Yes' for x
            #  and 'No' otherwise.

            foreach my $date ( sort keys %dateEvent ) {

		#  Before I do any of this, I should check to see if this
		#  person is on hiatus or vacation, and if so, skip this part.
		#  This logic is going to have to wait until the
		#  hitaus/vacation table exists in the database.

		print "Delete p_id=$href->{p_id}, date=$dateEvent{$date} ..\n";
                $sthCleanPersonEvent->execute( $href->{p_id}, $dateEvent{$date} )
                  or croak
                  "Failed to do (with $href->{p_id}, $dateEvent{ $date }) "
                  . $sthCleanPersonEvent->errstr;

		print "Add p_id=$href->{p_id}, date=$dateEvent{$date} '$line->[ $offset ]' ..\n";
                $sthAddPersonEvent->execute(
                    $href->{p_id},
                    $dateEvent{$date},
                    (
                             $href->{p_status} eq 'Active'
                          || $href->{p_status} eq 'Prospect'
                      ) ? 'Yes' : 'No',
                    $line->[ $offset++ ] eq 'x' ? 'Yes' : 'No'
                  )
                  or croak
                  "Failed to do (with $href->{p_id}, $dateEvent{ $date }) "
                  . $sthAddPersonEvent->errstr;

            }
	    $offset += 2;
        }
    }

    $sthSearchPerson->finish
      or croak "Failed to finish " . $sthSearchPerson->errstr;
    $dbh->disconnect or croak "Failed to disconnect " . $dbh->errstr;

    close($fh);
}
