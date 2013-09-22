#!/usr/bin/perl

#  Try reading the Oct28 event data in preparation for importing it into a
#  database.
#
#  This works quite well, but my conclusion is that I'd like to use the roster
#  that I use for attendance to initialize the people (er, persons), so my next
#  task is to parse that into a form that I can push into the database. --Alex
#  Beamish, September 21, 2013

use strict;
use warnings;
use autodie;

use Text::CSV;

my $dataFile = "api/Oct28.csv";

my %standardParts = map { $_ => 1 } qw /Tenor Lead Baritone Bass/;

sub titleCase {
    my $string = shift;
    $string =~ s/^([a-zA-Z])([a-zA-Z]+)$/\U$1\L$2/;
    return $string;
}

{
    my $csv = Text::CSV->new ({ binary => 1 });
    open ( my $fh, '<encoding(utf8)', $dataFile);
    while ( my $line = $csv->getline( $fh ) ) {
      my ( $first, $last, $part ) = ( $line->[9],$line->[10],$line->[11] );
      if ( !length $part || $part =~ /:/ ) { next; }

      #  Standardize on title case for names and part.
      if ( $first =~ /^[a-z]+$/ || $first =~ /^[A-Z]+$/ ) {
        $first = titleCase ( $first );
        print "f ";
      }
      if ( $last =~ /^[a-z]+$/ || $last =~ /^[A-Z]+$/ ) {
        $last = titleCase ( $last );
        print "l ";
      }
      if ( $part =~ /^[a-z]+$/ || $part =~ /^[A-Z]+$/ ) {
        $part = titleCase ( $part );
        print "p ";
      }

      #  Clean up the parts - some guys may sing two parts.
      my @subParts = split ( / /,$part );
      foreach my $bits ( @subParts ) {

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
        next if ( exists $standardParts{ $bits } );
        print "ERROR: Non-standard part $part\n";
      }

      $part = join(' ',@subParts);
      print join(' - ',$first,$last,$part);
      print "\n";
    }
    close ( $fh);
}
