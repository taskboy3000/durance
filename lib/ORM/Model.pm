# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package ORM::Model;
use strict;
use warnings;
use Carp qw(croak);
use Mojo::Base '-base', '-signatures';

our %COLUMN_META;
our ( %_columns, %_primary_key, %_tablename, 
      %_has_many, %_belongs_to, %_validations );

has primaryKey => 'id';

sub db_class {
    my ($self, $val) = @_;
    my $is_class = !ref($self);
    
    if (defined $val) {
        no strict 'refs';
        ${"$self\::db_class"} = $val;
        return $self;
    }
    
    if (!$is_class && exists $self->{db_class} && defined $self->{db_class}) {
        return $self->{db_class};
    }
    
    my $pkg = $is_class ? $self : ref($self);
    no strict 'refs';
    return ${"$pkg\::db_class"};
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

sub import {
    my ($class) = @_;
    my $caller = caller;

    no strict 'refs';

    *{"${caller}::column"} = sub {
        my ( $name, @opts ) = @_;
        my %opts = @opts;
        my $pkg  = caller;

        $ORM::Model::_columns{$pkg} //= [];
        push @{ $ORM::Model::_columns{$pkg} }, $name;

        $ORM::Model::COLUMN_META{$pkg}{$name} = \%opts;

        if ( $opts{primary_key} ) {
            $ORM::Model::_primary_key{$pkg} = $name;
        }

        my $is = $opts{is} // 'rw';
        my $validations = $ORM::Model::_validations{$pkg}{$name} // {};
        my $col_isa     = lc($opts{isa} // '');
        my $col_length  = $opts{length};
        my $is_bool     = ($col_isa eq 'bool') ? 1 : 0;

        if ( $is eq 'rw' ) {
            *{"${pkg}::${name}"} = sub {
                my ( $self, $val ) = @_;
                if ( defined $val ) {
                    if (exists $validations->{required}
                        && $validations->{required} && !defined $val)
                    {
                        croak "$name is required";
                    }
                    if (exists $validations->{format} && defined $val) {
                        unless ($val =~ $validations->{format}) {
                            croak "Invalid $name: $val";
                        }
                    }
                    if ($is_bool) {
                        $val = $val ? 1 : 0;
                    }
                    if (defined $col_length && length($val) > $col_length) {
                        croak "$name exceeds maximum length of $col_length";
                    }
                    $self->{$name} = $val;
                    return $self;
                }
                if ($is_bool && !exists $self->{$name}
                    && defined $opts{default})
                {
                    return $opts{default} ? 1 : 0;
                }
                return $self->{$name};
            };
        }
        else {
            *{"${pkg}::${name}"} = sub {
                my ($self) = @_;
                return $self->{$name};
            };
        }

        return;
    };

    *{"${caller}::tablename"} = sub ($name) {
        my $pkg = caller;
        $_tablename{$pkg} = $name;
        return;
    };

    *{"${caller}::has_many"} = sub ($name, %opts) {
        my $pkg = caller;
        $_has_many{$pkg}{$name} = \%opts;
        
        my $isa = $opts{isa};
        my $foreign_key = $opts{foreign_key};
        
        unless ($foreign_key) {
            $foreign_key = "${name}_id";
        }
        
        *{"${pkg}::${name}"} = sub ($self) {
            my $model_class = $isa;
            my $fk = $foreign_key;
            my $pk = $self->primary_key;
            my $pk_val = $self->$pk;
            
            return () unless defined $pk_val;
            
            my $result = $model_class->where({ $fk => $pk_val });
            return wantarray ? @$result : $result;
        };
        
        my $create_method = "create_$name";
        *{"${pkg}::$create_method"} = sub ($self, @args) {
            my $model_class = $isa;
            my $pk = $self->primary_key;
            my $pk_val = $self->$pk;
            
            return croak "Cannot create related object without primary key" unless defined $pk_val;
            
            my %data = (@args, $foreign_key => $pk_val);
            return $model_class->create(\%data);
        };
        
        return;
    };

    *{"${caller}::belongs_to"} = sub ($name, %opts) {
        my $pkg = caller;
        $_belongs_to{$pkg}{$name} = \%opts;
        
        my $isa = $opts{isa};
        my $foreign_key = $opts{foreign_key} // "${name}_id";
        
        *{"${pkg}::${name}"} = sub ($self) {
            my $model_class = $isa;
            my $fk = $foreign_key;
            my $fk_val = $self->$fk;
            
            return undef unless defined $fk_val;
            
            return $model_class->find($fk_val);
        };
        
        return;
    };

    *{"${caller}::validates"} = sub ($name, %opts) {
        my $pkg = caller;
        $_validations{$pkg}{$name} = \%opts;
        return;
    };
}

sub table ($self) {
    my $callerPkg = ref $self || $self;
    
    if (exists $_tablename{$callerPkg}) {
        return $_tablename{$callerPkg};
    }
    
    my ($tableName) = ($callerPkg =~ /::([^:]+)$/);
    $tableName = lc $tableName;
    
    my ($namespace) = ($callerPkg =~ /^(.+?)::[^:]+$/);
    if ($namespace) {
        $namespace = lc $namespace;
        $namespace =~ s/::/_/g;
        $tableName = "${namespace}_${tableName}";
    }
    
    $tableName .= 's' unless $tableName =~ /s$/;
    return $tableName;
};

sub column_meta ( $class, $column ) {
    return $COLUMN_META{$class}{$column} // {};
}

sub columns ($class) {
    return $_columns{$class} // [];
}

sub primary_key ($class) {
    return $_primary_key{$class} // 'id';
}

sub has_many ($class, $name) {
    return $_has_many{$class}{$name} // {};
}

sub belongs_to ($class, $name) {
    return $_belongs_to{$class}{$name} // {};
}

sub validations ($class, $name) {
    return $_validations{$class}{$name} // {};
}

sub attributes {
    my ($class) = @_;
    return $_columns{$class} // [];
}

sub dbh {
    my ($self, $val) = @_;
    my $is_class = !ref($self);
    
    if (defined $val) {
        if ($is_class) {
            no strict 'refs';
            ${"$self\::dbh"} = $val;
            return $self;
        }
        $self->{dbh} = $val;
        return $self;
    }
    
    if (!$is_class && exists $self->{dbh} && defined $self->{dbh}) {
        return $self->{dbh};
    }
    
    my $pkg = $is_class ? $self : ref($self);
    
    my $dbh = _find_dbh($pkg);
    return $dbh if $dbh;
    
    my $db_class;
    if (!$is_class && exists $self->{db_class} && defined $self->{db_class}) {
        $db_class = $self->{db_class};
    }
    else {
        no strict 'refs';
        $db_class = ${"$pkg\::db_class"};
    }
    $db_class //= _db_class_for($pkg);
    
    my $loaded;
    {
        no strict 'refs';
        $loaded = %{"${db_class}::"} > 0 || @{"${db_class}::ISA"} > 0;
    }
    
    if (!$loaded) {
        eval "require $db_class";
        croak "Cannot load DB class $db_class: $@" if $@;
    }
    
    if ($db_class->can('dbh')) {
        return $db_class->dbh;
    }
    
    croak "No database handle available. Set dbh on the class or instance.";
}

sub _find_dbh {
    my ($pkg) = @_;
    
    {
        no strict 'refs';
        my $class_dbh = ${"$pkg\::dbh"};
        if (defined $class_dbh) {
            eval { 
                local $SIG{__WARN__} = sub {}; 
                $class_dbh->prepare('SELECT 1') 
            };
            if (!$@) {
                return $class_dbh;
            }
        }
        
        for my $parent (@{"${pkg}::ISA"}) {
            if (my $parent_dbh = _find_dbh($parent)) {
                return $parent_dbh;
            }
        }
    }
    
    return undef;
}

sub find ( $class, $id ) {
    my $pk    = $class->primary_key;
    my $table = $class->table;
    my $dbh   = $class->dbh // croak 'No database handle';

    my $stmt = "SELECT * FROM $table WHERE $pk = ?";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute($id);

    my $row = $sth->fetchrow_hashref;
    $sth->finish;

    return undef unless $row;

    return $class->new(%$row, dbh => $dbh);
}

sub all ($class) {
    my $table = $class->table;
    my $dbh   = $class->dbh // croak 'No database handle';

    my $stmt = "SELECT * FROM $table";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute;

    my @rows;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @rows,
          $class->new( %$row, dbh => $dbh );
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

sub create ( $class, $data ) {
    my $dbh = $class->dbh // croak 'No database handle';

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

    return $class->new( %$data, dbh => $dbh )->insert;
}

sub _columns_info ($class) {
    return {};
}

sub insert ($self) {
    my $table = ref($self)->table;
    my $dbh   = $self->dbh // croak 'No database handle';

    my @cols =
      grep { defined $self->{$_} && $_ ne 'dbh' }
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
    my $dbh   = $self->dbh // croak 'No database handle';

    my $pk      = ref($self)->primary_key;
    my $pk_val = $self->{$pk} // croak "Cannot update without primary key value";

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
          && $_ ne 'dbh'
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
    my $dbh   = $self->dbh // croak 'No database handle';

    my $pk      = ref($self)->primary_key;
    my $pk_val = $self->{$pk} // croak "Cannot delete without primary key value";

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
    delete $hash{dbh};
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

=head1 NAME

ORM::Model - Base class for ORM models

=head1 SYNOPSIS

    package MyApp::Model::User;
    use Mojo::Base 'ORM::Model', '-signatures';
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
than the limit will croak. This applies regardless of database type.

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
    my $user = MyApp::Model::User->find(1, $dbh);

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

=head2 dbh

    MyApp::Model::User->dbh($dbh);
    my $dbh = MyApp::Model::User->dbh;

Gets or sets the database handle for the class.

=head2 db_class

    MyApp::Model::User->db_class('MyApp::DB');

Gets or sets the DB class to use for connections. Defaults to
deriving from model package name (e.g., MyApp::Model::User → MyApp::DB).

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

Returns a hashref of the model's data (excluding dbh).

=head2 dbh

    my $dbh = $user->dbh;

Gets the database handle (from instance, class, or derived DB class).

=head1 EXAMPLE

    package MyApp::Model::User;
    use Mojo::Base 'ORM::Model', '-signatures';
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
