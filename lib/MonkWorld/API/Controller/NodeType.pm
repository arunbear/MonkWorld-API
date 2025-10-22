package MonkWorld::API::Controller::NodeType;
use v5.40;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use HTTP::Status qw(HTTP_BAD_REQUEST HTTP_CREATED);

sub create ($self) {
    my $data = $self->req->json;

    # Validate input
    return $self->render(
        json   => { error => 'name is required' },
        status => HTTP_BAD_REQUEST
    ) unless $data->{name};

    # Prepare node type data
    my $node_data = {
        name        => $data->{name},
        description => $data->{description} // $data->{name},
    };

    # Include ID if provided
    $node_data->{id} = $data->{id} if exists $data->{id};

    # Insert node type
    my $result = $self->pg->db->insert('node_type', $node_data,
        { returning => ['id', 'name', 'description'] });

    my $node_type = $result->hash;
    $self->res->headers->location("/node-type/$node_type->{id}");
    $self->render(
        json   => $node_type,
        status => HTTP_CREATED
    );
}
