package MonkWorld::Test::Base;

use v5.40;
use Mojo::Pg;
use Test::Mojo;
use Test::Class::Most
  attributes  => [qw/mojo pg dbh/];

INIT { Test::Class->runtests }

sub db_prepare : Test(startup) ($self) {
    my $t = Test::Mojo->new('MonkWorld::API');
    $self->mojo($t);

    my $path = $t->app->home->child('migrations');
    my $pg = $t->app->pg;
    $pg->migrations->from_dir($path)->migrate;

    $self->pg($pg);
    $self->dbh($pg->db->dbh);
}

# Start a new transaction before each test to ensure test isolation.
sub db_setup : Test(setup) ($self) {
    $self->dbh->begin_work;
}

# Roll back all changes after each test.
# This ensures tests don't affect each other.
sub db_teardown : Test(teardown) ($self) {
    $self->dbh->rollback;
}

sub anonymous_user_id ($self) {
    return $self->pg->db->select('monk', ['id'], { username => 'Anonymous Monk' })->hash->{id};
}