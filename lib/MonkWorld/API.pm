package MonkWorld::API;
use Mojo::Base 'Mojolicious', -signatures;
use HTTP::Status 'HTTP_UNAUTHORIZED';

# This method will run once at server start
sub startup ($self) {

  # Load configuration from config file
  my $config = $self->plugin('NotYAMLConfig');

  # Configure the application
  $self->secrets($config->{secrets});

  # Setup database
  $self->helper(pg => sub {
      state $pg = Mojo::Pg->new($ENV{MONKWORLD_PG_URL});
      return $pg;
  });

  # Router
  my $r = $self->routes;

  $r->get('/')->to('Example#welcome');
  $r->get('/health' => sub ($c) { $c->render(json => ['OK']) });

  # Protected routes
  my $auth = $r->under(sub ($c) {
      my $auth_header = $c->req->headers->authorization // '';
      my ($token) = $auth_header =~ /^Bearer (\S+)$/;

      return 1 if $token && $token eq ($ENV{MONKWORLD_AUTH_TOKEN} // '');

      $c->render(
          json   => { error => 'Unauthorized' },
          status => HTTP_UNAUTHORIZED
      );
      return undef;
  });

  $auth->post('/node-type')->to('NodeType#create');
}

1;
