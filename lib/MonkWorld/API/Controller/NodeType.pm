package MonkWorld::API::Controller::NodeType;
use v5.40;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use HTTP::Status qw(HTTP_BAD_REQUEST HTTP_CREATED HTTP_CONFLICT);

sub create ($self) {
    my $data = $self->req->json;

    # Validate input
    return $self->render(
        json   => { error => 'name is required' },
        status => HTTP_BAD_REQUEST
    ) unless $data->{name};

    # Prepare node type data
    my $node_data = {
        name => $data->{name},
    };

    # Include ID if provided
    $node_data->{id} = $data->{id} if exists $data->{id};

    my $result = $self->pg->db->insert('node_type', $node_data,
        {
            returning => ['id', 'name'],
            on_conflict => undef,
        });

    if ($result->rows == 0) {
        return $self->render(
            json   => { error => 'Node type with this name already exists' },
            status => HTTP_CONFLICT
        );
    }

    my $node_type = $result->hash;
    $self->res->headers->location("/node-type/$node_type->{id}");
    $self->render(
        json   => $node_type,
        status => HTTP_CREATED
    );
}
