package MonkWorld::API;
use Mojo::Base 'Mojolicious', -signatures;

# This method will run once at server start
sub startup ($self) {

  # Load configuration from config file
  my $config = $self->plugin('NotYAMLConfig');

  # Configure the application
  $self->secrets($config->{secrets});

  # Router
  my $r = $self->routes;

  $r->get('/')->to('Example#welcome');
  $r->get('/health' => sub ($c) { $c->render(json => ['OK']) });
}

1;
