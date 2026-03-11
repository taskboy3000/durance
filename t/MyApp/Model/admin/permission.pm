# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package MyApp::Model::admin::permission;
use base ORM::Model;

tablename 'permissions';

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column user_id    => (is => 'rw', isa => 'Int', required => 1);
column role_id    => (is => 'rw', isa => 'Int', required => 1);
column created_at => (is => 'rw', isa => 'Str');
column updated_at => (is => 'rw', isa => 'Str');

belongs_to role => (
    is => 'rw', 
    isa => 'MyApp::Model::admin::role',        
    foreign_key => 'role_id'
);

1;
