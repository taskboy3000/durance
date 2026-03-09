package ORM::Base;
use strict;
use warnings;

use DBI;
use Carp qw(croak);
use FindBin;
use Mojo::Base ('-base', '-signatures');

our $gDBH;
our ( %_table, %_columns, %_primary_key, %_dbh, %_dbname,
    %COLUMN_META );

has 'dbname' => "$FindBin::Bin/../../../app.db";
has primaryKey => 'id';

sub dbh ( $self ) {
    if ( defined $gDBH) {
        return $gDBH;
    }

    $gDBH = DBI->new(
            "dbi:SQLite:dbname=" . $self->dbname, # This is a global config value
            '', '',
            {
                RaiseError => 1,
                AutoCommit => 1,
            }
    );

    if (!$gDBH) {
        croak("DBH: " . DBI->errstr);
    }

    return $gDBH;
}


sub import ($class) {
    my $callerPkg = caller;

    no strict 'refs';

    *{"${callerPkg}::column"} = sub ( $name, @opts ) {
        my %opts = @opts;
        my $pkg = caller;

        $_columns{$pkg} //= [];
        push @{ $_columns{$pkg} }, $name;

        $COLUMN_META{$pkg}{$name} = \%opts;

        if ( $opts{primary_key} ) {
            $callerPkg->primaryKey($name);
        }

        my $is = $opts{is} // 'rw';

        # Make the attribute accessors
        if ( $is eq 'ro' ) {
            *{"${pkg}::${name}"} = sub ($self) {
                return $self->{$name};
            };
        } else {
            *{"${pkg}::${name}"} = sub ($self, $val = undef) {
                if ( defined $val ) {
                    return $self->{$name} = $val;
                }
                return $self->{$name};
            };
        }

        return;
    };
    use strict;
}


# The SQL table is the name of the last part of the perl package name
sub table ($self) {
    my $callerPkg = ref $self || $self;
    my ($tableName) = ($callerPkg =~ /::([^:]+)$/);
    $tableName = lc ($tableName);
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


sub find ( $class, $id ) {
    my $pk    = $class->primary_key;
    my $table = $class->table;
    my $dbh   = $class->dbh // croak 'No database handle';

    my $stmt = "SELECT * FROM $table WHERE $pk = ?";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute($id);

    my $row = $sth->fetchrow_hashref;
    $sth->finish;

    my @found;
    return \@found unless $row;

    # Convert rows into objects
    while (my $row = $sth->fetchrow_hashref) {
        push @found, $class->new(%$row);
    }
    return \@found;
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
          $class->new( %$row, dbh => $dbh, dbname => $class->dbname );
    }
    $sth->finish;

    return \@rows;
}


sub where ( $class, $conditions ) {
    my $table = $class->table;
    my $dbh   = $class->dbh // croak 'No database handle';

    return $class->all unless $conditions && %$conditions;

    my @cols  = keys %$conditions;
    my @vals  = values %$conditions;
    my $where = join ' AND ', map {"$_ = ?"} @cols;

    my $stmt = "SELECT * FROM $table WHERE $where";
    my $sth  = $dbh->prepare($stmt);
    $sth->execute(@vals);

    my @rows;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @rows,
          $class->new( %$row, dbh => $dbh, dbname => $class->dbname );
    }
    $sth->finish;

    return @rows;
}


sub create ( $class, $data ) {
    my $dbh = $class->dbh // croak 'No database handle';

    return $class->new( %$data, dbh => $dbh, dbname => $class->dbname )
      ->insert;
}


sub _columns_info ($class) {
    return {};
}

sub insert ($self) {
    my $table = ref($self)->table;
    my $dbh   = $self->dbh // croak 'No database handle';

    my @cols =
      grep { defined $self->{$_} && $_ ne 'dbh' && $_ ne 'dbname' }
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

    my @cols =
      grep {
             defined $self->{$_}
          && $_ ne 'dbh'
          && $_ ne 'dbname'
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
    delete $hash{dbname};
    delete $hash{$_} for grep { !defined $self->{$_} } keys %hash;
    return \%hash;
}

1;
