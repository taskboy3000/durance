# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package MyApp::Model::app::user;
use Moo;
extends 'ORM::Model';
use ORM::DSL;

tablename 'users';

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column name       => (is => 'rw', isa => 'Str', required => 1);
column email      => (is => 'rw', isa => 'Str', unique => 1);
column created_at => (is => 'rw', isa => 'Str');
column updated_at => (is => 'rw', isa => 'Str');

has_many accounts => (is => 'rw', isa => 'MyApp::Model::app::account', 'class' => 'MyApp::Model::app::account');

validates email => (is => 'rw', isa => 'Str', format => qr/@/);

1;
