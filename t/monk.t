use Mojo::Base -strict;

use HTTP::Status qw(HTTP_CREATED HTTP_UNAUTHORIZED HTTP_UNPROCESSABLE_CONTENT);
use Mojo::Pg;
use Test::More;
use Test::Mojo;

plan skip_all => 'set MONKWORLD_PG_URL to enable this test' unless $ENV{MONKWORLD_PG_URL};

use Scalar::Constant TEST_SCHEMA => 'test_monk';

my $t = Test::Mojo->new('MonkWorld::API');

# Isolate tests
my $pg = $t->app->pg;
$pg->search_path([$TEST_SCHEMA, 'public']);
$pg->db->query("DROP SCHEMA IF EXISTS $TEST_SCHEMA CASCADE");
$pg->db->query("CREATE SCHEMA $TEST_SCHEMA");
my $path = $t->app->home->child('migrations');
$pg->migrations->from_dir($path)->migrate;

END {
    $pg->db->query("DROP SCHEMA $TEST_SCHEMA CASCADE")
      if $pg;
}

# Skip the authenticated test if no token is provided
if (my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}) {
    # Test creating a monk with bearer token
    $t->post_ok(
        '/monk' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            username => 'authenticated_monk',
        }
    )
    ->status_is(HTTP_CREATED)
    ->header_like('Location' => qr{/monk/\d+$})
    ->json_is('/username' => 'authenticated_monk')
    ->json_has('/id')
    ->json_has('/created_at');

    # Test creating a monk with an empty username
    $t->post_ok(
        '/monk' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            username => ' ',
        }
    )
    ->status_is(HTTP_UNPROCESSABLE_CONTENT)
    ->json_like('/error' => qr/username is required/);

    # Test creating a monk with an invalid ID
    $t->post_ok(
        '/monk' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            username => 'testuser',
            id => 'invalid_id'
        }
    )
    ->status_is(HTTP_UNPROCESSABLE_CONTENT)
    ->json_has('/error')
    ->json_like('/error' => qr/must be a positive integer/);

    # Test creating a monk with an explicit ID
    my $test_id = 9999;
    $t->post_ok(
        '/monk' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            id       => $test_id,
            username => 'monk_with_id',
        }
    )
    ->status_is(HTTP_CREATED)
    ->header_like('Location' => qr{/monk/\d+$})
    ->json_is('/id' => $test_id)
    ->json_is('/username' => 'monk_with_id')
    ->json_has('/created_at');
}
else {
    diag 'Skipping authenticated tests - set MONKWORLD_AUTH_TOKEN to enable';
}

done_testing();
