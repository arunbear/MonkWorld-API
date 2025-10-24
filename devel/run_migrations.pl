#!/usr/bin/env perl
use Mojo::Base -strict;
use Mojo::Pg;
use Mojo::File 'path';

# Get database URL from environment
my $dsn = $ENV{MONKWORLD_PG_URL}
  or die "MONKWORLD_PG_URL environment variable not set\n";

# Initialize database connection
my $pg = Mojo::Pg->new($dsn);

# Run migrations
my $path = path(__FILE__)->sibling('..', 'migrations');
$pg->migrations->from_dir($path)->migrate;

print "Migrations completed successfully\n";
