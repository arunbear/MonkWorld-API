package MonkWorld::API::Controller::Node;

use v5.40;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use HTTP::Status qw(HTTP_CREATED HTTP_BAD_REQUEST HTTP_CONFLICT);
use Mojo::JSON qw(decode_json);

sub create ($self) {
    my $data = $self->req->json;

    # Validate required fields
    return $self->render(
        json   => { error => 'node_type_id, title, and doctext are required' },
        status => HTTP_BAD_REQUEST
    ) unless $data->{node_type_id} && $data->{title} && $data->{doctext};

    # Prepare node data
    my $node_data = {
        node_type_id => $data->{node_type_id},
        author_id    => $data->{author_id},  # Include author_id from request
        title        => $data->{title},
        doctext      => $data->{doctext},
    };

    # Include ID if provided
    $node_data->{id} = $data->{id} if exists $data->{id};

    # Insert node with conflict handling
    my $result = $self->pg->db->insert('node', $node_data,
        {
            returning => ['id', 'node_type_id', 'author_id', 'title', 'doctext', 'created_at'],
            on_conflict => undef,
        });

    if ($result->rows == 0) {
        return $self->render(
            json   => { error => 'Node with this ID already exists' },
            status => HTTP_CONFLICT
        );
    }

    my $node = $result->hash;
    $self->res->headers->location("/node/$node->{id}");
    $self->render(
        json   => $node,
        status => HTTP_CREATED
    );
}

1;
