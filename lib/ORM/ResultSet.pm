# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package ORM::ResultSet;
use strict;
use warnings;
use Mojo::Base -base, -signatures;
use Carp qw(croak);

has 'class';
has 'conditions' => sub { {} };
has 'order_by'   => sub { [] };
has 'limit_val';
has 'offset_val';

sub where ($self, $conditions) {
    $self->conditions({ %{$self->conditions}, %$conditions });
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
    my $dbh   = $class->dbh // croak 'No database handle';

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
    $sql .= " WHERE " . join(' AND ', @where_parts) if @where_parts;
    $sql .= " ORDER BY " . join(', ', @{$self->order_by}) if @{$self->order_by};
    if (defined $self->limit_val) {
        $sql .= " LIMIT " . $self->limit_val;
    }
    elsif (defined $self->offset_val) {
        $sql .= " LIMIT 1000000";
    }
    $sql .= " OFFSET " . $self->offset_val if defined $self->offset_val;

    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind_values);

    my @rows;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @rows, $class->new(%$row, dbh => $dbh);
    }
    $sth->finish;

    return wantarray ? @rows : \@rows;
}

sub first ($self) {
    my @rows = $self->limit(1)->all;
    return $rows[0];
}

sub count ($self) {
    my $class = $self->class;
    my $table = $class->table;
    my $dbh   = $class->dbh // croak 'No database handle';

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

    my $sql = "SELECT COUNT(*) FROM $table";
    $sql .= " WHERE " . join(' AND ', @where_parts) if @where_parts;

    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind_values);
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
It延迟 executes queries until methods like C<all>, C<first>, or C<count> are called.

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
