package MyApp::Model::User;
BEGIN { require ORM::Base; ORM::Base->import; }
use strict;
use warnings;
use Mojo::Base 'ORM::Model';

column id    => (is => 'rw', isa => 'Int', primary_key => 1);
column name  => (is => 'rw', isa => 'Str', required => 1);
column email => (is => 'rw', isa => 'Str', required => 1, unique => 1);
column age   => (is => 'rw', isa => 'Int');
column active => (is => 'rw', isa => 'Bool', default => 1);

sub table { 'users' }

1;

=head1 NAME

MyApp::Model::User - Example user model

=head1 SYNOPSIS

    use MyApp::Model::User;
    
    my $user = MyApp::Model::User->create({
        name  => 'John Doe',
        email => 'john@example.com',
        age   => 30,
    });

=head1 DESCRIPTION

Example model class demonstrating the ORM.

=cut

package MyApp::Model::Post;
BEGIN { require ORM::Base; ORM::Base->import; }
use Mojo::Base 'ORM::Model';

column id      => (is => 'rw', isa => 'Int', primary_key => 1);
column title   => (is => 'rw', isa => 'Str', required => 1);
column body    => (is => 'rw', isa => 'Str');
column user_id => (is => 'rw', isa => 'Int', required => 1);
column created_at => (is => 'rw', isa => 'Int');

sub table { 'posts' }

1;

=head1 NAME

MyApp::Model::Post - Example post model

=head1 SYNOPSIS

    use MyApp::Model::Post;
    
    my $post = MyApp::Model::Post->create({
        title   => 'Hello World',
        body    => 'This is my first post',
        user_id => 1,
    });

=head1 DESCRIPTION

Example model class demonstrating the ORM.

=cut
