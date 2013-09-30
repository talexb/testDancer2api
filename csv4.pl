#!/usr/bin/perl

#  Read the Oct05 event data into the database. Cloned from csv1.pl.  --Alex
#  Beamish, September 30, 2013

use strict;
use warnings;
use autodie;
use Carp;

use Text::CSV;
use DBI;

my $dataFile = "api/Oct05.csv";

my %standardParts = map { $_ => 1 } qw /Tenor Lead Baritone Bass/;

sub titleCase {
    my $string = shift;
    $string =~ s/^([a-zA-Z])([a-zA-Z]+)$/\U$1\L$2/;
    return $string;
}

{
    my $csv = Text::CSV->new( { binary => 1 } );
    open( my $fh, '<encoding(utf8)', $dataFile );

    my $dbh = DBI->connect( 'dbi:SQLite:dbname=tnl1.db', '', '' );
    defined $dbh or croak "Unable to connect to database " . $dbh->errstr;

    my $searchCmd =
"SELECT p_id, p_voicePart FROM person WHERE p_firstName=? and p_lastName=?";

    my $sthSearch = $dbh->prepare($searchCmd);
    defined $sthSearch
      or croak "Failed to prepare statement " . $sthSearch->errstr;

    my $searchLikeCmd =
        "SELECT p_id, p_firstName, p_lastName FROM person "
      . "WHERE p_firstName like ? and p_lastName like ?";

    my $sthLike = $dbh->prepare($searchLikeCmd);
    defined $sthLike
      or croak "Failed to prepare statement " . $sthLike->errstr;

    my $updateCmd = "UPDATE person SET p_voicePart=? WHERE p_id=?";

    my $sthUpdate = $dbh->prepare($updateCmd);
    defined $sthUpdate
      or croak "Failed to prepare statement " . $sthUpdate->errstr;

    my $insertCmd =
"INSERT INTO person_event (pe_p_id, pe_e_id, pe_response) VALUES (?, ?, ?)";

    my $sthInsert = $dbh->prepare($insertCmd);
    defined $sthInsert
      or croak "Failed to prepare statement " . $sthInsert->errstr;

    while ( my $line = $csv->getline($fh) ) {
        my ( $first, $last, $part ) = ( $line->[1], $line->[2], $line->[3] );
        my ( $coming, $notes ) = ( $line->[4], $line->[5] );

        if ( !length $part || $part =~ /:/ ) { next; }

        #  Standardize on title case for names and part.
        if ( $first =~ /^[a-z]+$/ || $first =~ /^[A-Z]+$/ ) {
            $first = titleCase($first);
            print "f ";
        }
        if ( $last =~ /^[a-z]+$/ || $last =~ /^[A-Z]+$/ ) {
            $last = titleCase($last);
            print "l ";
        }
        if ( $part =~ /^[a-z]+$/ || $part =~ /^[A-Z]+$/ ) {
            $part = titleCase($part);
            print "p ";
        }

        #  Clean up the parts - some guys may sing two parts.
        my @subParts = split( / /, $part );
        foreach my $bits (@subParts) {

            #  Go with the long form for Bari.
            if ( $bits eq 'Bari' ) {
                $bits = 'Baritone';
            }

            #  Cleanup non-alpha from parts.
            if ( $bits !~ /^[A-Z][a-z]+$/ ) {
                $bits =~ tr/a-zA-Z//cd;
                print "c ";
            }

            #  Complain if the part still isn't recognizable.
            next if ( exists $standardParts{$bits} );
            print "ERROR: Non-standard part $part\n";
        }

        $part = join( ' ', @subParts );
        print join( ' - ', $first, $last, $part );

        $sthSearch->execute( $first, $last )
          or croak "Failed to execute " . $sthSearch->errstr;
        my $href = $sthSearch->fetchrow_hashref;
        my $p_id = $href->{p_id};
        if ( defined $p_id ) {

            print ", found, p_id is $p_id";

        }
        else {

            print ", -- NOT FOUND --\n-->Possible matches:\n";
            my (@first) = split( //, $first );
            my (@last)  = split( //, $last );

            $sthLike->execute( "$first[0]$first[1]%", "$last[0]$last[1]%" )
              or croak "Failed to execute " . $sthLike->errstr;
            my @possibleMatches;
            while ( my $href = $sthLike->fetchrow_hashref ) {
                print "--> $href->{p_firstName} / $href->{p_lastName}";
                print " (p_id=$href->{p_id})";
                push( @possibleMatches, $href->{p_id} );
            }
            if ( @possibleMatches == 1 ) {
                $p_id = $possibleMatches[0];
                print "--> Going with $p_id ..";
            }
            else {
                print
                  "--> Couldn't find a single match, skipping this entry.\n";
                next;
            }
        }

        if ( !defined $href->{p_voicePart} ) {
            $sthUpdate->execute( $part, $p_id )
              or croak "Failed to execute " . $sthUpdate->errstr;
            print " updated voice part ..";
        }

        print " response: $coming ..";
        $sthInsert->execute( $href->{p_id}, 7, $coming, )
          or croak "Failed to execute " . $sthInsert->errstr;
        print " updated event #7 ..";
        print "\n";

    }

    $sthSearch->finish or croak "Failed to finish " . $sthSearch->errstr;
    $sthLike->finish   or croak "Failed to finish " . $sthLike->errstr;
    $sthUpdate->finish or croak "Failed to finish " . $sthUpdate->errstr;
    $sthInsert->finish or croak "Failed to finish " . $sthInsert->errstr;
    $dbh->disconnect   or croak "Failed to disconnect " . $dbh->errstr;

    close($fh);
}
