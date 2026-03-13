# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package ORM::Model;
use strict;
use warnings;
use experimental 'signatures';


use Moo;

our %COLUMN_META;
our ( %_columns, %_primary_key, 
      %_has_many, %_belongs_to, %_validations );


has primaryKey => (is => 'lazy');
sub _build_primaryKey {'id'};

sub BUILD {
    my ($self, $args) = @_;
    
    # Handle db argument - store it in the object's hash
    if (exists $args->{db}) {
        $self->{db} = delete $args->{db};
    }
    
    my $class = ref $self || $self;
    my $cols = $class->columns;
    
    for my $col (@$cols) {
        if (exists $args->{$col} && defined $args->{$col}) {
            $self->{$col} = $args->{$col};
        }
    }
}


sub import {
    # Do nothing - users should explicitly use ORM::DSL
}

sub db {
    my $self = shift;
    my $class = ref $self || $self;
    
    # Instance: return stored db if exists
    if (ref $self && exists $self->{db}) {
        return $self->{db};
    }
    
    # Class: check for cached db instance (package variable)
    my $cache_key = "_db_cache";
    {
        no strict 'refs';
        return $$class{$cache_key} if exists $$class{$cache_key};
        
        # Create and cache new instance
        my $db_class = $class->_db_class_for;
        eval "require $db_class";
        die "Cannot load DB class $db_class: $@" if $@;
        my $db = $db_class->new;
        $$class{$cache_key} = $db;
        
        return $db;
    }
}

sub _db_class_for ($class) {
    my $pkg = $class =~ /::$/ ? $class : $class;
    $pkg =~ s/::Model::/::DB::/;
    $pkg =~ s/::Model$/::DB/;
    if ($pkg =~ /^(.+::)DB::([^:]+)$/) {
        $pkg = "$1DB";
    }
    return $pkg;
}

sub schema_name ($class) {
    my $pkg = ref $class || $class;
    if ($pkg =~ /^.+::Model::(.+?)::.+$/) {
        return $1;
    }
    return undef;
}

sub table ($self) {
    my $callerPkg = ref $self || $self;

    no strict 'refs';
    my $tableName = ${"${callerPkg}::_tablename"}; 
    if (defined $tableName) {
        return $tableName;
    }
    use strict;

    die("assert - tablename not set");
};

sub column_meta ( $class, $column ) {
    return $COLUMN_META{$class}{$column} // {};
}

sub columns ($self) {
    my $class = ref $self || $self;
    return $ORM::Model::_columns{$class} // [];
}

sub primary_key ($self) {
    my $class = ref $self || $self;
    return $ORM::Model::_primary_key{$class} // 'id';
}

sub validations ($self, $name) {
    my $class = ref $self || $self;
    return $ORM::Model::_validations{$class}{$name} // {};
}

sub attributes ($self) {
    my $class = ref $self || $self;
    return $ORM::Model::_columns{$class} // [];
}

sub has_many_relations ($class) {
    my $class_name = ref $class || $class;
    return $ORM::DSL::_has_many{$class_name} // {};
}

sub belongs_to_relations ($class) {
    my $class_name = ref $class || $class;
    return $ORM::DSL::_belongs_to{$class_name} // {};
}

sub related_to ($class, $name) {
    my $class_name = ref $class || $class;
    return $ORM::DSL::_has_many{$class_name}{$name} 
        // $ORM::DSL::_belongs_to{$class_name}{$name};
}

sub all_relations ($class) {
    # Unified accessor for all relationships (both has_many and belongs_to)
    # Returns: { relationship_name => 'has_many'|'belongs_to', ... }
    # NOTE: Hash key order is undefined; callers should use sort if consistent
    #       ordering is needed (e.g., for error messages or deterministic SQL)
    my %rels;
    my $hm = $class->has_many_relations;
    for my $name (keys %$hm) {
        $rels{$name} = 'has_many';
    }
    my $bt = $class->belongs_to_relations;
    for my $name (keys %$bt) {
        $rels{$name} = 'belongs_to';
    }
    return \%rels;
}

sub find ( $class, $id ) {
    my $pk    = $class->primary_key;
    my $table = $class->table;
    my $dbh   = $class->db->dbh;

    my $stmt = "SELECT * FROM $table WHERE $pk = ?";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute($id);

    my $row = $sth->fetchrow_hashref;
    $sth->finish;

    return undef unless $row;

    return $class->new(%$row, db => $class->db);
}

sub all ($class) {
    my $table = $class->table;
    my $dbh   = $class->db->dbh;

    my $stmt = "SELECT * FROM $table";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute;

    my @rows;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @rows,
          $class->new( %$row, db => $class->db );
    }
    $sth->finish;

    return wantarray ? @rows : \@rows;
}

sub where ( $class, $conditions = {} ) {
    my $rs_class = _load_resultset();
    my $rs = $rs_class->new(
        class       => $class,
        conditions  => $conditions,
        order_by    => [],
        limit_val   => undef,
        offset_val  => undef,
    );
    
    return wantarray ? $rs->all : $rs;
}

sub count ($class) {
    return $class->where({})->count;
}

sub first ($class) {
    return $class->where({})->first;
}

# Mented to a called as a class method
sub create ( $class, $data ) {
    my $dbh = $class->db->dbh;

    my $now = scalar localtime;
    if ($class->can('columns')) {
        my $cols = $class->columns;
        if (grep { $_ eq 'created_at' } @$cols) {
            $data->{created_at} //= $now;
        }
        if (grep { $_ eq 'updated_at' } @$cols) {
            $data->{updated_at} = $now;
        }
    }

    return $class->new( %$data, db => $class->db )->insert;
}

sub _columns_info ($class) {
    return {};
}

sub insert ($self) {
    my $table = ref($self)->table;
    my $dbh   = $self->db->dbh;

    my @cols =
      grep { defined $self->{$_} && $_ ne 'db' }
      keys %$self;
    return $self unless @cols;

    my @vals         = map { $self->{$_} } @cols;
    my $placeholders = join ', ', map {'?'} @cols;
    my $col_list     = join ', ', @cols;

    my $stmt = "INSERT INTO $table ($col_list) VALUES ($placeholders)";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute(@vals);
    $sth->finish;

    my $pk = ref($self)->primary_key;
    unless ( defined $self->{$pk} ) {
        my $id = $dbh->last_insert_id( undef, undef, $table, undef );
        $self->{$pk} = $id if defined $id;
    }

    return $self;
}

sub update ($self) {
    my $table = ref($self)->table;
    my $dbh   = $self->db->dbh;

    my $pk      = ref($self)->primary_key;
    my $pk_val = $self->{$pk} // die "Cannot update without primary key value";

    my $now = scalar localtime;
    if (ref($self)->can('columns')) {
        my $cols = ref($self)->columns;
        if (grep { $_ eq 'updated_at' } @$cols) {
            $self->{updated_at} = $now;
        }
    }

    my @cols =
      grep {
             defined $self->{$_}
          && $_ ne 'db'
          && $_ ne $pk
      }
      keys %$self;
    return $self unless @cols;

    my @vals       = map { $self->{$_} } @cols;
    my $set_clause = join ', ', map {"$_ = ?"} @cols;

    my $stmt = "UPDATE $table SET $set_clause WHERE $pk = ?";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute( @vals, $pk_val );
    $sth->finish;

    return $self;
}

sub delete ($self) {
    my $table = ref($self)->table;
    my $dbh   = $self->db->dbh;

    my $pk      = ref($self)->primary_key;
    my $pk_val = $self->{$pk} // die "Cannot delete without primary key value";

    my $stmt = "DELETE FROM $table WHERE $pk = ?";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute($pk_val);
    $sth->finish;

    return $self;
}

sub save ($self) {
    my $pk      = ref($self)->primary_key;
    my $pk_val = $self->{$pk};

    if ( defined $pk_val && $pk_val ne '' ) {
        return $self->update;
    }
    return $self->insert;
}

sub to_hash ($self) {
    my %hash = %$self;
    delete $hash{db};
    delete $hash{$_} for grep { !defined $self->{$_} } keys %hash;
    return \%hash;
}

sub _load_resultset {
    unless (defined &ORM::ResultSet::where) {
        require ORM::ResultSet;
    }
    return 'ORM::ResultSet';
}

1;

__END__

=encoding UTF-8

=head1 NAME

ORM::Model - Base class for ORM models

=head1 SYNOPSIS

    package MyApp::Model::User;
    use Moo;
    extends 'ORM::Model';
    use ORM::Model qw(column);

    column id      => (is => 'rw', isa => 'Int', primary_key => 1);
    column name    => (is => 'rw', isa => 'Str', required => 1);
    column email   => (is => 'rw', isa => 'Str', unique => 1);

    sub table { 'users' }

    1;

    # Usage
    my $user = MyApp::Model::User->create({ name => 'John', email => 'john@example.com' });
    my $user = MyApp::Model::User->find(1);
    my @users = MyApp::Model::User->where({ active => 1 })->order('name')->limit(10)->all;

=head1 DESCRIPTION

ORM::Model provides an ActiveRecord-style interface for database models.
It supports column definitions, CRUD operations, and chainable queries.

=head1 PACKAGE FUNCTIONS

These functions are available to model classes via C<use ORM::Model>.

=head2 column

    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str', required => 1);

Defines a column for the model. Options:

=over 4

=item * is - Access type: 'rw' (read-write) or 'ro' (read-only)

=item * isa - Data type: 'Int', 'Str', 'Text', 'Bool', 'Float', 'Timestamp'

=item * primary_key - Set to 1 for primary key column

=item * required - Set to 1 if column is required (NOT NULL)

=item * unique - Set to 1 for unique constraint

=item * default - Default value

=item * length - Maximum string length (enforced in setter, used for VARCHAR on MySQL)

=back

=head3 Setter Behavior

Setters generated for columns include automatic validation and coercion:

=over 4

=item * B<Length enforcement>: If C<length> is set, assigning a value longer
than the limit will die. This applies regardless of database type.

=item * B<Bool coercion>: Columns with C<isa =E<gt> 'Bool'> automatically
coerce values using Perl truthiness: truthy values become 1, falsy become 0.

=item * B<Format validation>: If a C<validates> rule with C<format> is
defined, the value is checked against the regex on set.

=back

=head2 tablename

    sub table { 'users' }

Defines the table name for the model. Defaults to package name with
C<::Model::> replaced by C<::> and lowercased.

=head2 has_many

    has_many accounts => (is => 'rw', isa => 'MyApp::Model::Account');

Defines a has-many relationship.

=head2 belongs_to

    belongs_to user => (is => 'rw', isa => 'MyApp::Model::User', foreign_key => 'user_id');

Defines a belongs-to relationship.

=head1 CLASS METHODS

=head2 create

    my $user = MyApp::Model::User->create({ name => 'John', email => 'john@example.com' });

Creates a new record in the database. Sets C<created_at> and C<updated_at> if
those columns exist. Returns the model instance with the primary key populated.

=head2 find

    my $user = MyApp::Model::User->find(1);

Finds a record by primary key. Returns undef if not found.

=head2 where

    my @users = MyApp::Model::User->where({ active => 1 });
    my $rs = MyApp::Model::User->where({ age => { '>' => 21 }]);

Returns matching records. In list context, returns results immediately.
In scalar context, returns a ResultSet for chainable queries.

=head2 all

    my @users = MyApp::Model::User->all;

Returns all records in the table.

=head2 columns

    my @columns = MyApp::Model::User->columns;

Returns list of column names.

=head2 column_meta

    my $meta = MyApp::Model::User->column_meta('email');

Returns column metadata (isa, required, unique, etc.).

=head2 primary_key

    my $pk = MyApp::Model::User->primary_key;

Returns the primary key column name (default: 'id').

=head2 table

    my $table = MyApp::Model::User->table;

Returns the table name for the model.

=head2 db

    my $db = MyApp::Model::User->db;

Gets the ORM::DB instance for the class. The DB class is automatically
derived from the model package name (e.g., MyApp::Model::User → MyApp::DB).

To use a custom DB instance, define C<sub _build_db> in your model:

    sub _build_db {
        my ($self) = @_;
        return MyApp::DB->new(dsn => 'dbi:SQLite:custom.db');
    }

=head2 validations

    my $rules = MyApp::Model::User->validations('email');

Returns validation rules for a column.

=head2 schema_name

    my $schema = MyApp::Model::User->schema_name;

Returns the schema name extracted from the package name (e.g., 'MyApp' from 'MyApp::Model::User').

=head2 attributes

    my @attrs = MyApp::Model::User->attributes;

Returns list of column names (alias for C<columns>).

=head1 INSTANCE METHODS

=head2 new

    my $user = MyApp::Model::User->new(name => 'John', email => 'john@example.com');

Creates a new model instance. Does not persist to database.

=head2 save

    $user->save;

Saves the model to the database. Calls C<insert> if new, C<update> if exists.

=head2 insert

    $user->insert;

Inserts the model as a new record. Sets primary key from C<last_insert_id>.

=head2 update

    $user->name('Jane')->update;

Updates existing record. Sets C<updated_at> if that column exists.

=head2 delete

    $user->delete;

Deletes the record from the database.

=head2 to_hash

    my $hash = $user->to_hash;

Returns a hashref of the model's data (excluding the C<db> reference).

=head2 db

    my $db = $user->db;

Gets the ORM::DB instance associated with this model. Configure by defining
C<sub _build_db { ... }> in your model class.

=head1 EXAMPLE

    package MyApp::Model::User;
    use Moo;
    extends 'ORM::Model';
    use ORM::Model qw(column);

    column id         => (is => 'rw', isa => 'Int', primary_key => 1);
    column name       => (is => 'rw', isa => 'Str', required => 1);
    column email      => (is => 'rw', isa => 'Str', unique => 1);
    column age        => (is => 'rw', isa => 'Int');
    column active     => (is => 'rw', isa => 'Int', default => 1);
    column created_at => (is => 'rw', isa => 'Str');
    column updated_at => (is => 'rw', isa => 'Str');

    sub table { 'users' }

    1;

    # Create
    my $user = MyApp::Model::User->create({
        name  => 'John',
        email => 'john@example.com',
        age   => 30,
    });

    # Read
    my $user = MyApp::Model::User->find($user->id);
    my @active = MyApp::Model::User->where({ active => 1 })->order('name')->all;

    # Update
    $user->name('Jane')->update;

    # Delete
    $user->delete;

=cut
