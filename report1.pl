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

    my $selectEvents = "SELECT e_id, e_date 
         FROM event
	WHERE e_type='Rehearsal' AND e_date < date('now')
     ORDER BY e_date";

    my $sthEvents = $dbh->prepare($selectEvents);
    defined $sthEvents
      or croak "Failed to prepare statement " . $sthEvents->errstr;

    $sthEvents->execute
      or croak "Failed to execute " . $sthEvents->errstr;

    my $selectAbsences = "SELECT pa_p_id
         FROM person_absence
	WHERE pa_startDate < ? AND pa_endDate > ?";

    my $sthAbsences = $dbh->prepare($selectAbsences);
    defined $sthAbsences
      or croak "Failed to prepare statement " . $sthAbsences->errstr;

    my @dates;
    while ( my $href = $sthEvents->fetchrow_hashref ) {

        #  This gets a list of absences by person IDs for the specific date. We
        #  turn these values into a hash so that later we can see if the person
        #  (who might have been absent) was actually planning to be away.

        $sthAbsences->execute( $href->{e_date}, $href->{e_date} )
          or croak "Failed to execute " . $sthAbsences->errstr;
        my $aref = $sthAbsences->fetchall_arrayref( [0] );
        my %list = map { $_->[0] => 1 } @$aref;

        push( @dates, { event => $href, absences => \%list } );
    }

    #  OK, this query's going to need some explanation. The output has to be
    #  grouped by voice part (Tenor, Lead, Bass, Baritone), but I also want the
    #  name to be formatted into a single field. Steve's original spreadsheet
    #  had sections in that order; however, the names appear to be in random
    #  order .. Well, this is going to be a first cut -- they're sorted by
    #  first name for now.

    my $selectAttendance =
      "SELECT p_voicePart, p_firstName || ' ' || p_lastName AS name, pe_actual, 
            p_id 
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

        $sthAttendance->execute( $date->{event}->{e_id} )
          or croak "Failed to execute " . $sthAttendance->errstr;

        while ( my $href = $sthAttendance->fetchrow_hashref ) {

	    #  Here's where we mark people as Away if they were on hiatus or on
	    #  vacation. However, if they showed up anyway, that's handled
	    #  correctly. (For example, John Mallett showed up Sept 9, even
	    #  though he'd planned to be away, just so he could announce why he
	    #  was going to be away.)

            my $value;
            if ( exists $date->{absences}->{ $href->{p_id} }
                && $href->{pe_actual} eq 'No' )
            {
                $value = 'Away';
            }
            else {
                $value = $href->{pe_actual};
            }
            push( @{ $hash{"$href->{p_voicePart}/$href->{name}"} }, $value );
        }
    }

    #  Aside: I should probably just be able to write a single query that would
    #  dump out all of the information I want at once .. this is going to have
    #  to do for now.

    print Dumper( \@dates, \%hash );

    my $csv = Text::CSV->new ( { binary => 1, eol => "\n" } );
    open ( my $fh, ">:encoding(utf8)", $outputFile );

    $csv->print ( $fh, [ undef, map { $_->{event}->{e_date} } @dates ] );
    foreach my $person ( sort sortPartThenName keys %hash ) {

      $csv->print ( $fh, [ $person, @{$hash{ $person }} ] );
    }

    close ( $fh );

}

sub sortPartThenName {

    #  I'm taking the 'Part/First Last' string and looking at the parts first.
    #  In some case there are multiple parts, so I'm going by the first part
    #  only.

    my @parts = map {
        my @w = split(/\//);
        if ( $w[0] =~ /(\w+)\s/ ) { $w[0] = $1; }
        $w[0]
    } ( $a, $b );

    #  This hash orders the parts as per Steve's original spreadsheet, and if
    #  the parts of the two singers is different, we report the sort order
    #  using this hash.

    my %partScores = (
        'Tenor'         => 1,
        'Lead'          => 2,
        'Bass'          => 3,
        'Baritone'      => 4,
    );

    if ( $parts[0] ne $parts[1] ) {
        return $partScores{ $parts[0] } <=> $partScores{ $parts[1] };
    }

    #  If the singers are in the same section, then we extract the names and
    #  order by the name (first, then last -- although that may change).

    my @names = map { my @w = split(/\//); $w[1] } ( $a, $b );
    return $names[0] cmp $names[1];
}
