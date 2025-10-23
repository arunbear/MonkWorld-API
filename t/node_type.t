use Mojo::Base -strict;

use HTTP::Status qw(HTTP_CREATED HTTP_UNAUTHORIZED);
use Mojo::Pg;
use Mojo::URL;
use Test::More;
use Test::Mojo;

plan skip_all => 'set MONKWORLD_PG_URL to enable this test' unless $ENV{MONKWORLD_PG_URL};

use Scalar::Constant TEST_SCHEMA => 'test_node_type';

my $t = Test::Mojo->new('MonkWorld::API');

# Isolate tests
my $pg = $t->app->pg;
$pg->search_path([$TEST_SCHEMA, 'public']);
$pg->db->query("DROP SCHEMA IF EXISTS $TEST_SCHEMA CASCADE");
$pg->db->query("CREATE SCHEMA $TEST_SCHEMA");
my $path = $t->app->home->child('migrations');
$pg->migrations->from_dir($path)->migrate;

END {
    $pg->db->query("DROP SCHEMA $TEST_SCHEMA CASCADE");
}

# Skip the authenticated test if no token is provided
if (my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}) {
    # Test creating a node type with bearer token
    $t->post_ok(
        '/node-type' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            name        => 'authenticated_node_type',
            description => 'Created with bearer token',
        }
    )
    ->status_is(HTTP_CREATED)
    ->header_like('Location' => qr{/node-type/\d+$})
    ->json_is('/name' => 'authenticated_node_type')
    ->json_is('/description' => 'Created with bearer token')
    ->json_has('/id');

    # Test creating a node type with an explicit ID
    my $test_id = 9999;
    $t->post_ok(
        '/node-type' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            id          => $test_id,
            name        => 'with_explicit_id',
            description => 'Should use the provided ID',
        }
    )
    ->status_is(HTTP_CREATED)
    ->header_like('Location' => qr{/node-type/\d+$})
    ->json_is('/id' => $test_id)
    ->json_is('/name' => 'with_explicit_id')
    ->json_is('/description' => 'Should use the provided ID');
}
else {
    diag 'Skipping authenticated tests - set MONKWORLD_AUTH_TOKEN to enable';
}

done_testing();
