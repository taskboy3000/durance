# All code Joe Johnston <jjohn@taskboy.com> 2026
package Durance::QueryBuilder;
use strict;
use warnings;
use experimental 'signatures';

use Moo;

has 'class' => (is => 'ro', required => 1);
has 'driver' => (is => 'rw', default => 'SQLite');

sub build_where ($self, $conditions = {}) {
    my @where_parts;
    my @bind_values;

    for my $col (keys %$conditions) {
        my $val = $conditions->{$col};
        if (ref $val eq 'HASH') {
            for my $op (keys %$val) {
                push @where_parts, "$col $op ?";
                push @bind_values, $val->{$op};
            }
        }
        else {
            push @where_parts, "$col = ?";
            push @bind_values, $val;
        }
    }

    my $where_clause = @where_parts ? join(' AND ', @where_parts) : '';

    return (wantarray ? ($where_clause, \@bind_values) : $where_clause);
}

sub build_joins ($self, $join_specs = []) {
    my $class = $self->class;
    my $table = $class->table;
    my @join_parts;

    return @join_parts unless @$join_specs;

    for my $rel (@$join_specs) {
        my ($rel_name, $rel_opts);

        if (ref $rel eq 'HASH') {
            ($rel_name, $rel_opts) = %$rel;
        }
        else {
            $rel_name = $rel;
            $rel_opts = {};
        }

        my $meta = $class->related_to($rel_name);

        if ($meta && ref $meta eq 'HASH') {
            my $join_type = $rel_opts->{type} // 'LEFT';
            my $related_class = $meta->{isa};
            my $related_table = $related_class->table;
            my $local_pk = $class->primary_key;

            my $already_joined = 0;
            for my $existing (@join_parts) {
                if ($existing =~ /\b$related_table\b/) {
                    $already_joined = 1;
                    last;
                }
            }
            next if $already_joined;

            my $on_clause;
            if ($meta->{_relationship_type} eq 'belongs_to') {
                my $foreign_key = $meta->{foreign_key} // "${rel_name}_id";
                $on_clause = "$related_table.id = $table.$foreign_key";
            }
            else {
                my $foreign_key = $meta->{foreign_key} // "${rel_name}_id";
                $on_clause = "$related_table.$foreign_key = $table.$local_pk";
            }

            $on_clause = $rel_opts->{on} // $on_clause;
            
            $self->_validate_on_clause($on_clause) if $rel_opts->{on};
            
            push @join_parts, "$join_type JOIN $related_table ON $on_clause";
        }
        elsif ($rel_opts && $rel_opts->{on}) {
            my $join_type = $rel_opts->{type} // 'LEFT';
            my $related_table = $rel_opts->{table} // $rel_name;

            my $already_joined = 0;
            for my $existing (@join_parts) {
                if ($existing =~ /\b$related_table\b/) {
                    $already_joined = 1;
                    last;
                }
            }
            unless ($already_joined) {
                $self->_validate_on_clause($rel_opts->{on});
                push @join_parts, "$join_type JOIN $related_table ON $rel_opts->{on}";
            }
        }
    }

    return @join_parts;
}

sub _validate_on_clause ($self, $on_clause) {
    return unless defined $on_clause;
    
    if ($on_clause =~ /;/ || $on_clause =~ /--/ || $on_clause =~ /\bDROP\b/i ||
        $on_clause =~ /\bDELETE\b/i || $on_clause =~ /\bINSERT\b/i ||
        $on_clause =~ /\bUPDATE\b/i || $on_clause =~ /\bSELECT\b/i) {
        die "Invalid ON clause: contains potentially unsafe SQL patterns. "
            . "Semicolons, comments, and DML/DDL statements are not allowed.";
    }
    
    unless ($on_clause =~ /^[a-zA-Z0-9_\.\s\(\)\=\>\<\!\,\-\+\'\"\(\)]+$/) {
        die "Invalid ON clause: contains unsupported characters.";
    }
    
    unless ($on_clause =~ /^[^\)]*(\([^\)]*\)|[^\(\)])*[^\)]*$/) {
        die "Invalid ON clause: unbalanced parentheses.";
    }
}

sub _get_aliased_columns ($self) {
    my $class = $self->class;
    my $main_table = $class->table;
    my @col_specs;
    
    my $main_cols = $class->columns;
    for my $col (@$main_cols) {
        push @col_specs, "$main_table.$col AS ${main_table}__$col";
    }
    
    return wantarray ? @col_specs : \@col_specs;
}

sub needs_distinct ($self, $join_specs = []) {
    return 0 unless @$join_specs;

    my $class = $self->class;

    for my $rel (@$join_specs) {
        my $rel_name;

        if (ref $rel eq 'HASH') {
            ($rel_name) = keys %$rel;
        }
        else {
            $rel_name = $rel;
        }

        my $meta = $class->related_to($rel_name);
        if ($meta && $meta->{_relationship_type} eq 'has_many') {
            return 1;
        }
    }

    return 0;
}

sub build_select ($self, $options = {}) {
    my $class = $self->class;
    my $table = $class->table;
    
    my $conditions = $options->{conditions} // {};
    my $order_by   = $options->{order_by} // [];
    my $limit_val  = $options->{limit_val};
    my $offset_val = $options->{offset_val};
    my $join_specs = $options->{join_specs} // [];
    
    my ($where_clause, $bind_values) = $self->build_where($conditions);
    
    my $columns_str;
    if (@$join_specs) {
        my @columns = $self->_get_aliased_columns();
        $columns_str = join(', ', @columns);
    }
    else {
        $columns_str = '*';
    }
    
    my $sql = "SELECT $columns_str FROM $table";
    
    my @join_parts = $self->build_joins($join_specs);
    $sql .= " " . join(' ', @join_parts) if @join_parts;
    
    $sql .= " WHERE " . $where_clause if $where_clause;
    $sql .= " ORDER BY " . join(', ', @$order_by) if @$order_by;
    
    if (defined $limit_val) {
        $sql .= " " . $self->_format_limit($limit_val, $offset_val);
    }
    elsif (defined $offset_val) {
        $sql .= " " . $self->_format_limit(1000000, $offset_val);
    }
    
    return (wantarray ? ($sql, $bind_values) : $sql);
}

sub build_count ($self, $options = {}) {
    my $class = $self->class;
    my $table = $class->table;
    
    my $conditions = $options->{conditions} // {};
    my $join_specs = $options->{join_specs} // [];
    
    my ($where_clause, $bind_values) = $self->build_where($conditions);
    
    my @join_parts = $self->build_joins($join_specs);
    
    my $needs_distinct = $self->needs_distinct($join_specs);
    my $pk = $class->primary_key;
    my $count_expr = $needs_distinct 
        ? "COUNT(DISTINCT $table.$pk)" 
        : "COUNT(*)";
    
    my $sql = "SELECT $count_expr FROM $table";
    $sql .= " " . join(' ', @join_parts) if @join_parts;
    $sql .= " WHERE " . $where_clause if $where_clause;
    
    return (wantarray ? ($sql, $bind_values) : $sql);
}

sub _format_limit ($self, $limit, $offset) {
    my $driver = $self->driver;
    
    if ($driver eq 'mysql' || $driver eq 'mariadb') {
        if (defined $offset) {
            return "LIMIT $offset, $limit";
        }
        return "LIMIT $limit";
    }
    
    my $sql = "LIMIT $limit";
    $sql .= " OFFSET $offset" if defined $offset;
    return $sql;
}

sub driver_from_dsn ($self, $dsn) {
    return 'SQLite' unless defined $dsn;
    
    if ($dsn =~ /dbi:SQLite/i) {
        return 'SQLite';
    }
    elsif ($dsn =~ /dbi:mysql/i) {
        return 'mysql';
    }
    elsif ($dsn =~ /dbi:mariadb/i) {
        return 'mariadb';
    }
    elsif ($dsn =~ /dbi:Pg/i) {
        return 'PostgreSQL';
    }
    
    return 'SQLite';
}

our $VERSION = '0.01';

1;

=pod

=head1 NAME

Durance::QueryBuilder - SQL query building abstraction

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

Provides SQL query building methods with driver-aware SQL generation.
Extracted from ResultSet to comply with Single Responsibility Principle.

=head1 ATTRIBUTES

=over 4

=item * class - The model class (required, read-only)

=item * driver - Database driver: 'SQLite', 'mysql', 'mariadb', 'PostgreSQL' (default: 'SQLite')

=back

=head1 METHODS

=head2 build_where

    my ($where_clause, $bind_values) = $qb->build_where({ status => 'active', age => { '>' => 21 } });

Generates WHERE clause from conditions hashref. Returns clause and bind values.

=head2 build_joins

    my @joins = $qb->build_joins(['company', 'posts']);

Generates JOIN clauses from join specifications.

=head2 build_select

    my ($sql, $bind_values) = $qb->build_select({
        conditions => { active => 1 },
        order_by   => ['name'],
        limit_val  => 10,
        offset_val => 20,
        join_specs => ['company'],
    });

Generates complete SELECT SQL with all clauses.

=head2 build_count

    my ($sql, $bind_values) = $qb->build_count({
        conditions => { active => 1 },
        join_specs => ['company'],
    });

Generates COUNT SQL, automatically using DISTINCT for has_many joins.

=head2 needs_distinct

    my $needs = $qb->needs_distinct($join_specs);

Returns true if any join_spec contains a has_many relationship.

=head2 driver_from_dsn

    my $driver = $qb->driver_from_dsn($dsn);

Extracts driver type from DSN string.

=head1 AUTHOR

Joe Johnston <jjohn@taskboy.com>

=head1 LICENSE

Perl Artistic License

=cut
