# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package Durance::ResultSet;
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
has 'preload_specs' => (is => 'rw', default => sub { [] });

has 'logger' => (is => 'lazy');
sub _build_logger ($self) {
    require Durance::Logger;
    return Durance::Logger->new;
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

sub where ($self, $conditions = {}) {
    # Merge conditions (simple replacement for now)
    $self->conditions($conditions);
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

sub preload ($self, @relations) {
    my $class = $self->class;

    for my $rel (@relations) {
        my $meta = $class->related_to($rel);
        unless ($meta) {
            my $class_name = ref $class || $class;
            my $all_rels = $class->all_relations;

            my $msg = "Invalid preload: '$class_name' has no"
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
                       . " has_many, belongs_to, or has_one"
                       . " in your model.\n";
            }

            die $msg;
        }

        push @{$self->preload_specs}, $rel;
    }

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
        my $logger = Durance::Logger->new;
        my $params_str = @bind_values ? '[' . join(', ', map { !defined $_ ? 'NULL' : /^\d+$/ ? $_ : "'$_'" } @bind_values) . ']' : '';
        $logger->log("SQL (" . sprintf("%.3f", $duration) . " ms): $sql $params_str");
    }

    my @rows;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @rows, $class->new(%$row, db => $class->db);
    }
    $sth->finish;

    # Eager loading: batch load related records for each preload spec
    if (@{$self->preload_specs} && @rows) {
        $self->_eager_load(\@rows);
    }

    return wantarray ? @rows : \@rows;
}

sub _eager_load ($self, $rows) {
    my $class = $self->class;
    my $pk = $class->primary_key;

    for my $rel_name (@{$self->preload_specs}) {
        my $meta = $class->related_to($rel_name);
        my $rel_class = $meta->{isa};
        my $rel_type = $meta->{_relationship_type};
        my $fk = $meta->{foreign_key} // '';

        # Get parent PK values
        my @parent_ids = grep { defined $_ } map { $_->$pk } @$rows;
        next unless @parent_ids;

        # Build the related records lookup
        my %related_by_parent;

        if ($rel_type eq 'has_many') {
            # has_many: foreign key is on related table
            my $fk = $meta->{foreign_key};
            my $rel_table = $rel_class->table;

            my $sql = "SELECT * FROM $rel_table WHERE $fk IN ("
                    . join(',', ('?') x @parent_ids) . ")";

            my $start = time();
            my $sth = $class->db->dbh->prepare($sql);
            $sth->execute(@parent_ids);
            my $duration = (time() - $start) * 1000;

            if ($ENV{ORM_SQL_LOGGING}) {
                my $logger = Durance::Logger->new;
                my $params_str = @parent_ids ? '[' . join(', ', @parent_ids) . ']' : '';
                $logger->log("SQL (" . sprintf("%.3f", $duration) . " ms): PRELOAD $rel_name $sql $params_str");
            }

            while (my $row = $sth->fetchrow_hashref) {
                my $rel_obj = $rel_class->new(%$row, db => $class->db);
                my $parent_id = $row->{$fk};
                push @{$related_by_parent{$parent_id}}, $rel_obj;
            }
            $sth->finish;
        }
        elsif ($rel_type eq 'has_one') {
            # has_one: similar to has_many but returns only first
            my $fk = $meta->{foreign_key};
            my $rel_table = $rel_class->table;

            my $sql = "SELECT * FROM $rel_table WHERE $fk IN ("
                    . join(',', ('?') x @parent_ids) . ")";

            # Add LIMIT 1 per parent to get only one record
            # Actually, let's just get all and pick first per parent
            $sql = "SELECT * FROM $rel_table WHERE $fk IN ("
                    . join(',', ('?') x @parent_ids) . ")";

            my $start = time();
            my $sth = $class->db->dbh->prepare($sql);
            $sth->execute(@parent_ids);
            my $duration = (time() - $start) * 1000;

            if ($ENV{ORM_SQL_LOGGING}) {
                my $logger = Durance::Logger->new;
                my $params_str = @parent_ids ? '[' . join(', ', @parent_ids) . ']' : '';
                $logger->log("SQL (" . sprintf("%.3f", $duration) . " ms): PRELOAD $rel_name $sql $params_str");
            }

            while (my $row = $sth->fetchrow_hashref) {
                my $rel_obj = $rel_class->new(%$row, db => $class->db);
                my $parent_id = $row->{$fk};
                # Store only first for has_one
                $related_by_parent{$parent_id} //= $rel_obj;
            }
            $sth->finish;
        }
        elsif ($rel_type eq 'belongs_to') {
            # belongs_to: foreign key is on local table
            my $fk = $meta->{foreign_key};
            
            # Get unique foreign key values from parent rows
            my @fk_values = grep { defined $_ } map { $_->$fk } @$rows;
            next unless @fk_values;

            my %unique_fk;
            @unique_fk{@fk_values} = ();

            my @rel_ids = sort keys %unique_fk;
            my $rel_pk = $rel_class->primary_key;
            my $rel_table = $rel_class->table;

            my $sql = "SELECT * FROM $rel_table WHERE $rel_pk IN ("
                    . join(',', ('?') x @rel_ids) . ")";

            my $start = time();
            my $sth = $class->db->dbh->prepare($sql);
            $sth->execute(@rel_ids);
            my $duration = (time() - $start) * 1000;

            if ($ENV{ORM_SQL_LOGGING}) {
                my $logger = Durance::Logger->new;
                my $params_str = @rel_ids ? '[' . join(', ', @rel_ids) . ']' : '';
                $logger->log("SQL (" . sprintf("%.3f", $duration) . " ms): PRELOAD $rel_name $sql $params_str");
            }

            my %rel_objs;
            while (my $row = $sth->fetchrow_hashref) {
                my $rel_obj = $rel_class->new(%$row, db => $class->db);
                $rel_objs{$row->{$rel_pk}} = $rel_obj;
            }
            $sth->finish;

            # Map to each parent
            for my $parent (@$rows) {
                my $fk_val = $parent->$fk;
                $related_by_parent{$fk_val} = $rel_objs{$fk_val} if defined $fk_val;
            }
        }

        # Store preloaded data in each parent object
        for my $parent (@$rows) {
            # Determine the key to use based on relationship type
            my $lookup_key;
            if ($rel_type eq 'belongs_to') {
                # For belongs_to, the foreign key value maps to the related record
                $lookup_key = $parent->$fk;
            }
            else {
                # For has_many and has_one, use the parent's primary key
                $lookup_key = $parent->$pk;
            }
            
            my $key = "_preloaded_$rel_name";
            $parent->{$key} = $related_by_parent{$lookup_key};
        }
    }
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
        my $logger = Durance::Logger->new;
        my $params_str = @bind_values ? '[' . join(', ', map { !defined $_ ? 'NULL' : /^\d+$/ ? $_ : "'$_'" } @bind_values) . ']' : '';
        $logger->log("SQL (" . sprintf("%.3f", $duration) . " ms): $sql $params_str");
    }
    
    my ($count) = $sth->fetchrow_array;
    $sth->finish;

    return $count;
}

our $VERSION = '0.01';

1;

=pod

=head1 NAME

Durance::ResultSet - Chainable query builder

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

Provides chainable query building with where, order, limit, offset, joins, and preload.

=head1 AUTHOR

Joe Johnston <jjohn@taskboy.com>

=head1 LICENSE

Perl Artistic License

=cut

=head1 NAME

Durance::ResultSet - Result set for chainable queries

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

Durance::ResultSet provides chainable query methods for ORM models.
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

    # String API - use relationship names
    my $rs = $rs->add_joins('company');
    my $rs = $rs->add_joins('company', 'posts');
    
    # Hash API - explicit override with custom JOIN type and ON clause
    my $rs = $rs->add_joins({ 
        company => {
            type => 'INNER',
            on   => 'companies.id = employees.company_id',
        }
    });
    
    # Mixed API - combine string and hash
    my $rs = $rs->add_joins('company', { 
        posts => { type => 'INNER' } 
    });

Add SQL JOIN clauses to the query. Supports multiple approaches:

=over 4

=item * B<String API> - Use relationship names defined via C<has_many> or 
C<belongs_to> declarations in your model. JOIN type defaults to LEFT JOIN. 
If the name does not match any known relationship, C<add_joins> will C<die> 
immediately with an error listing the available relationships.

=item * B<Hash API> - Explicit override with custom JOIN type and ON clause.
Hash refs are B<not validated> against the model's relationships, so you can 
join arbitrary tables this way.

=item * B<Mixed API> - Combine string and hash forms in a single call for 
flexibility when some relationships are standard and others need customization.

=back

Returns C<$self> for method chaining. Joins are applied to both C<all()> and 
C<count()> queries.

B<Relationship Type Handling:>

Joins work with both relationship types:

=over 4

=item * B<belongs_to> - Joins the related table with a simple COUNT(*) since 
each record matches at most one related record.

    # Employee belongs_to Company
    my @employees = Employee->where({})
        ->add_joins('company')
        ->all;
    # SQL: SELECT * FROM employees LEFT JOIN companies 
    #      ON companies.id = employees.company_id

=item * B<has_many> - For C<count()> queries with has_many JOINs, uses 
COUNT(DISTINCT table.id) to avoid duplicate counting when the joined table has 
multiple matches.

    # Company has_many Employees
    my $company_count = Company->where({})
        ->add_joins('employees')
        ->count;
    # SQL: SELECT COUNT(DISTINCT companies.id) FROM companies 
    #      LEFT JOIN employees ON employees.company_id = companies.id

=back

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
    
    # With WHERE conditions
    my $active_count = $rs->where({ active => 1 })->count;
    
    # With JOINs
    my $count = $rs->add_joins('company')->count;

Execute a COUNT query and return the number of matching records.

When JOINs are present, the COUNT is intelligently adjusted based on the 
relationship type:

=over 4

=item * B<No JOINs or belongs_to JOINs> - Uses COUNT(*) since each record 
matches at most one related record.

    my $count = User->where({})->add_joins('company')->count;
    # SQL: SELECT COUNT(*) FROM users LEFT JOIN companies ...

=item * B<has_many JOINs> - Uses COUNT(DISTINCT table.id) to avoid counting 
duplicate rows when the joined table has multiple matches.

    my $count = Company->where({})->add_joins('employees')->count;
    # SQL: SELECT COUNT(DISTINCT companies.id) FROM companies 
    #      LEFT JOIN employees ...

=item * B<Multiple JOINs> - DISTINCT is used if any JOIN is has_many, 
otherwise COUNT(*) is used.

    my $count = Company->where({})
        ->add_joins('employees', 'department')
        ->count;
    # SQL: SELECT COUNT(DISTINCT companies.id) FROM companies 
    #      LEFT JOIN employees ... LEFT JOIN department ...

=back

=head1 EXAMPLES

=head2 Basic Queries

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

=head2 JOINs with String API (Convention-Based)

    # Model definitions:
    # package MyApp::Model::Employee;
    #   belongs_to company => (...);
    #   has_many projects => (...);
    #
    # package MyApp::Model::Company;
    #   has_many employees => (...);

    # Single belongs_to JOIN
    my @employees = MyApp::Model::Employee
        ->where({})
        ->add_joins('company')
        ->all;
    # SQL: SELECT * FROM employees LEFT JOIN companies 
    #      ON companies.id = employees.company_id

    # Single has_many JOIN
    my @companies = MyApp::Model::Company
        ->where({})
        ->add_joins('employees')
        ->all;
    # SQL: SELECT * FROM companies LEFT JOIN employees 
    #      ON employees.company_id = companies.id

    # Multiple JOINs
    my @employees = MyApp::Model::Employee
        ->where({})
        ->add_joins('company', 'projects')
        ->all;
    # SQL: SELECT * FROM employees 
    #      LEFT JOIN companies ON ...
    #      LEFT JOIN projects ON ...

=head2 JOINs with Hash API (Explicit Override)

    # Custom JOIN type (INNER instead of LEFT)
    my @employees = MyApp::Model::Employee
        ->where({})
        ->add_joins({
            company => { type => 'INNER' }
        })
        ->all;
    # SQL: SELECT * FROM employees INNER JOIN companies ON ...

    # Custom ON clause for non-standard relationships
    my @employees = MyApp::Model::Employee
        ->where({})
        ->add_joins({
            company => {
                type => 'INNER',
                on   => 'companies.id = employees.company_id AND companies.active = 1'
            }
        })
        ->all;

    # Join arbitrary tables
    my @employees = MyApp::Model::Employee
        ->where({})
        ->add_joins({
            salary_history => {
                type => 'LEFT',
                on   => 'salary_history.employee_id = employees.id'
            }
        })
        ->all;

=head2 JOINs with COUNT

    # COUNT with belongs_to JOIN (simple COUNT)
    my $count = MyApp::Model::Employee
        ->where({ salary => { '>' => 50000 } })
        ->add_joins('company')
        ->count;
    # SQL: SELECT COUNT(*) FROM employees 
    #      LEFT JOIN companies ON ... WHERE salary > 50000

    # COUNT with has_many JOIN (uses DISTINCT)
    my $count = MyApp::Model::Company
        ->where({ active => 1 })
        ->add_joins('employees')
        ->count;
    # SQL: SELECT COUNT(DISTINCT companies.id) FROM companies 
    #      LEFT JOIN employees ON ... WHERE active = 1

    # COUNT with multiple JOINs
    my $count = MyApp::Model::Employee
        ->where({})
        ->add_joins('company', 'projects')
        ->count;
    # SQL: SELECT COUNT(DISTINCT employees.id) FROM employees 
    #      LEFT JOIN companies ON ...
    #      LEFT JOIN projects ON ...

=head2 Mixed String and Hash JOINs

    # Combine standard relationships with explicit overrides
    my @data = MyApp::Model::Employee
        ->where({})
        ->add_joins('company', {
            projects => { type => 'INNER' }
        })
        ->all;
    # SQL: SELECT * FROM employees 
    #      LEFT JOIN companies ON ... (string API)
    #      INNER JOIN projects ON ...  (hash API)

=cut
