requires 'Mojo::Pg', '4.28';
requires 'Path::Iterator::Rule', '1.015';
requires 'Scalar::Constant', '0.001005';
requires 'HTTP::Message', '7.01';

on 'test' => sub {
  requires 'Test::Class::Most', '0.08';
  requires 'Test::Lib', '0.003';
};