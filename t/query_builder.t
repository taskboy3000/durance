#!/usr/bin/env perl
use strict;
use warnings;
use experimental 'signatures';

use File::Basename;
use FindBin;
BEGIN {
    $::PROJ_ROOT = dirname($FindBin::Bin);
}

use lib ("$::PROJ_ROOT/lib", "$::PROJ_ROOT/t");

use Test2::V0;

require Durance::QueryBuilder;
require Durance::Model;
require Durance::DSL;

{
    package MyApp::Model::User;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'users';

    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str');
    column age  => (is => 'rw', isa => 'Int');

    1;
}

{
    package MyApp::Model::Company;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'companies';

    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str');

    has_many employees => (
        is => 'rw',
        isa => 'MyApp::Model::Employee',
        foreign_key => 'company_id',
    );

    1;
}

{
    package MyApp::Model::Employee;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'employees';

    column id         => (is => 'rw', isa => 'Int', primary_key => 1);
    column name       => (is => 'rw', isa => 'Str');
    column company_id => (is => 'rw', isa => 'Int');

    belongs_to company => (
        is => 'rw',
        isa => 'MyApp::Model::Company',
        foreign_key => 'company_id',
    );

    1;
}

{
    package MyApp::Model::Post;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'posts';

    column id      => (is => 'rw', isa => 'Int', primary_key => 1);
    column title   => (is => 'rw', isa => 'Str');
    column user_id => (is => 'rw', isa => 'Int');

    belongs_to user => (
        is => 'rw',
        isa => 'MyApp::Model::User',
        foreign_key => 'user_id',
    );

    1;
}

{
    package MyApp::Model::Comment;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'comments';

    column id      => (is => 'rw', isa => 'Int', primary_key => 1);
    column post_id => (is => 'rw', isa => 'Int');
    column user_id => (is => 'rw', isa => 'Int');

    belongs_to post => (
        is => 'rw',
        isa => 'MyApp::Model::Post',
        foreign_key => 'post_id',
    );

    1;
}

subtest 'QueryBuilder - basic attributes' => sub {
    my $qb = Durance::QueryBuilder->new(
        class => 'MyApp::Model::User',
        driver => 'SQLite',
    );

    is($qb->class, 'MyApp::Model::User', 'class is set');
    is($qb->driver, 'SQLite', 'driver is set');
};

subtest 'QueryBuilder - build_where with simple conditions' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::User');

    my ($clause, $values) = $qb->build_where({ name => 'John' });

    is($clause, 'name = ?', 'WHERE clause generated');
    is($values, ['John'], 'bind values correct');
};

subtest 'QueryBuilder - build_where with operators' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::User');

    my ($clause, $values) = $qb->build_where({
        age => { '>' => 21, '<' => 65 }
    });

    like($clause, qr/age [<>] \? AND age [<>] \?/, 'operators in clause');
    is(scalar(@$values), 2, 'two bind values');
};

subtest 'QueryBuilder - build_where with no conditions' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::User');

    my ($clause, $values) = $qb->build_where({});

    is($clause, '', 'empty clause for no conditions');
    is($values, [], 'empty bind values');
};

subtest 'QueryBuilder - build_joins with belongs_to' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::Employee');

    my @joins = $qb->build_joins(['company']);

    is(scalar @joins, 1, 'one join generated');
    like($joins[0], qr/LEFT JOIN companies ON/, 'LEFT JOIN with company');
    like($joins[0], qr/companies\.id = employees\.company_id/, 'ON clause correct');
};

subtest 'QueryBuilder - build_joins with hash override' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::Employee');

    my @joins = $qb->build_joins([{
        company => {
            type => 'INNER',
            on => 'companies.id = employees.company_id AND companies.active = 1',
        }
    }]);

    is(scalar @joins, 1, 'one join generated');
    like($joins[0], qr/INNER JOIN companies ON/, 'INNER JOIN');
    like($joins[0], qr/companies\.active = 1/, 'custom ON clause');
};

subtest 'QueryBuilder - needs_distinct detection' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::Employee');

    my $needs = $qb->needs_distinct(['company']);
    is($needs, 0, 'belongs_to does not need distinct');
};

subtest 'QueryBuilder - needs_distinct with has_many' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::Company');

    my $needs = $qb->needs_distinct(['employees']);
    is($needs, 1, 'has_many needs distinct');
};

subtest 'QueryBuilder - build_select basic' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::User');

    my ($sql, $values) = $qb->build_select({
        conditions => { name => 'John' },
    });

    like($sql, qr/^SELECT \* FROM users WHERE/, 'SELECT with WHERE');
    like($sql, qr/name = \?/, 'condition in SQL');
    is($values, ['John'], 'bind values');
};

subtest 'QueryBuilder - build_select with order and limit' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::User');

    my ($sql, $values) = $qb->build_select({
        order_by  => ['name DESC'],
        limit_val => 10,
        offset_val => 20,
    });

    like($sql, qr/ORDER BY name DESC/, 'ORDER BY');
    like($sql, qr/LIMIT 10/, 'LIMIT');
    like($sql, qr/OFFSET 20/, 'OFFSET');
};

subtest 'QueryBuilder - build_select with JOINs' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::Employee');

    my ($sql, $values) = $qb->build_select({
        join_specs => ['company'],
    });

    like($sql, qr/LEFT JOIN companies ON/, 'JOIN in SELECT');
};

subtest 'QueryBuilder - build_count basic' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::User');

    my ($sql, $values) = $qb->build_count({
        conditions => { active => 1 },
    });

    like($sql, qr/^SELECT COUNT\(\*\) FROM users WHERE/, 'COUNT with WHERE');
};

subtest 'QueryBuilder - build_count with has_many uses DISTINCT' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::Company');

    my ($sql, $values) = $qb->build_count({
        join_specs => ['employees'],
    });

    like($sql, qr/COUNT\(DISTINCT/, 'uses DISTINCT');
};

subtest 'QueryBuilder - driver_from_dsn' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::User');

    is($qb->driver_from_dsn('dbi:SQLite:test.db'), 'SQLite', 'SQLite');
    is($qb->driver_from_dsn('dbi:mysql:test'), 'mysql', 'MySQL');
    is($qb->driver_from_dsn('dbi:mariadb:test'), 'mariadb', 'MariaDB');
    is($qb->driver_from_dsn('dbi:Pg:dbname=test'), 'PostgreSQL', 'PostgreSQL');
    is($qb->driver_from_dsn(undef), 'SQLite', 'undefined defaults to SQLite');
};

subtest 'QueryBuilder - _format_limit' => sub {
    my $qb_sqlite = Durance::QueryBuilder->new(class => 'MyApp::Model::User', driver => 'SQLite');
    my $qb_mysql = Durance::QueryBuilder->new(class => 'MyApp::Model::User', driver => 'mysql');
    my $qb_mariadb = Durance::QueryBuilder->new(class => 'MyApp::Model::User', driver => 'mariadb');

    is($qb_sqlite->_format_limit(10, 20), 'LIMIT 10 OFFSET 20', 'SQLite format');
    is($qb_mysql->_format_limit(10, 20), 'LIMIT 20, 10', 'MySQL format');
    is($qb_mariadb->_format_limit(10, 20), 'LIMIT 20, 10', 'MariaDB format');
};

subtest 'QueryBuilder - ON clause validation' => sub {
    my $qb = Durance::QueryBuilder->new(class => 'MyApp::Model::Employee');

    my @joins = $qb->build_joins([{
        company => {
            type => 'INNER',
            on => 'companies.id = employees.company_id',
        }
    }]);
    is(scalar @joins, 1, 'valid ON clause accepted');

    my $qb2 = Durance::QueryBuilder->new(class => 'MyApp::Model::Employee');
    my $exception;
    eval {
        $qb2->build_joins([{
            company => {
                type => 'INNER',
                on => "companies.id = employees.company_id; DROP TABLE users;--",
            }
        }]);
    };
    $exception = $@ if $@;
    ok($exception, 'SQL injection attempt with semicolon dies');
    like($exception, qr/semicolons/i, 'error mentions semicolons');
};

done_testing;
