# All code Joe Johnston <jjohn@taskboy.com> 2026
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

has 'query_builder' => (is => 'lazy');
sub _build_query_builder ($self) {
    require Durance::QueryBuilder;
    my $class = $self->class;
    my $driver = 'SQLite';
    
    if ($class->can('db')) {
        my $db = eval { $class->db };
        if ($db && $db->can('dsn')) {
            my $qb = Durance::QueryBuilder->new(class => $class);
            $driver = $qb->driver_from_dsn($db->dsn);
        }
    }
    
    return Durance::QueryBuilder->new(class => $class, driver => $driver);
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
                       . " has_many, belongs_to, has_one, or many_to_many"
                       . " in your model.\n";
            }

            die $msg;
        }

        push @{$self->preload_specs}, $rel;
    }

    return $self;
}

sub _get_aliased_columns ($self) {
    my $class = $self->class;
    my $main_table = $class->table;
    my @col_specs;
    
    # Main table columns with alias
    my $main_cols = $class->columns;
    for my $col (@$main_cols) {
        push @col_specs, "$main_table.$col AS ${main_table}__$col";
    }
    
    # Add columns from joined tables with aliases
    for my $rel (@{$self->join_specs}) {
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
            my $related_class = $meta->{isa};
            my $related_table = $related_class->table;
            
            my $rel_cols = $related_class->columns;
            for my $col (@$rel_cols) {
                push @col_specs, "$related_table.$col AS ${related_table}__$col";
            }
        }
        elsif ($rel_opts && $rel_opts->{table}) {
            # For explicit overrides, just add the table without aliasing
            # User must handle column collisions themselves
            push @col_specs, "$rel_opts->{table}.*";
        }
    }
    
    return wantarray ? @col_specs : \@col_specs;
}

sub all ($self) {
    my $class = $self->class;
    my $table = $class->table;
    my $dbh   = $class->db->dbh;

    my ($sql, $bind_values) = $self->query_builder->build_select({
        conditions => $self->conditions,
        order_by   => $self->order_by,
        limit_val  => $self->limit_val,
        offset_val => $self->offset_val,
        join_specs => $self->join_specs,
    });

    my $start = time();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@$bind_values);
    my $duration = (time() - $start) * 1000;
    
    if ($ENV{ORM_SQL_LOGGING}) {
        my $logger = Durance::Logger->new;
        my $params_str = @$bind_values ? '[' . join(', ', map { !defined $_ ? 'NULL' : /^\d+$/ ? $_ : "'$_'" } @$bind_values) . ']' : '';
        $logger->log("SQL (" . sprintf("%.3f", $duration) . " ms): $sql $params_str");
    }

    my @rows;
    my $main_table = $class->table;
    while ( my $row = $sth->fetchrow_hashref ) {
        if (@{$self->join_specs}) {
            my %mapped_row;
            for my $key (keys %$row) {
                if ($key =~ /^${main_table}__(.+)$/) {
                    $mapped_row{$1} = $row->{$key};
                }
            }
            push @rows, $class->new(%mapped_row, db => $class->db);
        }
        else {
            push @rows, $class->new(%$row, db => $class->db);
        }
    }
    $sth->finish;

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
        elsif ($rel_type eq 'many_to_many') {
            # many_to_many: requires JOIN through junction table
            # SELECT related.* FROM related 
            # JOIN through ON related.id = through.using
            # WHERE through.local_fk IN (parent_ids)
            my $through = $meta->{through};
            my $using = $meta->{using};
            my $local_fk = $meta->{local_fk};
            my $rel_table = $rel_class->table;

            my $sql = "SELECT $rel_table.*, $through.$local_fk AS _parent_fk "
                    . "FROM $rel_table "
                    . "JOIN $through ON $rel_table.id = $through.$using "
                    . "WHERE $through.$local_fk IN ("
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
                my $parent_id = delete $row->{_parent_fk};
                my $rel_obj = $rel_class->new(%$row, db => $class->db);
                push @{$related_by_parent{$parent_id}}, $rel_obj;
            }
            $sth->finish;
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
    return $self->query_builder->build_joins($self->join_specs);
}

sub _needs_distinct ($self) {
    return $self->query_builder->needs_distinct($self->join_specs);
}

sub count ($self) {
    my $class = $self->class;
    my $dbh   = $class->db->dbh;

    my ($sql, $bind_values) = $self->query_builder->build_count({
        conditions => $self->conditions,
        join_specs => $self->join_specs,
    });

    my $start = time();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@$bind_values);
    my $duration = (time() - $start) * 1000;
    
    if ($ENV{ORM_SQL_LOGGING}) {
        my $logger = Durance::Logger->new;
        my $params_str = @$bind_values ? '[' . join(', ', map { !defined $_ ? 'NULL' : /^\d+$/ ? $_ : "'$_'" } @$bind_values) . ']' : '';
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
