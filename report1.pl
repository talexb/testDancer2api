#!/usr/bin/perl

#  Generate a report in CSV format suitable for Steve Armstrong to import into
#  a spreadsheet, as done manually. --Alex Beamish, October 3, 2013.

use strict;
use warnings;
use autodie;
use Carp;

use Text::CSV;
use DBI;
use Data::Dumper;

my $outputFile = "/tmp/TNLattendance-Fall2013.csv";

{
    my $dbh = DBI->connect( 'dbi:SQLite:dbname=tnl1.db', '', '' );
    defined $dbh or croak "Unable to connect to database " . $dbh->errstr;

    my $selectEvents =
      "SELECT e_id, e_date 
         FROM event
	WHERE e_type='Rehearsal' AND e_date < date('now')
     ORDER BY e_date";
     
    my $sthEvents = $dbh->prepare($selectEvents);
    defined $sthEvents
      or croak "Failed to prepare statement " . $sthEvents->errstr;

    $sthEvents->execute
      or croak "Failed to execute " . $sthEvents->errstr;

    my @dates;
    while ( my $href = $sthEvents->fetchrow_hashref ) {

      push ( @dates, $href );
    }

    #  OK, this query's going to need some explanation. The output has to be
    #  grouped by voice part (Tenor, Lead, Bass, Baritone), but I also want the
    #  name to be formatted into a single field. Steve's original spreadsheet
    #  had sections in that order; however, the names appear to be in random
    #  order .. Well, this is going to be a first cut -- they're sorted by
    #  first name for now.

    my $selectAttendance = 
    "SELECT p_voicePart, p_firstName || ' ' || p_lastName AS name, pe_actual 
       FROM person
       JOIN person_event ON pe_p_id=p_id,
                   event ON    e_id=pe_e_id
      WHERE p_status='Active' AND e_id=?
   ORDER BY CASE p_voicePart
              WHEN 'Tenor' THEN 1
              WHEN 'Tenor Bass' THEN 1
  	      WHEN 'Lead' THEN 2
  	      WHEN 'Bass' THEN 3
  	      WHEN 'Baritone' THEN 4
  	      WHEN 'Lead Baritone' THEN 4
	      ELSE 5
	    END, name";
    my $sthAttendance = $dbh->prepare($selectAttendance);
    defined $sthAttendance
      or croak "Failed to prepare statement " . $sthAttendance->errstr;

    $sthAttendance->execute
      or croak "Failed to execute " . $sthAttendance->errstr;

    my %hash;
    foreach my $date (@dates) {

        $sthAttendance->execute( $date->{e_id} )
          or croak "Failed to execute " . $sthAttendance->errstr;

        while ( my $href = $sthAttendance->fetchrow_hashref ) {

            push(
                @{ $hash{"$href->{p_voicePart}/$href->{name}"} },
                $href->{pe_actual}
            );
        }
    }

    #  Aside: I should probably just be able to write a single query that would
    #  dump out all of the information I want at once .. this is going to have
    #  to do for now.

    #  Hmm .. the above query ignores the hiatus information I have .. perhaps
    #  add that later.

    print Dumper(\@dates,\%hash);

}
