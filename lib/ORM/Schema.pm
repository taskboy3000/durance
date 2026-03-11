package ORM::Schema;
use strict;
use warnings;
use Mojo::Base '-base', '-signatures';
use Carp qw(croak);

has 'dbh';
has 'model_class';

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
    
    croak "No database handle available. Set dbh on schema or ensure $db_class can provide one.";
}

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

=head2 $schema->sync_table($model_class)

Sync table schema (create if not exists, migrate if needed).

    $schema->sync_table('MyApp::Model::User');

=head2 $schema->pending_changes($model_class)

Check for pending schema changes.

    my @pending = @{$schema->pending_changes('MyApp::Model::User')};

=head2 $schema->schema_version

Get the current schema version.

    my $version = $schema->schema_version;

=head1 AUTOMATIC DBH DERIVATION

ORM::Schema can automatically derive the database handle from the model class.
Given a model like C<MyApp::Model::User>, it will look for C<MyApp::DB> and
call C<< MyApp::DB->dbh >> to get the connection.

    # These are equivalent:
    my $schema = ORM::Schema->new(dbh => $dbh);
    my $schema = ORM::Schema->new(model_class => 'MyApp::Model::User');
    my $schema = ORM::Schema->new();  # Derives from context

=cut

sub create_table_for_class ( $self, $class_name ) {
    my $table   = $class_name->can('table') ? $class_name->table : $class_name;
    my $columns = $class_name->can('columns') ? $class_name->columns : [];
    my $dbh     = $self->_get_dbh_for($class_name);

    return $self->create_table( $class_name->new( dbh => $dbh ) );
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
    if ($pk eq 'id') {
        $sql .= "$pk INTEGER PRIMARY KEY AUTOINCREMENT";
        $sql .= ", $columns_def" if $columns_def;
    }
    else {
        $sql .= $columns_def;
    }
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

    if ( $meta->{required} || (defined $meta->{nullable} && $meta->{nullable} eq '0') ) {
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

    return \@pending;
}

sub _ensure_schema_info_table ( $self, $dbh ) {
    my $table_exists = eval {
        my $sth = $dbh->table_info(undef, undef, 'schema_info', undef);
        my @info = $sth->fetchrow_array;
        $sth->finish;
        scalar @info > 0;
    };

    unless ($table_exists) {
        $dbh->do(<<SQL);
CREATE TABLE schema_info (
    version   INTEGER PRIMARY KEY AUTOINCREMENT,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    change_desc TEXT
)
SQL
    }
}

sub _record_version ( $self, $dbh, $change_desc ) {
    $dbh->do("INSERT INTO schema_info (change_desc) VALUES (?)", undef, $change_desc);
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

=head1 AUTHOR

ORM Framework

=head1 LICENSE

MIT

=cut
