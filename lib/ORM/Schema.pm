# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package ORM::Schema;
use strict;
use warnings;
use Mojo::Base '-base', '-signatures';
use Carp qw(croak);

has 'dbh';
has 'model_class';
has 'driver';

my %TYPE_MAP = (
    sqlite => {
        Int       => 'INTEGER',
        Str       => 'TEXT',
        Text      => 'TEXT',
        Bool      => 'INTEGER',
        Float     => 'REAL',
        Timestamp => 'TEXT',
    },
    mysql => {
        Int       => 'INTEGER',
        Str       => 'VARCHAR',
        Text      => 'TEXT',
        Bool      => 'TINYINT(1)',
        Float     => 'DOUBLE',
        Timestamp => 'TIMESTAMP',
    },
);

my %AUTO_INCREMENT = (
    sqlite => 'AUTOINCREMENT',
    mysql  => 'AUTO_INCREMENT',
);

sub _db_class_for ($class) {
    my $pkg = $class =~ /::$/ ? $class : $class;
    $pkg =~ s/::Model::/::DB::/;
    $pkg =~ s/::Model$/::DB/;
    if ($pkg =~ /^(.+::)DB::([^:]+)$/) {
        $pkg = "$1DB";
    }
    return $pkg;
}

sub _get_dbh_for {
    my ($self, $model_class) = @_;

    return $self->dbh if $self->dbh;

    my $db_class = $self->model_class // _db_class_for($model_class);

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

    croak "No database handle available. "
        . "Set dbh on schema or ensure $db_class can provide one.";
}

sub _detect_driver ( $self, $dbh = undef ) {
    return $self->driver if $self->driver;

    $dbh //= $self->dbh;
    return 'sqlite' unless $dbh;

    my $driver = eval { $dbh->{Driver}{Name} } // '';
    return 'sqlite' if $driver eq 'SQLite';
    return 'mysql'  if $driver eq 'mysql';
    return 'sqlite';
}

sub _type_for ( $self, $driver, $isa, $meta = {} ) {
    my $map = $TYPE_MAP{$driver} // $TYPE_MAP{sqlite};
    my $sql_type = $map->{$isa} // $map->{Str};

    if ($isa eq 'Str' && $driver eq 'mysql') {
        my $len = $meta->{length} // 255;
        $sql_type = "VARCHAR($len)";
    }

    return $sql_type;
}

sub _column_sql ( $self, $name, $type, $meta, $driver = undef ) {
    $driver //= $self->_detect_driver;
    my $sql = "$name ";

    $sql .= $self->_type_for($driver, $type, $meta);

    if ( $meta->{required}
        || (defined $meta->{nullable} && $meta->{nullable} eq '0') )
    {
        $sql .= ' NOT NULL';
    }

    if ( defined $meta->{default} ) {
        my $default = $meta->{default};
        if ($default =~ /\D/) {
            $default = "'$default'";
        }
        $sql .= " DEFAULT $default";
    }

    if ( $meta->{unique} ) {
        $sql .= ' UNIQUE';
    }

    return $sql;
}

sub _pk_sql ( $self, $pk, $driver = undef ) {
    $driver //= $self->_detect_driver;
    my $auto = $AUTO_INCREMENT{$driver} // $AUTO_INCREMENT{sqlite};
    return "$pk INTEGER PRIMARY KEY $auto";
}

sub _build_columns_def ( $self, $class, $driver = undef ) {
    $driver //= $self->_detect_driver;
    my @defs;

    my $attrs = $class->attributes;
    my $pk    = $class->primary_key;

    for my $attr (@$attrs) {
        next if $attr eq $pk;
        next if $attr eq 'dbh';

        my $meta = $class->column_meta($attr) // {};
        my $type = $meta->{isa} // 'Str';

        my $col_def = $self->_column_sql( $attr, $type, $meta, $driver );
        push @defs, $col_def if $col_def;
    }

    return join ', ', @defs;
}

sub _build_create_table_sql ( $self, $class, $driver = undef ) {
    $driver //= $self->_detect_driver;

    my $table       = $class->table;
    my $pk          = $class->primary_key;
    my $columns_def = $self->_build_columns_def($class, $driver);

    my $sql = "CREATE TABLE $table (";
    $sql .= $self->_pk_sql($pk, $driver);
    $sql .= ", $columns_def" if $columns_def;
    $sql .= ")";

    return $sql;
}

sub ddl_for_class ( $self, $class_name, $driver = undef ) {
    $driver //= $self->_detect_driver;
    return $self->_build_create_table_sql($class_name, $driver);
}

sub create_table_for_class ( $self, $class_name ) {
    my $dbh = $self->_get_dbh_for($class_name);
    return $self->create_table( $class_name->new( dbh => $dbh ) );
}

sub create_table ( $self, $model ) {
    my $class = ref $model;
    my $table = $class->table;
    my $dbh   = $self->dbh // $model->dbh // croak 'No database handle';

    if ( $self->table_exists($table) ) {
        return $self->migrate($model);
    }

    my $driver = $self->_detect_driver($dbh);
    my $sql    = $self->_build_create_table_sql($class, $driver);

    $dbh->do($sql);

    return 1;
}

sub table_exists ( $self, $table ) {
    my $dbh = $self->dbh // croak 'No database handle';

    my $sth  = $dbh->table_info( undef, undef, $table, undef );
    my @info = $sth->fetchrow_array;
    $sth->finish;

    return scalar(@info) > 0;
}

sub column_info ( $self, $table, $column ) {
    my $dbh = $self->dbh // croak 'No database handle';

    my $sth = $dbh->column_info( undef, undef, $table, $column );
    return undef unless $sth;

    my $info = $sth->fetchrow_hashref;
    $sth->finish;

    return $info;
}

sub table_info ( $self, $table ) {
    my $dbh = $self->dbh // croak 'No database handle';

    my $sth = $dbh->column_info( undef, undef, $table, '%' );
    return () unless $sth;

    my @columns;
    while ( my $info = $sth->fetchrow_hashref ) {
        push @columns, $info;
    }
    $sth->finish;

    return @columns;
}

sub migrate ( $self, $model ) {
    my $class = ref $model;
    my $table = $class->table;
    my $dbh   = $self->dbh // $model->dbh // croak 'No database handle';

    my $driver = $self->_detect_driver($dbh);

    my %existing;
    for my $col ( $self->table_info($table) ) {
        $existing{ $col->{COLUMN_NAME} } = 1;
    }

    my $attrs = $class->attributes;
    my $pk    = $class->primary_key;

    for my $attr (@$attrs) {
        next if $attr eq $pk;
        next if $attr eq 'dbh';
        next if $existing{$attr};

        my $meta = $class->column_meta($attr) // {};
        my $type = $meta->{isa} // 'Str';

        if ( my $col_def = $self->_column_sql($attr, $type, $meta, $driver) )
        {
            my $sql = "ALTER TABLE $table ADD COLUMN $col_def";
            $dbh->do($sql);
        }
    }

    return 1;
}

sub sync_table ( $self, $class_or_model ) {
    my $class = ref $class_or_model || $class_or_model;
    my $dbh   = $self->_get_dbh_for($class);
    my $model = $class->new( dbh => $dbh );

    $self->_ensure_schema_info_table($dbh);

    if ( !$self->table_exists( $class->table ) ) {
        $self->create_table($model);
        $self->_record_version($dbh, "Created table: $class->table");
        return ["Created table: $class->table"];
    }

    my @changes = @{$self->pending_changes($class)};

    if (@changes) {
        $self->migrate($model);
        $self->_record_version($dbh, "Migrated: $class->table");
    }

    return \@changes;
}

sub pending_changes ( $self, $class ) {
    my $class_name = ref $class || $class;
    my $table = $class_name->table;
    my $dbh   = $self->_get_dbh_for($class_name);

    my @pending;

    if ( !$self->table_exists($table) ) {
        push @pending, "Table $table does not exist";
        return \@pending;
    }

    my %existing;
    for my $col ( $self->table_info($table) ) {
        $existing{ $col->{COLUMN_NAME} } = $col;
    }

    my $attrs = $class_name->columns;
    my $pk    = $class_name->primary_key;

    for my $attr (@$attrs) {
        next if $attr eq $pk;
        next if $attr eq 'dbh';

        unless ( exists $existing{$attr} ) {
            push @pending, "ADD COLUMN $attr";
        }
    }

    if (_has_sqlt() && %existing) {
        my @sqlt_changes = $self->_sqlt_pending_changes(
            $class_name, \%existing
        );
        push @pending, @sqlt_changes;
    }

    return \@pending;
}

sub _has_sqlt {
    return eval { require SQL::Translator; 1 };
}


    }

    return @changes;
}

sub _ensure_schema_info_table ( $self, $dbh ) {
    my $table_exists = eval {
        my $sth = $dbh->table_info(undef, undef, 'schema_info', undef);
        my @info = $sth->fetchrow_array;
        $sth->finish;
        scalar @info > 0;
    };

    unless ($table_exists) {
        my $driver = $self->_detect_driver($dbh);
        my $auto   = $AUTO_INCREMENT{$driver} // $AUTO_INCREMENT{sqlite};
        $dbh->do(<<"SQL");
CREATE TABLE schema_info (
    version    INTEGER PRIMARY KEY $auto,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    change_desc TEXT
)
SQL
    }
}

sub _record_version ( $self, $dbh, $change_desc ) {
    $dbh->do(
        "INSERT INTO schema_info (change_desc) VALUES (?)",
        undef, $change_desc
    );
}

sub schema_version ($self) {
    my $dbh = $self->dbh // croak 'No database handle';
    $self->_ensure_schema_info_table($dbh);

    my $sth = $dbh->prepare("SELECT MAX(version) FROM schema_info");
    $sth->execute;
    my ($version) = $sth->fetchrow_array;
    $sth->finish;

    return $version // 0;
}

1;

__END__

=head1 NAME

ORM::Schema - Schema manager for ORM models

=head1 SYNOPSIS

    use ORM::Schema;
    use MyApp::Model::User;

    my $schema = ORM::Schema->new(dbh => $dbh);
    $schema->create_table_for_class('MyApp::Model::User');

    # Inspect DDL without executing
    my $sql = $schema->ddl_for_class('MyApp::Model::User');
    my $mysql_sql = $schema->ddl_for_class('MyApp::Model::User', 'mysql');

=head1 DESCRIPTION

ORM::Schema manages database tables based on ORM model definitions.
It supports multiple database systems (SQLite and MySQL/MariaDB) by
generating dialect-specific DDL from model column definitions.

=head1 ATTRIBUTES

=over 4

=item * dbh - Database handle (optional if model_class is set)

=item * model_class - Model class name for auto-deriving dbh

=item * driver - Override database driver detection ('sqlite' or 'mysql')

=back

=head1 METHODS

=head2 ddl_for_class

    my $sql = $schema->ddl_for_class('MyApp::Model::User');
    my $sql = $schema->ddl_for_class('MyApp::Model::User', 'mysql');

Returns the CREATE TABLE DDL for a model class without executing it.
Optionally pass a driver name to generate DDL for a specific database.

=head2 create_table_for_class

    $schema->create_table_for_class('MyApp::Model::User');

Creates a table for the given model class. If the table already exists,
runs migrate instead.

=head2 create_table

    $schema->create_table(MyApp::Model::User->new);

Creates a table from a model instance.

=head2 table_exists

    if ($schema->table_exists('users')) { ... }

Returns true if the table exists in the database.

=head2 column_info

    my $info = $schema->column_info('users', 'email');

Returns column metadata from the database.

=head2 table_info

    my @columns = $schema->table_info('users');

Returns all column metadata for a table.

=head2 migrate

    $schema->migrate(MyApp::Model::User->new);

Adds missing columns to an existing table.

=head2 sync_table

    my $changes = $schema->sync_table('MyApp::Model::User');

Creates or migrates a table to match the model definition.

=head2 pending_changes

    my @pending = @{$schema->pending_changes('MyApp::Model::User')};

Returns a list of pending schema changes. If SQL::Translator is
available, also reports type mismatches.

=head2 schema_version

    my $version = $schema->schema_version;

Returns the current schema version number.

=head1 MULTI-DATABASE SUPPORT

ORM::Schema detects the database driver from the DBI handle and
generates appropriate DDL. You can also override the driver explicitly:

    my $schema = ORM::Schema->new(dbh => $dbh, driver => 'mysql');

Supported drivers:

=over 4

=item * sqlite - SQLite (default)

=item * mysql - MySQL / MariaDB

=back

=head2 Type Mapping

    | ORM Type  | SQLite  | MySQL        |
    |-----------|---------|--------------|
    | Int       | INTEGER | INTEGER      |
    | Str       | TEXT    | VARCHAR(n)   |
    | Text      | TEXT    | TEXT         |
    | Bool      | INTEGER | TINYINT(1)   |
    | Float     | REAL    | DOUBLE       |
    | Timestamp | TEXT    | TIMESTAMP    |

For Str columns on MySQL, the length defaults to 255 and can be set
via the C<length> option in the column definition.

=head1 OPTIONAL SQL::TRANSLATOR SUPPORT

If L<SQL::Translator> is installed, C<pending_changes> will also detect
type mismatches between the model definition and the database. Without
SQL::Translator, only missing columns are reported.

=cut
