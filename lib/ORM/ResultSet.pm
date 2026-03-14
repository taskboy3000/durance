# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package ORM::ResultSet;
use strict;
use warnings;
use experimental 'signatures';
use Moo;
use Time::HiRes qw(time);

has 'class' => (is => 'ro', required => 1);
has 'conditions' => (is => 'rw', default => sub { {} });
has 'order_by' => (is => 'rw', default => sub { [] });
has 'limit_val' => (is => 'rw');
has 'offset_val' => (is => 'rw');
has 'join_specs' => (is => 'rw', default => sub { [] });

has 'logger' => (is => 'lazy');
sub _build_logger ($self) {
    require ORM::Logger;
    return ORM::Logger->new;
}

sub add_joins ($self, @relations) {
    my $class = $self->class;

    for my $rel (@relations) {
        # Only validate string relationship names.
        # Hash refs are explicit overrides -- trust the user.
        next if ref $rel;

        my $meta = $class->related_to($rel);
        unless ($meta) {
            my $class_name = ref $class || $class;
            my $all_rels = $class->all_relations;

            my $msg = "Invalid JOIN: '$class_name' has no"
                    . " relationship named '$rel'\n";

            if (keys %$all_rels) {
                $msg .= "Available relationships:\n";
                for my $name (sort keys %$all_rels) {
                    $msg .= "  - $name ($all_rels->{$name})\n";
                }
            }
            else {
                $msg .= "$class_name has no defined"
                       . " relationships.\n"
                       . "Define relationships with"
                       . " has_many or belongs_to"
                       . " in your model.\n";
            }

            die $msg;
        }
    }

    push @{$self->join_specs}, @relations;
    return $self;
}

sub order ($self, $order) {
    push @{$self->order_by}, $order;
    return $self;
}

sub limit ($self, $limit) {
    $self->limit_val($limit);
    return $self;
}

sub offset ($self, $offset) {
    $self->offset_val($offset);
    return $self;
}

sub all ($self) {
    my $class = $self->class;
    my $table = $class->table;
    my $dbh   = $class->db->dbh;

    my @where_parts;
    my @bind_values;

    for my $col (keys %{$self->conditions}) {
        my $val = $self->conditions->{$col};
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

    my $sql = "SELECT * FROM $table";

    # Build JOIN clauses
    my @join_parts = $self->_build_join_sql();
    $sql .= " " . join(' ', @join_parts) if @join_parts;

    $sql .= " WHERE " . join(' AND ', @where_parts) if @where_parts;
    $sql .= " ORDER BY " . join(', ', @{$self->order_by}) if @{$self->order_by};
    if (defined $self->limit_val) {
        $sql .= " LIMIT " . $self->limit_val;
    }
    elsif (defined $self->offset_val) {
        $sql .= " LIMIT 1000000";
    }
    $sql .= " OFFSET " . $self->offset_val if defined $self->offset_val;

    my $start = time();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind_values);
    my $duration = (time() - $start) * 1000;
    
    if ($ENV{ORM_SQL_LOGGING}) {
        my $logger = ORM::Logger->new;
        my $params_str = @bind_values ? '[' . join(', ', map { !defined $_ ? 'NULL' : /^\d+$/ ? $_ : "'$_'" } @bind_values) . ']' : '';
        $logger->log("SQL (" . sprintf("%.3f", $duration) . " ms): $sql $params_str");
    }

    my @rows;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @rows, $class->new(%$row, db => $class->db);
    }
    $sth->finish;

    return wantarray ? @rows : \@rows;
}

sub first ($self) {
    my @rows = $self->limit(1)->all;
    return $rows[0];
}

sub _build_join_sql ($self) {
    my $class = $self->class;
    my $table = $class->table;
    my @join_parts;

    for my $rel (@{$self->join_specs}) {
        my ($rel_name, $rel_opts);

        if (ref $rel eq 'HASH') {
            ($rel_name, $rel_opts) = %$rel;
        }
        else {
            $rel_name = $rel;
            $rel_opts = {};
        }

        # Look up relationship metadata
        my $meta = $class->related_to($rel_name);

        # If no metadata found and it's a hash override, use explicit settings
        if ($meta && ref $meta eq 'HASH') {
            # Determine JOIN type (default LEFT)
            my $join_type = $rel_opts->{type} // 'LEFT';

            # Determine tables and keys
            my $related_class = $meta->{isa};
            my $related_table = $related_class->table;
            my $local_pk = $class->primary_key;
            my $local_table = $table;

            # Skip if this table is already joined (avoid duplicates)
            my $already_joined = 0;
            for my $existing (@join_parts) {
                if ($existing =~ /\b$related_table\b/) {
                    $already_joined = 1;
                    last;
                }
            }
            next if $already_joined;

            # Build ON clause based on relationship type
            my $on_clause;
            if ($meta->{_relationship_type} eq 'belongs_to') {
                # belongs_to: foreign key is on local table
                # e.g., Employee belongs_to Company: employees.company_id = companies.id
                my $foreign_key = $meta->{foreign_key} // "${rel_name}_id";
                $on_clause = "$related_table.id = $local_table.$foreign_key";
            }
            else {
                # has_many: foreign key is on related table
                # e.g., Company has_many Employees: employees.company_id = companies.id
                my $foreign_key = $meta->{foreign_key} // "${rel_name}_id";
                $on_clause = "$related_table.$foreign_key = $local_table.$local_pk";
            }

            # Allow override
            $on_clause = $rel_opts->{on} // $on_clause;

            push @join_parts, "$join_type JOIN $related_table ON $on_clause";
        }
        elsif ($rel_opts && $rel_opts->{on}) {
            # Explicit override without metadata - use explicit settings
            my $join_type = $rel_opts->{type} // 'LEFT';
            my $related_table = $rel_opts->{table} // $rel_name;

            # Skip if this table is already joined (avoid duplicates)
            my $already_joined = 0;
            for my $existing (@join_parts) {
                if ($existing =~ /\b$related_table\b/) {
                    $already_joined = 1;
                    last;
                }
            }
            unless ($already_joined) {
                push @join_parts, "$join_type JOIN $related_table ON $rel_opts->{on}";
            }
        }
    }

    return @join_parts;
}

sub _needs_distinct ($self) {
    # Return true if any join_specs include has_many relationships
    my $class = $self->class;

    for my $rel (@{$self->join_specs}) {
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

sub count ($self) {
    my $class = $self->class;
    my $table = $class->table;
    my $dbh   = $class->db->dbh;

    my @where_parts;
    my @bind_values;

    for my $col (keys %{$self->conditions}) {
        my $val = $self->conditions->{$col};
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

    # Build JOIN clauses
    my @join_parts = $self->_build_join_sql();

    # Determine if we need DISTINCT
    my $needs_distinct = $self->_needs_distinct();
    my $count_expr = $needs_distinct ? "COUNT(DISTINCT $table." . $class->primary_key . ")" : "COUNT(*)";

    my $sql = "SELECT $count_expr FROM $table";
    $sql .= " " . join(' ', @join_parts) if @join_parts;
    $sql .= " WHERE " . join(' AND ', @where_parts) if @where_parts;

    my $start = time();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind_values);
    my $duration = (time() - $start) * 1000;
    
    if ($ENV{ORM_SQL_LOGGING}) {
        my $logger = ORM::Logger->new;
        my $params_str = @bind_values ? '[' . join(', ', map { !defined $_ ? 'NULL' : /^\d+$/ ? $_ : "'$_'" } @bind_values) . ']' : '';
        $logger->log("SQL (" . sprintf("%.3f", $duration) . " ms): $sql $params_str");
    }
    
    my ($count) = $sth->fetchrow_array;
    $sth->finish;

    return $count;
}

1;

__END__

=head1 NAME

ORM::ResultSet - Result set for chainable queries

=head1 SYNOPSIS

    # Create a result set
    my $rs = MyApp::Model::User->where({ active => 1 });

    # Chain methods
    my $rs = MyApp::Model::User->where({ age => { '>=' => 18 }})
                               ->order('name')
                               ->limit(10)
                               ->offset(20);

    # Execute
    my @users = $rs->all;
    my $user = $rs->first;
    my $count = $rs->count;

    # In list context, all() is called automatically
    my @users = MyApp::Model::User->where({ active => 1 })->order('name');

=head1 DESCRIPTION

ORM::ResultSet provides chainable query methods for ORM models.
It lazily executes queries until methods like C<all>, C<first>, or C<count> are called.

=head1 ATTRIBUTES

=over 4

=item * class - The model class (required, read-only)

=item * conditions - Hashref of query conditions (read-write)

=item * order_by - Arrayref of ORDER BY clauses (read-write)

=item * limit_val - LIMIT value (read-write)

=item * offset_val - OFFSET value (read-write)

=item * join_specs - Arrayref of JOIN specifications (read-write)

=back

=head1 METHODS

=head2 where

    my $rs = $rs->where({ status => 'active' });

Add conditions to the query. Can be called multiple times to add more conditions.

    $rs->where({ age => 30 })->where({ active => 1 });

Supports hashrefs for operators:

    { age => { '>' => 21 } }     # age > 21
    { age => { '>=' => 21 } }    # age >= 21
    { age => { '<' => 65 } }     # age < 65
    { name => { 'LIKE' => 'J%' } } # name LIKE 'J%'

=head2 order

    my $rs = $rs->order('name');
    my $rs = $rs->order('name DESC');
    my $rs = $rs->order('age ASC', 'name DESC');

Add ORDER BY clause. Can be called multiple times.

=head2 limit

    my $rs = $rs->limit(10);

Add LIMIT clause.

=head2 offset

    my $rs = $rs->offset(20);

Add OFFSET clause. Note: Most databases require LIMIT when using OFFSET.

=head2 add_joins

    my $rs = $rs->add_joins('company');
    my $rs = $rs->add_joins('company', 'department');
    my $rs = $rs->add_joins({ company => {
        type => 'INNER',
        on   => 'companies.id = employees.company_id',
    }});

Add SQL JOIN clauses to the query. Supports two forms:

=over 4

=item * B<String API> - Relationship names that match defined
C<has_many> or C<belongs_to> relationships.  If the name does not
match any known relationship, C<add_joins> will C<die> immediately
with an error listing the available relationships.

=item * B<Hash API> - Explicit override with custom JOIN type and
ON clause.  Hash refs are B<not validated> against the model's
relationships, so you can join arbitrary tables this way.

=back

Returns C<$self> for method chaining.

B<Error behavior (string API only):>

    # Dies immediately:
    MyApp::Model::User->where({})
        ->add_joins('nonexistent')
        ->all;

    # Error message:
    # Invalid JOIN: 'MyApp::Model::User' has no
    #   relationship named 'nonexistent'
    # Available relationships:
    #   - posts (has_many)
    #   - company (belongs_to)

=head2 all

    my @users = $rs->all;
    my $users_arrayref = $rs->all;

Execute the query and return all matching records.
In list context returns an array, in scalar context returns an arrayref.

=head2 first

    my $user = $rs->first;

Execute the query with LIMIT 1 and return the first record (or undef).

=head2 count

    my $count = $rs->count;

Execute a COUNT(*) query and return the number of matching records.

=head1 EXAMPLE

    # Find all active users, ordered by name, paginated
    my $page = 2;
    my $per_page = 25;

    my @users = MyApp::Model::User
        ->where({ active => 1 })
        ->order('name')
        ->limit($per_page)
        ->offset(($page - 1) * $per_page)
        ->all;

    # Count active users
    my $active_count = MyApp::Model::User->where({ active => 1 })->count;

    # Find first matching user
    my $user = MyApp::Model::User->where({ email => 'john@example.com' })->first;

=cut
