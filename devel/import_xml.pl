#!/usr/bin/env perl
use v5.40;
use feature 'try';
use Mojolicious;
use Mojo::File 'path';
use Mojo::Pg;
use Mojo::DOM;
use Mojo::Util qw(trim);
use Mojo::Loader qw(load_class);
use Data::Dumper;
use feature 'say';
use YAML::XS 'LoadFile';

process_xml();

sub process_xml {
    import_node_data(parse_xml());
}

sub parse_xml {
    my $xml_file = get_xml_file_from_args();

    # Read and parse XML
    my $xml = Mojo::File->new($xml_file)->slurp;
    my $dom = Mojo::DOM->new($xml);

    # Extract node data
    my $node = $dom->at('node')
        or die "No node found in XML file\n";

    my $node_id = $node->attr('id')
        or die "Node ID is required\n";

    my $title = $node->attr('title');
    my $created = $node->attr('created');
    my $updated = $node->attr('updated');

    # Extract node type
    my $type_name = lc($node->at('type')->text // 'note');
    my $type_id = $node->at('type')->attr('id');

    # Extract author
    my $author = $node->at('author');
    my $author_id = $author->attr('id');
    my $author_username = trim($author->text);

    my $content = '';
    my $reputation = 0;
    my $root_node;
    my $parent_node;

    if (my $data = $node->at('data')) {
        if (my $doctext = $data->at('field[name="doctext"]')) {
            $content = trim($doctext->text // '');
        }
        if (my $rep = $data->at('field[name="reputation"]')) {
            $reputation = $rep->text // 0;
        }
        if (my $root = $data->at('field[name="root_node"]')) {
            $root_node = $root->text;
        }
        if (my $parent = $data->at('field[name="parent_node"]')) {
            $parent_node = $parent->text;
        }
    }

    return {
        node_id         => $node_id,
        title           => $title,
        type_id         => $type_id,
        type_name       => $type_name,
        author_id       => $author_id,
        author_username => $author_username,
        content         => $content,
        reputation      => $reputation,
        root_node       => $root_node,
        parent_node     => $parent_node,
        created         => $created,
        updated         => $updated,
    };
}

sub import_node_data ($node_data) {
    my $pg = get_db_connection();
    my $db = $pg->db;
    my $tx = $db->begin;
    try {
        ensure_author_exists($db, $node_data);
        insert_node($db, $node_data);
        $tx->commit;
    } catch ($error) {
        die "Failed to import node $node_data->{node_id}: $error\n";
    }
}

sub ensure_author_exists ($db, $author_data) {
    my $results = $db->insert('monk', {
        id           => $author_data->{author_id},
        username     => $author_data->{author_username},
        is_anonymous => ($author_data->{author_id} == 961 ? 1 : 0),
        created_at   => $author_data->{created},
        updated_at   => $author_data->{created},
    }, { on_conflict => undef });

    printf("Rows inserted into monk: %d\n", $results->rows);
    return $results;
}

sub insert_node ($db, $node_data) {
    my $results = $db->insert('node', {
        id           => $node_data->{node_id},
        node_type_id => $node_data->{type_id},
        author_id    => $node_data->{author_id},
        root_node    => $node_data->{root_node} || $node_data->{node_id},
        parent_node  => $node_data->{parent_node} || $node_data->{node_id},
        title        => $node_data->{title},
        content      => $node_data->{content},
        reputation   => $node_data->{reputation},
        created_at   => $node_data->{created},
        updated_at   => $node_data->{updated}
    }, { on_conflict => undef });

    printf("Rows inserted into node: %d\n", $results->rows);
    return $results;
}

# ====== Utility Functions ======

sub get_xml_file_from_args {
    my $file = shift @ARGV || die "Error: No XML file specified\n";
    die "Error: Cannot read file '$file'\n" unless -r $file;
    return $file;
}

sub get_db_connection {
    # Load configuration from YAML file
    my $config_file = 'monk_world-a_p_i.yml';
    my $config = LoadFile($config_file);

    # Get database configuration
    my $db_conf = $config->{database} or die "No database configuration found in $config_file\n";

    # Construct connection string
    my $db_uri = sprintf('postgresql://%s:%s@%s:%d/%s',
        $db_conf->{username} // 'monk',
        $db_conf->{password},
        $db_conf->{host}     // 'localhost',
        $db_conf->{port}     // 5432,
        $db_conf->{database} // 'monkworld'
    );

    return Mojo::Pg->new($db_uri);
}
