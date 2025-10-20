#!/usr/bin/env perl
use v5.40;
use feature 'say';
use feature 'try';
use Data::Dump 'dump';
use Devel::Assert 'on';
use Getopt::Long;
use Mojolicious;
use Mojo::Pg;
use Mojo::DOM;
use Mojo::Util qw(trim);
use Path::Iterator::Rule;
use XXX -with => 'Data::Dump';

my %OPT;
GetOptions(\%OPT,
    'limit=i',
) or die "Error in command line arguments\n";

process_xml();

sub process_xml {
    my $input = get_input_for_parsing();

    if (ref $input eq 'CODE') {
        my $count = 0;
        # Process multiple XML files from directory using iterator
        while (my $file = $input->()) {
            $count += import_node_data(parse_xml($file));
            last if defined $OPT{limit} && $count == $OPT{limit};
        }
    }
    else {
        # Process single XML file
        import_node_data(parse_xml($input));
    }
}

sub parse_xml ($xml_file) {
    # Read and parse XML
    my $xml = Mojo::File->new($xml_file)->slurp;
    my $dom = Mojo::DOM->new($xml);

    # Extract node data
    my $node = $dom->at('node')
        or die "No node found in XML file\n";

    my %field;
    $field{node_id} = $node->attr('id')
        or die "Node ID is required\n";

    for my $attr (qw(title created updated)) {
        $field{$attr} = $node->attr($attr);
    }

    # Extract node type
    my $type = $node->at('type');
    $field{type_name} = trim($type->text);
    $field{type_id}   = $type->attr('id');

    # Extract author
    my $author = $node->at('author');
    $field{author_id}       = $author->attr('id');
    $field{author_username} = trim($author->text);

    if (my $data = $node->at('data')) {
        for my $name (qw(doctext reputation root_node parent_node)) {
            if (my $field_elem = $data->at(qq{field[name="$name"]})) {
                $field{$name} = trim($field_elem->text // '');
            }
        }
    }

    $field{input_file} = $xml_file;

    return \%field;
}

sub import_node_data ($node_data) {
    my $pg = get_db_connection();
    my $db = $pg->db;
    my $tx = $db->begin;
    my $rows = 0;

    try {
        ensure_author_exists($db, $node_data);
        ensure_node_type_exists($db, $node_data);
        $rows = insert_node($db, $node_data);
        $tx->commit;
    } catch ($error) {
        my $message = "Failed to import node $node_data->{node_id}: $error\n" . dump($node_data);
        if ($error =~ /is not present in table "node"/) {
            warn "[Skipping] $message";
        }
        else {
            die "[Stopped] $message";
        }
    }
    return $rows;
}

sub ensure_node_type_exists ($db, $node_data) {
    my $results = $db->insert('node_type', {
        id          => $node_data->{type_id},
        name        => $node_data->{type_name},
        description => $node_data->{type_name},
    }, { on_conflict => undef });

    printf("Rows inserted into node_type: %d\n", $results->rows);
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
    if (!$node_data->{doctext}) {
        return 0;
    }
    if ($node_data->{updated} eq '0000-00-00 00:00:00') {
        $node_data->{updated} = $node_data->{created};
    }
    my $node_results = $db->insert('node', {
        id           => $node_data->{node_id},
        node_type_id => $node_data->{type_id},
        author_id    => $node_data->{author_id},
        title        => $node_data->{title},
        doctext      => $node_data->{doctext},
        reputation   => $node_data->{reputation} // 0,
        created_at   => $node_data->{created},
        updated_at   => $node_data->{updated}
    }, { on_conflict => undef });

    printf("Rows inserted into node: %d\n", $node_results->rows);

    if ($node_data->{type_id} == 11) {
        insert_note($db, $node_data);
    }
    return $node_results->rows;
}

sub insert_note ($db, $node_data) {
    my $root_node   = $node_data->{root_node};
    my $parent_node = $node_data->{parent_node};

    my @path_info = ($node_data->{node_id});
    if ($parent_node eq $root_node) {
        unshift @path_info, $parent_node;
    }
    else  {
        # Get parent's path and append current node ID
        my $parent = $db->select('note', ['path'], { node_id => $parent_node })->hash;
        if (!defined $parent) {
            warn "Parent node $parent_node not found for node $node_data->{node_id}";
            return;
        }
        unshift @path_info, $parent->{path};
    }
    my $path = join('.', @path_info);

    my $note_results = $db->insert('note', {
        node_id     => $node_data->{node_id},
        root_node   => $root_node,
        parent_node => $parent_node,
        path        => $path
    }, { on_conflict => undef });

    printf("Rows inserted into note: %d\n", $note_results->rows);
}

# ====== Utility Functions ======

sub get_input_for_parsing {
    my $file = shift @ARGV
        or die "Error: No XML file or directory specified\n";

    if (-d $file) {
        # Return iterator for XML files from directory
        my $rule = Path::Iterator::Rule->new;
        $rule->file->name('*.xml');
        return $rule->iter($file);
    }
    elsif (-f $file) {
        die "Error: Cannot read file '$file'\n" unless -r $file;
        return $file;
    }
}

sub get_db_connection {
    assert $ENV{MONKWORLD_PG_URL} =~ /^postgresql:/;
    state $pg = Mojo::Pg->new($ENV{MONKWORLD_PG_URL});
    return $pg;
}
