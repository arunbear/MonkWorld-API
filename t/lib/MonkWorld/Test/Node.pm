package MonkWorld::Test::Node;

use v5.40;
use HTTP::Status qw(HTTP_CREATED);

use Test::Class::Most
  parent => 'MonkWorld::Test::Base';


sub a_node_can_be_created : Test(4) ($self) {
    my $t = $self->mojo;

    my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}
      or return('Expected MONKWORLD_AUTH_TOKEN in %ENV');

    # First, create a node type that we'll use for the node
    $t->post_ok(
        '/node-type' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            name => 'post'
        }
    )->status_is(HTTP_CREATED);

    my $node_type_id = $t->tx->res->json->{id};
    my $anon_user_id = $self->anonymous_user_id;

    subtest 'without an ID' => sub {
        $t->post_ok(
            '/node' => {
                'Authorization' => "Bearer $auth_token"
            } => json => {
                node_type_id => $node_type_id,
                author_id    => $anon_user_id,
                title       => 'Test Node',
                doctext     => 'This is a test node'
            }
        )
        ->status_is(HTTP_CREATED)
        ->header_like('Location' => qr{/node/\d+$})
        ->json_has('/id')
        ->json_has('/created_at')
        ->json_is('/title' => 'Test Node')
        ->json_is('/doctext' => 'This is a test node')
        ->json_is('/node_type_id' => $node_type_id);
    };

    subtest 'with an explicit ID' => sub {
        my $id = $t->tx->res->json->{id};
        ok $id > 0, 'ID is a positive integer';
        my $explicit_id = $id + 1;

        $t->post_ok(
            '/node' => {
                'Authorization' => "Bearer $auth_token"
            } => json => {
                id           => $explicit_id,
                node_type_id => $node_type_id,
                author_id    => $anon_user_id,
                title        => 'Node With ID',
                doctext      => 'This node has an explicit ID'
            }
        )
        ->status_is(HTTP_CREATED)
        ->header_like('Location' => qr{/node/\d+$})
        ->json_is('/id' => $explicit_id)
        ->json_is('/title' => 'Node With ID')
        ->json_is('/doctext' => 'This node has an explicit ID')
        ->json_is('/node_type_id' => $node_type_id);
    };
}
