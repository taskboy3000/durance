package MyApp::Model::Post;
use Mojo::Base 'ORM::Model', '-signatures';
use ORM::Model;

column id      => (is => 'rw', isa => 'Int', primary_key => 1);
column title   => (is => 'rw', isa => 'Str', required => 1);
column body    => (is => 'rw', isa => 'Text');

sub table { 'posts' }

1;
