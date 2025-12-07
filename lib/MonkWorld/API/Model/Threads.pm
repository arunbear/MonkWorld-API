package MonkWorld::API::Model::Threads;

use v5.40;
use Mojo::Base 'MonkWorld::API::Model::Base', -signatures;
use Data::Dump 'dump';
use Time::HiRes qw(gettimeofday tv_interval);

sub get_threads ($self, $interval = '1 day') {
    my $rows = $self->fetch_threads_rows($interval);

    my $result = {};
    my @wanted_fields = qw(title created_at author_username author_id);
    my %section_of;

    # group rows into a thread hierarchy
    for my $row (@$rows) {

        my $is_root_node = $row->{path} eq $row->{id};
        if ($is_root_node) {
            my $section = $row->{section_name};
            $section_of{$row->{id}} = $section;
            foreach my $field (@wanted_fields) {
                $result->{$section}{ $row->{id} }{$field} = $row->{$field};
            }
            next;
        }

        # This is a reply.
        # Place it in a nested hash by walking its path segments.
        # Example:
        #   Root thread id 200; first reply 201; reply to that 202.
        #   note.path for node 202 is "200.201.202".
        #   We split to [200, 201, 202], take root_id=200, then create
        #   reply{201} and reply{202} under result->{Section}{200}.
        my @ids = split m{\.}, ($row->{path} // '');
        next unless @ids;

        my $root_id = shift @ids;
        my $section = $section_of{$root_id};
        my $cursor = $result->{$section}{$root_id};

        for my $seg_id (@ids) {
            $cursor->{reply}{$seg_id} //= {};
            $cursor = $cursor->{reply}{$seg_id};
        }
        # at leaf position
        foreach my $field (@wanted_fields) {
            $cursor->{$field} = $row->{$field};
        }
    }

    return $result;
}

sub fetch_threads_rows ($self, $interval = '1 day') {
    my $db = $self->pg->db;

    # Get threads that have been active in the most recent N day block
    #
    my $t0 = [gettimeofday];
    my $last_day = $db->query(q{SELECT MAX(created_at::date) AS max_day FROM node})->hash->{max_day};

    my $recent_ids = $db->query(q{
      SELECT n.id
      FROM node n
      WHERE n.created_at::date BETWEEN $1::date - $2::interval AND $3::date
    }, $last_day, $interval, $last_day)->arrays;

    my $elapsed = tv_interval ( $t0 );
    $self->log->debug("Elapsed Q2: $elapsed");
    $self->log->trace("Recent nodes: " . dump($recent_ids));
    my $id_array = sprintf('{%s}', $recent_ids->flatten->join(',')); # Pg array avoids (?, ?, ...) fiddliness

    # get details of these nodes and their ancestors
    my $rows = $db->query(q{
          SELECT DISTINCT
            n1.id,
            n1.title,
            n1.path,
            n1.created_at,
            m.username AS author_username,
            m.id AS author_id,
            s.name AS section_name
          FROM node n1
          JOIN monk m ON m.id = n1.author_id
          JOIN node_type s ON s.id = n1.node_type_id
          JOIN node n2 ON n1.path @> n2.path
            WHERE n2.id = ANY($1)
          ORDER BY n1.id
        }, $id_array
    )->hashes->to_array;
    $self->log->debug("Elapsed Q3: ". tv_interval($t0));
    $self->log->trace("Threads rows: " . dump($rows));

    return $rows;
}

__DATA__