# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package MyApp::Model::admin::role;
use base ORM::Model;

tablename 'roles';

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column rolename   => (is => 'rw', isa => 'Str', required => 1, unique => 1);
column created_at => (is => 'rw', isa => 'Str');
column updated_at => (is => 'rw', isa => 'Str');

has_many permissions => (is => 'rw', isa => 'MyApp::Model::admin::permission');

1;
