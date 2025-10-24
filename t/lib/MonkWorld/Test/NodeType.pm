package MonkWorld::Test::NodeType;

use v5.40;
use HTTP::Status qw(HTTP_CREATED);
use Mojo::Pg;
use Mojo::URL;
use Test::Mojo;

use Test::Class::Most
  attributes  => [qw/mojo schema/];

INIT { Test::Class->runtests }

sub db_setup : Test(startup) ($self) {
    my $t = Test::Mojo->new('MonkWorld::API');
    $self->mojo($t);
    $self->schema('test_node_type'); # for test isolation

    my $pg = $t->app->pg;
    $pg->search_path([$self->schema, 'public']);
    $pg->db->query("DROP SCHEMA IF EXISTS ${\ $self->schema} CASCADE");
    $pg->db->query("CREATE SCHEMA ${\ $self->schema}");

    my $path = $t->app->home->child('migrations');
    $pg->migrations->from_dir($path)->migrate;
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

sub db_cleanup : Test(shutdown) ($self) {
    my $pg = $self->mojo->app->pg;
    $pg->db->query("DROP SCHEMA IF EXISTS ${\ $self->schema} CASCADE");
}