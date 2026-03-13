# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package ORM::DB;
use strict;
use warnings;
use experimental 'signatures';
use utf8;

use Carp qw(croak);
use DBI;
use Moo;

our %HANDLES;

has dsn             => (is => 'lazy');
has username        => (is => 'ro', predicate => 1);
has password        => (is => 'ro', predicate => 1);
has driver_options  => (is => 'lazy');

sub _build_driver_options { { RaiseError => 1, AutoCommit => 1 } };
sub _build_dsn ($self) {
    die("assert: " . ref $self . " should make _build_dns to override this");
}

sub dbh ($self) {
    my $class = ref $self || $self;
    my $key   = $class;

    if ($HANDLES{$key} && $HANDLES{$key}->ping) {
        return $HANDLES{$key};
    }

    my $dsn  = $self->dsn // croak 'dsn not configured';
    my $dbh  = DBI->connect(
        $dsn,
        $self->username,
        $self->password,
        $self->driver_options,
    );

    $HANDLES{$key} = $dbh;
    return $dbh;
}

sub disconnect_all {
    for my $dbh (values %HANDLES) {
        $dbh->disconnect if $dbh;
    }
    %HANDLES = ();
}

1;

__END__

=encoding UTF-8

=head1 NAME

ORM::DB - Database connection manager base class

=head1 SYNOPSIS

    package MyApp::DB;
    use ORM::DB -base;

    has dsn    => 'dbi:SQLite:dbname=app.db';
    has driver_options => sub { { RaiseError => 1, AutoCommit => 1 } };

    1;

    # In your application
    my $dbh = MyApp::DB->dbh;

=head1 DESCRIPTION

ORM::DB is a base class for application-specific database connection managers.
Users create a subclass (e.g., MyApp::DB) that defines the DSN and connection
credentials.

=head2 Convention

Given model classes like C<MyApp::Model::User> or C<MyApp::Model::app::user>,
the ORM derives the DB class by replacing C<Model> with C<DB>:

    MyApp::Model::User      to MyApp::DB
    MyApp::Model::app::user to MyApp::DB
    Analytics::Model::Report to Analytics::DB

The ORM will automatically lazy-load this class when a model needs a database
connection.

=head1 ATTRIBUTES

=head2 dsn

    my $dsn = MyApp::DB->dsn;

The DBI data source name (DSN). Example: C<dbi:SQLite:dbname=app.db>
Lazy-initialized attribute.

=head2 username

    my $username = MyApp::DB->username;

Database username (default: empty string). Read-only attribute.

=head2 password

    my $password = MyApp::DB->password;

Database password (default: empty string). Read-only attribute.

=head2 driver_options

    my $opts = MyApp::DB->driver_options;

Hashref of DBI connect options. Default: C<{ RaiseError =E<gt> 1, AutoCommit =E<gt> 1 }>
Lazy-initialized attribute.

=head1 METHODS

=head2 dbh

    my $dbh = MyApp::DB->dbh;

Returns a connected DBI handle. Uses per-process handle pooling - the same
handle is returned for the same class if the connection is still alive (verified
via C<-E<gt>ping>).

=head2 disconnect_all

    ORM::DB->disconnect_all;

Disconnects all pooled handles. Useful for testing or clean shutdown.

=head1 EXAMPLE

    package MyApp::DB;
    use Moo;
    extends 'ORM::DB';

    sub _build_dsn { 'dbi:SQLite:dbname=myapp.db' };
    sub _build_driver_options { { RaiseError => 1, AutoCommit => 1 } };

    1;

    # Now models can automatically use this connection:
    package MyApp::Model::User;
    use Moo; 
    extends 'ORM::Model';

    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str');

    sub table { 'users' }

    1;

    # Usage - dbh is derived automatically
    my $user = MyApp::Model::User->create({ name => 'John' });

=cut
