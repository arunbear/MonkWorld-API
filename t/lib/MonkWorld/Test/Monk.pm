package MonkWorld::Test::Monk;

use v5.40;
use HTTP::Status qw(HTTP_CREATED HTTP_UNPROCESSABLE_CONTENT);
use Mojo::Pg;
use Mojo::URL;
use Test::Mojo;

use Test::Class::Most
    attributes  => [qw/mojo/];

INIT { Test::Class->runtests }

sub db_setup : Test(startup) ($self) {
    my $t = Test::Mojo->new('MonkWorld::API');
    $self->mojo($t);

    my $path = $t->app->home->child('migrations');
    my $pg = $t->app->pg;
    $pg->migrations->from_dir($path)->migrate;

    # keep transaction open for test isolation
    $self->{tx} = $pg->db->begin;
}

sub a_monk_can_be_created : Test(2) ($self) {
    my $t = $self->mojo;

    my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}
        or return('Expected MONKWORLD_AUTH_TOKEN in %ENV');

    subtest 'without an ID' => sub {
        $t->post_ok(
            '/monk' => {
                'Authorization' => "Bearer $auth_token"
            } => json => {
                username => 'testuser1'
            }
        )
        ->status_is(HTTP_CREATED)
        ->header_like('Location' => qr{/monk/\d+$})
        ->json_is('/username' => 'testuser1')
        ->json_has('/id');
    };

    subtest 'with an explicit ID' => sub {
        my $id = $t->tx->res->json->{id};
        ok $id > 0, 'ID is a positive integer';
        my $explicit_id = $id + 1;
        $t->post_ok(
            '/monk' => {
                'Authorization' => "Bearer $auth_token"
            } => json => {
                id => $explicit_id,
                username => 'testuser2'
            }
        )
        ->status_is(HTTP_CREATED)
        ->header_like('Location' => qr{/monk/$explicit_id$})
        ->json_is('/id' => $explicit_id)
        ->json_is('/username' => 'testuser2');
    };
}

sub a_monk_cannot_be_created_without_a_username : Tests(3) ($self) {
    my $t = $self->mojo;

    my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}
      or return('Expected MONKWORLD_AUTH_TOKEN in %ENV');

    $t->post_ok(
        '/monk' => {
            'Authorization' => "Bearer $auth_token"
        } => json => { }
    )
    ->status_is(HTTP_UNPROCESSABLE_CONTENT)
    ->json_like('/error' => qr/username is required/);
}

sub a_monk_cannot_be_created_with_an_invalid_id : Tests(4) ($self) {
    my $t = $self->mojo;

    my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}
        or return('Expected MONKWORLD_AUTH_TOKEN in %ENV');

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
}