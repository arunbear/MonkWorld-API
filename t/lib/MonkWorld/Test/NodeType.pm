package MonkWorld::Test::NodeType;

use v5.40;
use HTTP::Status qw(HTTP_CREATED);
use Mojo::Pg;
use Mojo::URL;
use Test::Mojo;

use Test::Class::Most
  attributes  => [qw/mojo dbh/];

INIT { Test::Class->runtests }

sub db_prepare : Test(startup) ($self) {
    my $t = Test::Mojo->new('MonkWorld::API');
    $self->mojo($t);

    my $path = $t->app->home->child('migrations');
    my $pg = $t->app->pg;
    $pg->migrations->from_dir($path)->migrate;

    $self->dbh($pg->db->dbh);
}

sub db_setup : Test(setup) ($self) {
    $self->dbh->begin_work;
}

sub db_teardown : Test(teardown) ($self) {
    $self->dbh->rollback;
}

sub a_node_type_can_be_created : Test(2) ($self) {
    my $t = $self->mojo;

    my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}
      or return('Expected MONKWORLD_AUTH_TOKEN in %ENV');

    subtest 'without an ID' => sub {
        $t->post_ok(
            '/node-type' => {
                'Authorization' => "Bearer $auth_token"
            } => json => {
                name => 'a_node_type'
            }
        )
        ->status_is(HTTP_CREATED)
        ->header_like('Location' => qr{/node-type/\d+$})
        ->json_is('/name' => 'a_node_type')
        ->json_has('/id');
    };

    subtest 'with an explicit ID' => sub {
        my $id = $t->tx->res->json->{id};
        ok $id > 0, 'ID is a positive integer';
        my $explicit_id = $id + 1;
        $t->post_ok(
            '/node-type' => {
                'Authorization' => "Bearer $auth_token"
            } => json => {
                id   => $explicit_id,
                name => 'another_node_type'
            }
        )
        ->status_is(HTTP_CREATED)
        ->header_like('Location' => qr{/node-type/\d+$})
        ->json_is('/id' => $explicit_id)
        ->json_is('/name' => 'another_node_type');
    };
}

sub a_node_type_cannot_be_created_if_name_exists : Test(5) ($self) {
    my $t = $self->mojo;

    my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}
        or return('Expected MONKWORLD_AUTH_TOKEN in %ENV');

    my $node_type_name = 'test_node_type';

    # First, create a node type
    $t->post_ok(
        '/node-type' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            name => $node_type_name
        }
    )->status_is(HTTP_CREATED);

    # Then try to create another node type with the same name
    $t->post_ok(
        '/node-type' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            name => $node_type_name
        }
    )
    ->status_is(HTTP::Status::HTTP_CONFLICT)
    ->json_like('/error' => qr/already exists/);
}
