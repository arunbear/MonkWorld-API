package MonkWorld::Test::Note;

use v5.40;
use HTTP::Status qw(HTTP_CREATED HTTP_CONFLICT);
use MonkWorld::API::Constants qw(NODE_TYPE_NOTE NODE_TYPE_PERLQUESTION);

use Test::Class::Most
  parent => 'MonkWorld::Test::Base';

sub a_note_can_be_created : Test(4) ($self) {
    my $t = $self->mojo;

    my $auth_token = $ENV{MONKWORLD_AUTH_TOKEN}
      or return('Expected MONKWORLD_AUTH_TOKEN in %ENV');

    my $anon_user_id = $self->anonymous_user_id;

    my $parent_node = $t->post_ok(
        '/node' => {
            'Authorization' => "Bearer $auth_token"
        } => json => {
            node_type_id => NODE_TYPE_PERLQUESTION,
            author_id    => $anon_user_id,
            title        => 'A Parent',
            doctext      => 'This is also the root',
        }
    )->status_is(HTTP_CREATED)->tx->res->json;

    my $parent_node_id = $parent_node->{id};
    my $root_node_id = $parent_node_id;
    my $created_at = $parent_node->{created_at};

    subtest 'without an ID' => sub {
        $t->post_ok(
            '/node' => {
                'Authorization' => "Bearer $auth_token"
            } => json => {
                node_type_id => NODE_TYPE_NOTE,
                author_id    => $anon_user_id,
                title        => 'Test Note',
                doctext      => 'This is a test note',
                root_node    => $root_node_id,
                parent_node  => $parent_node_id,
                created      => $created_at,
            }
        )
        ->header_like('Location' => qr{/node/\d+$})
        ->json_has('/id')
        ->json_has('/created_at')
        ->json_is('/title' => 'Test Note')
        ->json_is('/doctext' => 'This is a test note')
        ->json_is('/node_type_id' => NODE_TYPE_NOTE)
        ->json_is('/root_node' => $root_node_id)
        ->json_is('/parent_node' => $parent_node_id)
        ->json_is('/path' => "$parent_node_id." . $t->tx->res->json->{id})
        ;
    };

    subtest 'with an explicit ID' => sub {
        my $id = $t->tx->res->json->{id};
        ok $id > 0, 'ID is a positive integer';
        my $explicit_id = $id + 2; # better than 1 as auto increment would give a false pass

        $t->post_ok(
            '/node' => {
                'Authorization' => "Bearer $auth_token"
            } => json => {
                node_id      => $explicit_id,
                node_type_id => NODE_TYPE_NOTE,
                author_id    => $anon_user_id,
                title        => 'Test Note with ID',
                doctext      => 'This is a test note with explicit ID',
                root_node    => $root_node_id,
                parent_node  => $parent_node_id,
                created      => $created_at,
            }
        )
        ->status_is(HTTP_CREATED)
        ->header_like('Location' => qr{/node/$explicit_id$})
        ->json_is('/id' => $explicit_id)
        ->json_has('/created_at')
        ->json_is('/title' => 'Test Note with ID')
        ->json_is('/doctext' => 'This is a test note with explicit ID')
        ->json_is('/node_type_id' => NODE_TYPE_NOTE)
        ->json_is('/root_node' => $root_node_id)
        ->json_is('/parent_node' => $parent_node_id)
        ->json_is('/path' => "$parent_node_id.$explicit_id");
    };
}