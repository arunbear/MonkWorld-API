package MonkWorld::API::Model::Node;

use v5.40;
use Mojo::Base -base, -signatures;

has 'pg';

sub create ($self, $node_data) {

    my $result = $self->pg->db->insert('node', $node_data,
        {
            returning => ['id', 'node_type_id', 'author_id', 'title', 'doctext', 'created_at'],
            on_conflict => undef,
        });
    return $result;
}