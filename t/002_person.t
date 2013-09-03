use Test::More;
use strict;
use warnings;

use JSON;

use API;
use Dancer2::Test apps => ['API'];

{
    route_exists [ GET => '/person/:id' ], 'person route handler is defined';
    my $json = JSON->new->allow_nonref;
    response_content_is[ GET => '/person/1' ],
      $json->encode({id =>'1', name => 'Fred1'}), "Fred1 test";
    done_testing;
}

