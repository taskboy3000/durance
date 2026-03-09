package ORM::Schema;
use strict;
use warnings;
use Mojo::Base -base, -signatures;
use Carp qw(croak);

has 'dbh';

=head1 NAME

ORM::Schema - Schema manager for ORM models

=head1 SYNOPSIS

    use ORM::Schema;
    use MyApp::Model::User;
    
    my $schema = ORM::Schema->new(dbh => $dbh);
    $schema->create_table(MyApp::Model::User->new);
    
    # Or use class directly
    $schema->create_table_for_class('MyApp::Model::User');

=head1 DESCRIPTION

ORM::Schema manages database tables based on ORM model definitions.
It can create tables, add columns, and modify schema to match model definitions.

=head1 ATTRIBUTES

=over 4

=item * dbh - Database handle (required)

=back

=head1 METHODS

=head2 new(%attributes)

Create a new ORM::Schema instance.

    my $schema = ORM::Schema->new(dbh => $dbh);

=head2 $schema->create_table_for_class($class_name)

Create a table for the given model class.

    $schema->create_table_for_class('MyApp::Model::User');

=head2 $schema->create_table($model_instance)

Create a table based on a model instance.

    $schema->create_table($user);

=head2 $schema->table_exists($table_name)

Check if a table exists.

    if ($schema->table_exists('users')) {
        # table exists
    }

=head2 $schema->column_info($table, $column)

Get information about a column.

    my $info = $schema->column_info('users', 'name');

=head2 $schema->table_info($table)

Get all columns for a table.

    my @columns = $schema->table_info('users');

=head2 $schema->migrate($model_class)

Migrate table to match model definition (add missing columns).

    $schema->migrate('MyApp::Model::User');

=cut

sub create_table_for_class ( $self, $class_name ) {
    my $table   = $class_name->can('table') ? $class_name->table : $class_name;
    my $columns = $class_name->can('columns') ? $class_name->columns : [];

    return $self->create_table( $class_name->new( dbh => $self->dbh ) );
}

sub create_table ( $self, $model ) {
    my $class = ref $model;
    my $table = $class->table;
    my $dbh   = $self->dbh // $model->dbh // croak 'No database handle';

    if ( $self->table_exists($table) ) {
        return $self->migrate($model);
    }

    my $columns_def = $self->_build_columns_def($class);
    my $pk          = $class->primary_key;

    my $sql = "CREATE TABLE $table (";
    $sql .= "$pk INTEGER PRIMARY KEY AUTOINCREMENT, " if $pk eq 'id';
    $sql .= $columns_def;
    $sql .= ")";

    $dbh->do($sql);

    return 1;
}

sub _build_columns_def ( $self, $class ) {
    my @defs;

    my $attrs = $class->attributes;
    my $pk    = $class->primary_key;

    for my $attr (@$attrs) {
        next if $attr eq $pk;
        next if $attr eq 'dbh';

        my $meta = $class->$attr // {};
        my $type = $meta->{isa}  // 'Str';

        my $col_def = $self->_column_sql( $attr, $type, $meta );
        push @defs, $col_def if $col_def;
    }

    return join ', ', @defs;
}

sub _column_sql ( $self, $name, $type, $meta ) {
    my $sql = "$name ";

    $type = lc $type;

    if ( $type =~ /int/i ) {
        $sql .= 'INTEGER';
    }
    elsif ( $type =~ /num|real|float|double/i ) {
        $sql .= 'REAL';
    }
    elsif ( $type =~ /bool/i ) {
        $sql .= 'INTEGER';
    }
    else {
        $sql .= 'TEXT';
    }

    if ( $meta->{required} || $meta->{nullable} eq '0' ) {
        $sql .= ' NOT NULL';
    }

    if ( $meta->{default} ) {
        my $default = $meta->{default};
        $default = "'$default'" if $default =~ /\D/;
        $sql .= " DEFAULT $default";
    }

    if ( $meta->{unique} ) {
        $sql .= ' UNIQUE';
    }

    return $sql;
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

        my $meta = $class->$attr // {};
        my $type = $meta->{isa}  // 'Str';

        if ( my $col_def = $self->_column_sql( $attr, $type, $meta ) ) {
            my $sql = "ALTER TABLE $table ADD COLUMN $col_def";
            $dbh->do($sql);
        }
    }

    return 1;
}

1;

=head1 AUTHOR

ORM Framework

=head1 LICENSE

MIT

=cut
