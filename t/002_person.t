use Test::More;
use strict;
use warnings;

use API;
use Dancer2::Test apps => ['API'];

{
    route_exists [ GET => '/person/:id' ], 'person route handler is defined';
    response_content_is_deeply [ GET => '/person/1' ],
      { id => 1, name => 'Fred1' }, "Fred1 test";
    done_testing;
}

