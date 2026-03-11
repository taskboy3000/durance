package MyApp::Model::User;
use Mojo::Base 'ORM::Model', '-signatures';
use ORM::Model;

column id      => (is => 'rw', isa => 'Int', primary_key => 1);
column name    => (is => 'rw', isa => 'Str', required => 1);
column email   => (is => 'rw', isa => 'Str', unique => 1, required => 1);
column age     => (is => 'rw', isa => 'Int');
column active  => (is => 'rw', isa => 'Int', default => 1);

sub table { 'users' }

1;
