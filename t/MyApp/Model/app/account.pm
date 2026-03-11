package MyApp::Model::app::account;
use base ORM::Model;

tablename 'accounts';

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column user_id    => (is => 'rw', isa => 'Int', required => 1);
column domain     => (is => 'rw', isa => 'Str', required => 1);
column created_at => (is => 'rw', isa => 'Str');
column updated_at => (is => 'rw', isa => 'Str');

belongs_to user => (
    is => 'rw', 
    isa => 'MyApp::Model::app::user',        
    foreign_key => 'user_id'
);

1;
