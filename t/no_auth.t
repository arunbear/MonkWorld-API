use Mojo::Base -strict;

use HTTP::Status qw(HTTP_UNAUTHORIZED);
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('MonkWorld::API');

subtest 'Creating a monk without authentication' => sub {
    $t->post_ok('/monk' => json => {
        username => 'test_monk',
    })
    ->status_is(HTTP_UNAUTHORIZED)
    ->json_has('/error');
};

subtest 'Creating a node type without authentication' => sub {
    $t->post_ok('/node-type' => json => {
        name        => 'test_node_type',
        description => 'A test node type for testing',
    })
    ->status_is(HTTP_UNAUTHORIZED)
    ->json_has('/error');
};

done_testing();
