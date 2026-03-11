package ORM::DB;
use strict;
use warnings;
use DBI;
use Carp qw(croak);
use Mojo::Base '-base', '-signatures';

our %HANDLES;

has dsn             => undef;
has username        => '';
has password        => '';
has driver_options  => sub { { RaiseError => 1, AutoCommit => 1 } };

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

sub _build_dsn ($class, $type, $dbname, $host = undef) {
    if ($type eq 'sqlite') {
        return "dbi:SQLite:dbname=$dbname";
    }
    elsif ($type eq 'mariadb' || $type eq 'mysql') {
        $host //= 'localhost';
        return "dbi:mysql:host=$host;database=$dbname";
    }
    elsif ($type eq 'postgres') {
        $host //= 'localhost';
        return "dbi:Pg:host=$host;dbname=$dbname";
    }
    croak "Unsupported database type: $type";
}

sub disconnect_all {
    for my $dbh (values %HANDLES) {
        $dbh->disconnect if $dbh;
    }
    %HANDLES = ();
}

1;

__END__

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

    MyApp::Model::User      → MyApp::DB
    MyApp::Model::app::user → MyApp::DB
    Analytics::Model::Report → Analytics::DB

The ORM will automatically lazy-load this class when a model needs a database
connection.

=head1 ATTRIBUTS

=head2 dsn

The DBI data source name (DSN). Example: C<dbi:SQLite:dbname=app.db>

=head2 username

Database username (default: empty string)

=head2 password

Database password (default: empty string)

=head2 driver_options

Hashref of DBI connect options. Default: C<{ RaiseError =E<gt> 1, AutoCommit =E<gt> 1 }>

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
    use ORM::DB -base;

    has dsn             => 'dbi:SQLite:dbname=myapp.db';
    has driver_options  => sub { { RaiseError => 1, AutoCommit => 1 } };

    1;

    # Now models can automatically use this connection:
    package MyApp::Model::User;
    use ORM::Model;

    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str');

    sub table { 'users' }

    1;

    # Usage - dbh is derived automatically
    my $user = MyApp::Model::User->create({ name => 'John' });

=cut
