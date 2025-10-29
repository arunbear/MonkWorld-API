package MonkWorld::API::Controller::Node;

use v5.40;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use HTTP::Status qw(HTTP_CREATED HTTP_BAD_REQUEST HTTP_CONFLICT);
use Mojo::JSON qw(decode_json);
use MonkWorld::API::Model::Node;

has node_model => sub ($self) {
    MonkWorld::API::Model::Node->new(pg => $self->pg);
};

sub create ($self) {
    my $data = $self->req->json;

    # Validate required fields
    return $self->render(
        json   => { error => 'node_type_id, title, and doctext are required' },
        status => HTTP_BAD_REQUEST
    ) unless $data->{node_type_id} && $data->{title} && $data->{doctext};

    my $collection = $self->node_model->create($data);

    if ($collection->size == 0) {
        return $self->render(
            json   => { error => 'Node with this ID already exists' },
            status => HTTP_CONFLICT
        );
    }

    my $node = $collection->first;
    $self->res->headers->location("/node/$node->{id}");
    $self->render(
        json   => $node,
        status => HTTP_CREATED
    );
}