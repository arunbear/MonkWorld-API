package MonkWorld::API::Controller::Monk;
use v5.40;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use HTTP::Status qw(HTTP_UNPROCESSABLE_CONTENT HTTP_CREATED HTTP_CONFLICT);

sub create ($self) {
    my $data = $self->req->json;

    my $validator = Mojolicious::Validator->new;
    my $v = $validator->validation;
    $v->input($data);
    $v->required('username')->like(qr/^[a-zA-Z0-9_]+/)->like(qr/[a-zA-Z0-9_]+$/);
    $v->optional('id')->num(1, undef);

    if ($v->has_error('username')) {
        return $self->render(
            json   => { error => 'username is required' },
            status => HTTP_UNPROCESSABLE_CONTENT
        );
    }
    if ($v->has_error('id')) {
        return $self->render(
            json   => { error => 'ID must be a positive integer' },
            status => HTTP_UNPROCESSABLE_CONTENT
        );
    }

    my $monk_data = {
        username => $data->{username},
    };

    if (exists $data->{id}) {
        $monk_data->{id} = $data->{id};
    }

    my $result = $self->pg->db->insert('monk', $monk_data,
        {
            returning => ['id', 'username', 'created_at'],
            on_conflict => undef,
        });

    if ($result->rows == 0) {
        return $self->render(
            json   => { error => 'Username already exists' },
            status => HTTP_CONFLICT
        );
    }

    my $monk = $result->hash;

    $self->res->headers->location("/monk/$monk->{id}");
    $self->render(
        json   => $monk,
        status => HTTP_CREATED
    );
}
