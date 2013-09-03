package API;
use Dancer2;

our $VERSION = '0.01';

set serializer => 'JSON';

get '/person/:id' => sub {

    return { id => params->{id}, name => "Fred" . params->{id} };
};

1;

