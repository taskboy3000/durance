package Durance::DDL;
use strict;
use warnings;
use experimental 'signatures';

use Moo;

has 'driver' => (is => 'rw', required => 1);

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
    mariadb => {
        Int       => 'INTEGER',
        Str       => 'VARCHAR',
        Text      => 'TEXT',
        Bool      => 'TINYINT(1)',
        Float     => 'DOUBLE',
        Timestamp => 'TIMESTAMP',
    },
);

my %AUTO_INCREMENT = (
    sqlite  => 'AUTOINCREMENT',
    mysql   => 'AUTO_INCREMENT',
    mariadb => 'AUTO_INCREMENT',
);

sub driver_from_dsn ($self, $dsn) {
    return 'sqlite' unless $dsn;

    my ($driver) = $dsn =~ /^dbi:(\w+):/i;
    return 'sqlite' unless $driver;

    $driver = lc $driver;
    return 'mysql' if $driver eq 'mysql';
    return 'mariadb' if $driver eq 'mariadb';
    return 'sqlite';
}

sub _type_for ($self, $isa, $meta = {}) {
    my $driver = $self->driver;
    my $map = $TYPE_MAP{$driver} // $TYPE_MAP{sqlite};
    my $sql_type = $map->{$isa} // $map->{Str};

    if ($isa eq 'Str' && ($driver eq 'mysql' || $driver eq 'mariadb')) {
        my $len = $meta->{length} // 255;
        $sql_type = "VARCHAR($len)";
    }

    return $sql_type;
}

sub _column_sql ($self, $name, $type, $meta = {}) {
    my $driver = $self->driver;
    my $sql = "$name ";

    $sql .= $self->_type_for($type, $meta);

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

sub _pk_sql ($self, $pk) {
    my $auto = $AUTO_INCREMENT{$self->driver} // $AUTO_INCREMENT{sqlite};
    return "$pk INTEGER PRIMARY KEY $auto";
}

sub _build_columns_def ($self, $class) {
    my @defs;

    my $attrs = $class->attributes;
    my $pk    = $class->primary_key;

    for my $attr (@$attrs) {
        next if $attr eq $pk;
        next if $attr eq 'dbh';

        my $meta = $class->column_meta($attr) // {};
        my $type = $meta->{isa} // 'Str';

        my $col_def = $self->_column_sql( $attr, $type, $meta );
        push @defs, $col_def if $col_def;
    }

    return join ', ', @defs;
}

sub build_create_table_sql ($self, $class) {
    my $table       = $class->table;
    my $pk          = $class->primary_key;
    my $columns_def = $self->_build_columns_def($class);

    my $sql = "CREATE TABLE $table (";
    $sql .= $self->_pk_sql($pk);
    $sql .= ", $columns_def" if $columns_def;
    $sql .= ")";

    return $sql;
}

sub build_alter_table_add_column ($self, $table, $attr, $type, $meta = {}) {
    my $col_def = $self->_column_sql($attr, $type, $meta);
    return "ALTER TABLE $table ADD COLUMN $col_def";
}

sub ddl_for_class ($self, $class_name) {
    return $self->build_create_table_sql($class_name);
}

our $VERSION = '0.01';

1;

=pod

=head1 NAME

Durance::DDL - Driver-aware SQL DDL generation

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

Generates driver-specific SQL DDL (CREATE TABLE, ALTER TABLE) for Durance ORM models.
Supports SQLite, MySQL, and MariaDB with driver-aware type mapping.

=head1 ATTRIBUTES

=over 4

=item * driver - Database driver ('sqlite', 'mysql', or 'mariadb') - required

=back

=head1 METHODS

=head2 driver_from_dsn

    my $driver = Durance::DDL->driver_from_dsn('dbi:mysql:database=test');

Extracts driver type from a DBI DSN string.

=head2 ddl_for_class

    my $sql = $ddl->ddl_for_class('MyApp::Model::User');

Returns the CREATE TABLE DDL for a model class.

=head2 build_create_table_sql

    my $sql = $ddl->build_create_table_sql($model_class);

Returns the CREATE TABLE SQL for a model class.

=head2 build_alter_table_add_column

    my $sql = $ddl->build_alter_table_add_column('users', 'email', 'Str', { required => 1 });

Returns the ALTER TABLE ADD COLUMN SQL for adding a column.

=head1 TYPE MAPPING

| ORM Type  | SQLite  | MySQL/MariaDB |
|-----------|---------|---------------|
| Int       | INTEGER | INTEGER       |
| Str       | TEXT    | VARCHAR(n)    |
| Text      | TEXT    | TEXT          |
| Bool      | INTEGER | TINYINT(1)    |
| Float     | REAL    | DOUBLE        |
| Timestamp | TEXT    | TIMESTAMP     |

For Str columns on MySQL/MariaDB, the length defaults to 255 and can be set
via the C<length> option in the column definition.

=head1 AUTHOR

Joe Johnston <jjohn@taskboy.com>

=head1 LICENSE

Perl Artistic License

=cut
