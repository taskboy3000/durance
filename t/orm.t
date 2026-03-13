#!/usr/bin/env perl
# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
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

use MyApp::DB;
use ORM::Schema;

# Test database class - defined once for all tests
package TestDB;
use Moo;
extends 'ORM::DB';
use FindBin;

sub _build_dsn { 
    my $db_path = "$FindBin::Bin/MyApp/var/test.db";
    return "dbi:SQLite:dbname=$db_path";
}

# Base model class for test models that use TestDB
package TestModel;
use Moo;
extends 'ORM::Model';

sub _db_class_for { return 'TestDB'; }

package main;

our $gDBName = "$FindBin::Bin/MyApp/var/test.db";

# Clean up test DB before running tests
if (-e $gDBName) {
    print "Removing stale DB file: $gDBName\n";
    unlink $gDBName or warn("unlink: $gDBName - $!\n");
}

sub create_test_db ($app) {
    if (-e $gDBName) {
        unlink $gDBName;
    }
    ORM::Schema->migrate_all($app);
}

subtest 'ORM::DB - attributes and methods' => sub {
    my $db = TestDB->new;

    subtest 'attributes' => sub {
        like($db->dsn, qr/dbi:SQLite:dbname=.*\.db/, 'dsn returns correct DSN');

        is($db->username, undef, 'username defaults to undef');
        is($db->password, undef, 'password defaults to undef');

        my $opts = $db->driver_options;
        ok($opts, 'driver_options returns truthy value');
        is($opts->{RaiseError}, 1, 'RaiseError defaults to 1');
        is($opts->{AutoCommit}, 1, 'AutoCommit defaults to 1');
    };

    subtest 'dbh method' => sub {
        my $dbh = $db->dbh;
        ok($dbh, 'dbh returns a connected handle');
        ok(eval { $dbh->can('prepare') }, 'dbh has prepare method (is DBI handle)');

        my $driver = $dbh->{Driver}{Name};
        is($driver, 'SQLite', 'driver is SQLite');
    };

    subtest 'handle pooling' => sub {
        my $dbh1 = $db->dbh;
        my $dbh2 = $db->dbh;
        is($dbh1, $dbh2, 'calling dbh twice returns same handle');

        ok($dbh1->ping, 'connection is still alive');
    };

    subtest 'disconnect_all' => sub {
        my $dbh = $db->dbh;
        ok($dbh->ping, 'handle is connected before disconnect_all');

        TestDB->disconnect_all;

        ok(!$dbh->ping, 'handle is disconnected after disconnect_all');
    };

    subtest 'isDSNValid' => sub {
        my ($valid, $error) = TestDB->isDSNValid;
        is($valid, 1, 'valid DSN returns true');
        is($error, undef, 'no error for valid DSN');

        my ($invalid, $err_msg) = TestDB->isDSNValid('dbi:SQLite:dbname=/nonexistent/path/test.db');
        is($invalid, 0, 'invalid DSN returns false');
        ok($err_msg, 'error message returned for invalid DSN');
        like($err_msg, qr/unable to open database file/, 'error message is clean');
    };

    package main;
};

subtest 'ORM::Schema - constructor and attributes' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;

    my $schema = ORM::Schema->new(dbh => $dbh);

    ok($schema, 'Schema object created');
    is($schema->dbh, $dbh, 'dbh attribute set correctly');

    my $driver = $schema->_detect_driver($dbh);
    is($driver, 'sqlite', 'driver auto-detected as sqlite');

    subtest 'driver override' => sub {
        my $schema_mysql = ORM::Schema->new(dbh => $dbh, driver => 'mysql');
        is($schema_mysql->driver, 'mysql', 'driver can be overridden');
    };

    ok($schema->logger, 'logger attribute exists');
};

subtest 'ORM::Schema - DDL generation' => sub {
    package MyApp::Model::TestItem;
    use Moo;
    extends 'ORM::Model';
    use ORM::DSL;

    tablename 'test_items';
    column id    => (is => 'rw', isa => 'Int', primary_key => 1);
    column name  => (is => 'rw', isa => 'Str', required => 1);
    column email => (is => 'rw', isa => 'Str');
    column age   => (is => 'rw', isa => 'Int');

    package main;

    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh, driver => 'sqlite');

    subtest 'ddl_for_class generates valid SQL' => sub {
        my $sql = $schema->ddl_for_class('MyApp::Model::TestItem', 'sqlite');

        like($sql, qr/CREATE TABLE test_items/, 'contains CREATE TABLE');
        like($sql, qr/id INTEGER PRIMARY KEY AUTOINCREMENT/, 'id is INTEGER PRIMARY KEY AUTOINCREMENT');
        like($sql, qr/name TEXT NOT NULL/, 'name is TEXT NOT NULL');
        like($sql, qr/email TEXT/, 'email is TEXT');
        like($sql, qr/age INTEGER/, 'age is INTEGER');
        unlike($sql, qr/VARCHAR/, 'no VARCHAR for SQLite');
    };

    subtest 'ddl_for_class with MySQL driver' => sub {
        my $sql = $schema->ddl_for_class('MyApp::Model::TestItem', 'mysql');

        like($sql, qr/CREATE TABLE test_items/, 'contains CREATE TABLE');
        like($sql, qr/id INTEGER PRIMARY KEY AUTO_INCREMENT/, 'id uses AUTO_INCREMENT');
        like($sql, qr/name VARCHAR\(255\) NOT NULL/, 'name is VARCHAR(255) NOT NULL');
        like($sql, qr/email VARCHAR\(255\)/, 'email is VARCHAR(255)');
        like($sql, qr/age INTEGER/, 'age is INTEGER');
        unlike($sql, qr/AUTOINCREMENT/, 'no SQLite AUTOINCREMENT');
    };

    subtest 'type mapping for SQLite' => sub {
        package MyApp::Model::Types;
        use Moo;
        extends 'ORM::Model';
        use ORM::DSL;

        tablename 'types';
        column id          => (is => 'rw', isa => 'Int', primary_key => 1);
        column str_col     => (is => 'rw', isa => 'Str');
        column text_col    => (is => 'rw', isa => 'Text');
        column bool_col    => (is => 'rw', isa => 'Bool');
        column float_col   => (is => 'rw', isa => 'Float');
        column timestamp_col => (is => 'rw', isa => 'Timestamp');

        package main;

        my $sql = $schema->ddl_for_class('MyApp::Model::Types', 'sqlite');

        like($sql, qr/str_col TEXT/, 'Str maps to TEXT');
        like($sql, qr/text_col TEXT/, 'Text maps to TEXT');
        like($sql, qr/bool_col INTEGER/, 'Bool maps to INTEGER');
        like($sql, qr/float_col REAL/, 'Float maps to REAL');
        like($sql, qr/timestamp_col TEXT/, 'Timestamp maps to TEXT');
    };
};

subtest 'ORM::Schema - table introspection' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    subtest 'table_exists returns false for non-existent table' => sub {
        package MyApp::Model::NonExistent;
        use Moo;
        extends 'ORM::Model';
        use ORM::DSL;

        tablename 'nonexistent_table';
        column id => (is => 'rw', isa => 'Int', primary_key => 1);

        package main;

        my $model = MyApp::Model::NonExistent->new(db => $db);
        ok(!$schema->table_exists($model), 'table_exists returns false');
    };

    subtest 'table_info returns empty for non-existent table' => sub {
        package MyApp::Model::NonExistent2;
        use Moo;
        extends 'ORM::Model';
        use ORM::DSL;

        tablename 'another_nonexistent';
        column id => (is => 'rw', isa => 'Int', primary_key => 1);

        package main;

        my $model = MyApp::Model::NonExistent2->new(db => $db);
        my @cols = $schema->table_info($model);
        is(scalar @cols, 0, 'table_info returns empty list');
    };
};

subtest 'ORM::Schema - table creation and migration' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    subtest 'Step 3.1 & 3.2: Create model and test create_table' => sub {
        package MyApp::Model::CreateTest;
        use Moo;
        extends 'ORM::Model';
        use ORM::DSL;

        tablename 'create_test';
        column id    => (is => 'rw', isa => 'Int', primary_key => 1);
        column name  => (is => 'rw', isa => 'Str', required => 1);

        package main;

        my $model = MyApp::Model::CreateTest->new(db => $db);
        $dbh->do("DROP TABLE IF EXISTS create_test");
        ok(MyApp::Model::CreateTest->can('table'), 'Model can call table');
        is(MyApp::Model::CreateTest->table, 'create_test', 'table name is correct');

        ok(!$schema->table_exists($model), 'table does not exist yet');

        my $result = $schema->create_table($model);
        ok($result, 'create_table returns truthy');

        ok($schema->table_exists($model), 'table exists after create_table');

        my @cols = $schema->table_info($model);
        is(scalar @cols, 2, 'table has 2 columns');

        my %col_names = map { $_->{COLUMN_NAME} => 1 } @cols;
        ok($col_names{id}, 'id column exists');
        ok($col_names{name}, 'name column exists');
    };

    subtest 'Step 3.3: Test pending_changes detects missing columns' => sub {
        package MyApp::Model::PendingCheck;
        use Moo;
        extends 'ORM::Model';
        use ORM::DSL;

        tablename 'create_test';
        column id    => (is => 'rw', isa => 'Int', primary_key => 1);
        column name  => (is => 'rw', isa => 'Str', required => 1);
        column extra => (is => 'rw', isa => 'Str');

        package main;

        my $model = MyApp::Model::PendingCheck->new(db => $db);

        my @pending = @{$schema->pending_changes($model)};
        is(scalar @pending, 1, 'pending_changes shows 1 extra column in model not in DB');
        like($pending[0], qr/ADD COLUMN extra/, 'pending includes extra column');
    };

    subtest 'Step 3.3b: Test sync_table creates table' => sub {
        package MyApp::Model::SyncTest3;
        use Moo;
        extends 'ORM::Model';
        use ORM::DSL;

        tablename 'sync_test3';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column code => (is => 'rw', isa => 'Str');

        package main;
        my $model = MyApp::Model::SyncTest3->new(db => $db);
        $db->dbh->do("DROP TABLE IF EXISTS " . $model->table);

        my $changes = $schema->sync_table($model);
        ok($schema->table_exists($model), 'sync_table creates table');
        is(ref $changes, 'ARRAY', 'sync_table returns array ref');
        is(scalar @$changes, 1, 'sync_table returns one change (table created)');
    };
};

subtest 'ORM::Model - CRUD operations' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    subtest 'Step 4.1-4.7: Full CRUD workflow' => sub {
        package MyApp::Model::CrudFull;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'crud_full';
        column id    => (is => 'rw', isa => 'Int', primary_key => 1);
        column name  => (is => 'rw', isa => 'Str', required => 1);
        column email => (is => 'rw', isa => 'Str');

        package main;

        my $crud_model = MyApp::Model::CrudFull->new(db => $db);
        $schema->create_table($crud_model);

        subtest '4.1: Model instantiation and metadata' => sub {
            my $model = MyApp::Model::CrudFull->new;
            ok($model->can('new'), 'Model can be instantiated');
            is($model->columns->[0], 'id', 'first column is id');
            is($model->columns->[1], 'name', 'second column is name');
            is($model->primary_key, 'id', 'primary key is id');
        };

        subtest '4.2: Test create and insert' => sub {
            my $user = MyApp::Model::CrudFull->create({ name => 'Alice', email => 'alice@test.com' });
            ok($user, 'create returns object');
            ok($user->id, 'id is set after create');
            is($user->name, 'Alice', 'name is set');
            is($user->email, 'alice@test.com', 'email is set');
        };

        subtest '4.3: Test find and all' => sub {

            my $alice = MyApp::Model::CrudFull->create({ name => 'Bob', email => 'bob@test.com' });
            MyApp::Model::CrudFull->create({ name => 'Carol', email => 'carol@test.com' });

            my $found = MyApp::Model::CrudFull->find($alice->id);
            ok($found, 'find returns a defined value');
            is($found->name, 'Bob', 'found correct record');

            my @all = MyApp::Model::CrudFull->all;
            ok(scalar @all >= 2, 'all returns at least 2 records');

            my @found_where = MyApp::Model::CrudFull->where({ name => 'Bob' })->all;
            is(scalar @found_where, 1, 'where returns 1 record');
            is($found_where[0]->email, 'bob@test.com', 'where returns correct record');
        };

        subtest '4.4: Test update' => sub {
            my $user = MyApp::Model::CrudFull->first;
            $user->name('Updated');
            $user->update;

            my $updated = MyApp::Model::CrudFull->find($user->id);
            is($updated->name, 'Updated', 'name updated in DB');
        };

        subtest '4.5: Test delete' => sub {
            my $user = MyApp::Model::CrudFull->first;
            my $id = $user->id;
            $user->delete;

            my $found = MyApp::Model::CrudFull->find($id);
            ok(!$found, 'record deleted');
        };

        subtest '4.6: Test ResultSet chainable methods' => sub {
            # Note: Previous tests have created records, so we check total count
            my @existing = MyApp::Model::CrudFull->all;
            my $existing_count = scalar @existing;
            
            MyApp::Model::CrudFull->create({ name => 'Zara', email => 'zara@test.com' });
            MyApp::Model::CrudFull->create({ name => 'Alice', email => 'alice2@test.com' });
            MyApp::Model::CrudFull->create({ name => 'Bob', email => 'bob2@test.com' });

            my @ordered = MyApp::Model::CrudFull->where({})->order('name')->all;
            is($ordered[0]->name, 'Alice', 'first ordered by name');
            is($ordered[1]->name, 'Bob', 'second ordered by name');
            # Third could be Bob (duplicate) or Zara depending on order
            ok($ordered[2]->name eq 'Bob' || $ordered[2]->name eq 'Zara', 'third is Bob or Zara');

            my @limited = MyApp::Model::CrudFull->where({})->limit(2)->all;
            is(scalar @limited, 2, 'limit returns 2');

            my $first = MyApp::Model::CrudFull->where({})->first;
            ok($first, 'first returns a record');

            my $count = MyApp::Model::CrudFull->count;
            is($count, $existing_count + 3, 'count returns correct total');
        };

        subtest '4.7: Test to_hash and save' => sub {
            # Find any existing record
            my $user = MyApp::Model::CrudFull->first;
            ok($user, 'first returns a record for to_hash test');
            
            my $hash = $user->to_hash;

            ok(exists $hash->{name}, 'to_hash includes name');
            ok(exists $hash->{email}, 'to_hash includes email');
            ok(!exists $hash->{db}, 'to_hash excludes db');

            my $new_user = MyApp::Model::CrudFull->new(name => 'NewUser', email => 'new@test.com');
            $new_user->save;
            ok($new_user->id, 'save inserts and sets id');
        };
    };
};

subtest 'ORM::Model - Error handling' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    subtest 'EH-1: find() returns undef when record not found' => sub {
        package MyApp::Model::ErrorFind;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'error_find';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column name => (is => 'rw', isa => 'Str');

        package main;

        my $model = MyApp::Model::ErrorFind->new(db => $db);
        $schema->create_table($model);

        my $found = MyApp::Model::ErrorFind->find(999);
        ok(!defined $found, 'find returns undef for non-existent record');
    };

    subtest 'EH-2: update() without primary key throws' => sub {
        package MyApp::Model::ErrorUpdate;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'error_update';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column name => (is => 'rw', isa => 'Str');

        package main;

        my $obj = MyApp::Model::ErrorUpdate->new(name => 'Test');
        eval { $obj->update };
        ok($@ && $@ =~ /primary key/, 'update without pk dies');
    };

    subtest 'EH-3: delete() without primary key throws' => sub {
        package MyApp::Model::ErrorDelete;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'error_delete';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column name => (is => 'rw', isa => 'Str');

        package main;

        my $obj = MyApp::Model::ErrorDelete->new(name => 'Test');
        eval { $obj->delete };
        ok($@ && $@ =~ /primary key/, 'delete without pk dies');
    };

    subtest 'EH-4: db() with invalid DSN throws' => sub {
        package MyApp::Model::BadDSN;
        use Moo;
        extends 'ORM::Model';

        sub _db_class_for { 'BadTestDB' }

        package BadTestDB;
        use Moo;
        extends 'ORM::DB';

        sub _build_dsn { 'dbi:SQLite:dbname=/nonexistent/path/test.db' }

        package main;

        my $db = MyApp::Model::BadDSN->db;
        eval { $db->dbh };
        ok($@, 'dbh() dies with invalid DSN');
    };
};

subtest 'ORM::Model - Auto-timestamps' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    subtest 'AT-1 & AT-2: create() sets created_at and updated_at' => sub {
        package MyApp::Model::TimestampTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'timestamp_test';
        column id         => (is => 'rw', isa => 'Int', primary_key => 1);
        column name       => (is => 'rw', isa => 'Str');
        column created_at => (is => 'rw', isa => 'Str');
        column updated_at => (is => 'rw', isa => 'Str');

        package main;

        my $model = MyApp::Model::TimestampTest->new(db => $db);
        $schema->create_table($model);

        my $obj = MyApp::Model::TimestampTest->create({ name => 'Test' });

        ok($obj->created_at, 'created_at is set after create');
        ok($obj->updated_at, 'updated_at is set after create');
    };

    subtest 'AT-3: update() sets updated_at' => sub {
        package MyApp::Model::TimestampUpdate;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'timestamp_update';
        column id         => (is => 'rw', isa => 'Int', primary_key => 1);
        column name       => (is => 'rw', isa => 'Str');
        column created_at => (is => 'rw', isa => 'Str');
        column updated_at => (is => 'rw', isa => 'Str');

        package main;

        my $model = MyApp::Model::TimestampUpdate->new(db => $db);
        $schema->create_table($model);

        my $obj = MyApp::Model::TimestampUpdate->create({ name => 'Test' });
        my $original_updated = $obj->updated_at;

        sleep(1);

        $obj->name('Updated');
        $obj->update;

        ok($obj->updated_at gt $original_updated, 'updated_at changed after update');
    };

    subtest 'AT-4: timestamps work without columns' => sub {
        package MyApp::Model::NoTimestamp;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'no_timestamp';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column name => (is => 'rw', isa => 'Str');

        package main;

        my $model = MyApp::Model::NoTimestamp->new(db => $db);
        $schema->create_table($model);

        my $obj = MyApp::Model::NoTimestamp->create({ name => 'Test' });
        ok($obj->id, 'create works without timestamp columns');

        $obj->name('Updated');
        $obj->update;
        ok($obj->name eq 'Updated', 'update works without timestamp columns');
    };
};

subtest 'ORM::Model - Complex ResultSet Queries' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    subtest 'RQ-1: where() with comparison operators' => sub {
        package MyApp::Model::CompareTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'compare_test';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column name => (is => 'rw', isa => 'Str');
        column age  => (is => 'rw', isa => 'Int');

        package main;

        my $model = MyApp::Model::CompareTest->new(db => $db);
        $schema->create_table($model);

        MyApp::Model::CompareTest->create({ name => 'Alice', age => 25 });
        MyApp::Model::CompareTest->create({ name => 'Bob', age => 30 });
        MyApp::Model::CompareTest->create({ name => 'Carol', age => 35 });

        my @adults = MyApp::Model::CompareTest->where({ age => { '>=' => 18 }})->all;
        is(scalar @adults, 3, '>= 18 returns 3');

        my @seniors = MyApp::Model::CompareTest->where({ age => { '>' => 30 }})->all;
        is(scalar @seniors, 1, '> 30 returns 1');
        is($seniors[0]->name, 'Carol', 'senior is Carol');

        my @young = MyApp::Model::CompareTest->where({ age => { '<' => 30 }})->all;
        is(scalar @young, 1, '< 30 returns 1 (Alice, age 25)');
        is($young[0]->name, 'Alice', 'youngest is Alice');
    };

    subtest 'RQ-2: where() with LIKE operator' => sub {
        package MyApp::Model::LikeTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'like_test';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column name => (is => 'rw', isa => 'Str');

        package main;

        my $model = MyApp::Model::LikeTest->new(db => $db);
        $schema->create_table($model);

        MyApp::Model::LikeTest->create({ name => 'John' });
        MyApp::Model::LikeTest->create({ name => 'Jane' });
        MyApp::Model::LikeTest->create({ name => 'Bob' });

        my @j_names = MyApp::Model::LikeTest->where({ name => { 'LIKE' => 'J%' }})->all;
        is(scalar @j_names, 2, 'LIKE J% returns 2');

        my @ohn = MyApp::Model::LikeTest->where({ name => { 'LIKE' => '%ohn%' }})->all;
        is(scalar @ohn, 1, 'LIKE %ohn% returns 1');
        is($ohn[0]->name, 'John', 'found John');
    };

    subtest 'RQ-3: where() with multiple conditions' => sub {
        package MyApp::Model::MultiCondTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'multi_cond_test';
        column id      => (is => 'rw', isa => 'Int', primary_key => 1);
        column name    => (is => 'rw', isa => 'Str');
        column status  => (is => 'rw', isa => 'Str');
        column active  => (is => 'rw', isa => 'Int');

        package main;

        my $model = MyApp::Model::MultiCondTest->new(db => $db);
        $schema->create_table($model);

        MyApp::Model::MultiCondTest->create({ name => 'A', status => 'gold', active => 1 });
        MyApp::Model::MultiCondTest->create({ name => 'B', status => 'silver', active => 1 });
        MyApp::Model::MultiCondTest->create({ name => 'C', status => 'gold', active => 0 });

        my @gold_active = MyApp::Model::MultiCondTest->where({
            status => 'gold',
            active => 1
        })->all;
        is(scalar @gold_active, 1, 'multiple conditions return 1');
        is($gold_active[0]->name, 'A', 'gold active is A');
    };

    subtest 'RQ-4: order() with multiple columns' => sub {
        package MyApp::Model::MultiOrderTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'multi_order_test';
        column id    => (is => 'rw', isa => 'Int', primary_key => 1);
        column name  => (is => 'rw', isa => 'Str');
        column score => (is => 'rw', isa => 'Int');

        package main;

        my $model = MyApp::Model::MultiOrderTest->new(db => $db);
        $schema->create_table($model);

        MyApp::Model::MultiOrderTest->create({ name => 'Alice', score => 100 });
        MyApp::Model::MultiOrderTest->create({ name => 'Bob', score => 90 });
        MyApp::Model::MultiOrderTest->create({ name => 'Carol', score => 100 });

        my @by_name = MyApp::Model::MultiOrderTest->where({})->order('score DESC')->order('name ASC')->all;
        is($by_name[0]->name, 'Alice', 'first: Alice (score 100, alphabetical)');
        is($by_name[1]->name, 'Carol', 'second: Carol (score 100, alphabetical)');
        is($by_name[2]->name, 'Bob', 'third: Bob (score 90)');
    };

    subtest 'RQ-5: order() with DESC' => sub {
        package MyApp::Model::DescOrderTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'desc_order_test';
        column id    => (is => 'rw', isa => 'Int', primary_key => 1);
        column name  => (is => 'rw', isa => 'Str');

        package main;

        my $model = MyApp::Model::DescOrderTest->new(db => $db);
        $schema->create_table($model);

        MyApp::Model::DescOrderTest->create({ name => 'Alice' });
        MyApp::Model::DescOrderTest->create({ name => 'Bob' });
        MyApp::Model::DescOrderTest->create({ name => 'Carol' });

        my @desc = MyApp::Model::DescOrderTest->where({})->order('name DESC')->all;
        is($desc[0]->name, 'Carol', 'first in DESC: Carol');
        is($desc[1]->name, 'Bob', 'second in DESC: Bob');
        is($desc[2]->name, 'Alice', 'third in DESC: Alice');
    };

    subtest 'RQ-6: offset() without limit' => sub {
        package MyApp::Model::OffsetTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'offset_test';
        column id    => (is => 'rw', isa => 'Int', primary_key => 1);
        column name  => (is => 'rw', isa => 'Str');

        package main;

        my $model = MyApp::Model::OffsetTest->new(db => $db);
        $schema->create_table($model);

        MyApp::Model::OffsetTest->create({ name => 'A' });
        MyApp::Model::OffsetTest->create({ name => 'B' });
        MyApp::Model::OffsetTest->create({ name => 'C' });
        MyApp::Model::OffsetTest->create({ name => 'D' });
        MyApp::Model::OffsetTest->create({ name => 'E' });

        my @skip_two = MyApp::Model::OffsetTest->where({})->order('name ASC')->offset(2)->all;
        is(scalar @skip_two, 3, 'offset(2) returns 3 records');
        is($skip_two[0]->name, 'C', 'first after offset is C');
    };
};

subtest 'ORM::Model - Relationship functions' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    subtest 'has_many and belongs_to relationships' => sub {
        package MyApp::Model::Author;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'authors';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column name => (is => 'rw', isa => 'Str', required => 1);

        has_many posts => (is => 'rw', isa => 'MyApp::Model::Post', foreign_key => 'author_id');

        package MyApp::Model::Post;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'posts';
        column id        => (is => 'rw', isa => 'Int', primary_key => 1);
        column author_id => (is => 'rw', isa => 'Int');
        column title     => (is => 'rw', isa => 'Str', required => 1);

        belongs_to author => (is => 'rw', isa => 'MyApp::Model::Author', foreign_key => 'author_id');

        package main;

        my $author_model = MyApp::Model::Author->new(db => $db);
        my $post_model = MyApp::Model::Post->new(db => $db);
        $schema->create_table($author_model);
        $schema->create_table($post_model);

        subtest 'has_many creates relationship method' => sub {
            my $author = MyApp::Model::Author->create({ name => 'Alice' });
            ok($author->can('posts'), 'has_many creates posts method');
            ok($author->can('create_posts'), 'has_many creates create_posts method');
        };

        subtest 'belongs_to creates relationship method' => sub {
            my $author = MyApp::Model::Author->create({ name => 'Bob' });
            my $post = MyApp::Model::Post->create({ title => 'Test Post', author_id => $author->id });
            
            ok($post->can('author'), 'belongs_to creates author method');
            my $found_author = $post->author;
            is($found_author->name, 'Bob', 'belongs_to returns correct parent');
        };

        subtest 'has_many queries related objects' => sub {
            my $author = MyApp::Model::Author->create({ name => 'Carol' });
            MyApp::Model::Post->create({ title => 'Post 1', author_id => $author->id });
            MyApp::Model::Post->create({ title => 'Post 2', author_id => $author->id });

            my @posts = $author->posts;
            is(scalar @posts, 2, 'has_many returns related objects');
        };

        subtest 'create_* method sets foreign key automatically' => sub {
            my $author = MyApp::Model::Author->create({ name => 'Dave' });
            my $new_post = $author->create_posts({ title => 'Auto FK Post' });
            
            is($new_post->author_id, $author->id, 'create_* sets foreign key');
            is($new_post->title, 'Auto FK Post', 'create_* sets other fields');
        };
    };
};

subtest 'ORM::Model - Validation functions' => sub {
    my $db = TestDB->new;
    my $dbh = $db->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    subtest 'Format validation' => sub {
        package MyApp::Model::FormatTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'format_test';
        column id    => (is => 'rw', isa => 'Int', primary_key => 1);
        column email => (is => 'rw', isa => 'Str');

        validates email => (format => qr/@/);

        package main;

        my $model = MyApp::Model::FormatTest->new(db => $db);
        $schema->create_table($model);

        my $obj = MyApp::Model::FormatTest->new;
        $obj->email('test@example.com');
        is($obj->email, 'test@example.com', 'valid email accepted');

        my $died = dies { $obj->email('invalid') };
        ok($died, 'invalid email format dies');
    };

    subtest 'Length validation' => sub {
        package MyApp::Model::LengthTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'length_test';
        column id   => (is => 'rw', isa => 'Int', primary_key => 1);
        column code => (is => 'rw', isa => 'Str', length => 5);

        package main;

        my $model = MyApp::Model::LengthTest->new(db => $db);
        $schema->create_table($model);

        my $obj = MyApp::Model::LengthTest->new;
        $obj->code('ABCDE');
        is($obj->code, 'ABCDE', 'value within length accepted');

        my $died = dies { $obj->code('ABCDEF') };
        ok($died, 'value exceeding length dies');
    };

    subtest 'Bool coercion' => sub {
        package MyApp::Model::BoolTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'bool_test';
        column id      => (is => 'rw', isa => 'Int', primary_key => 1);
        column enabled => (is => 'rw', isa => 'Bool', default => 1);

        package main;

        my $model = MyApp::Model::BoolTest->new(db => $db);
        $schema->create_table($model);

        my $obj = MyApp::Model::BoolTest->new;

        $obj->enabled('yes');
        is($obj->enabled, 1, 'truthy string coerced to 1');

        $obj->enabled(0);
        is($obj->enabled, 0, 'zero stays 0');

        $obj->enabled('');
        is($obj->enabled, 0, 'empty string coerced to 0');

        $obj->enabled(42);
        is($obj->enabled, 1, 'nonzero int coerced to 1');

        my $fresh = MyApp::Model::BoolTest->new;
        is($fresh->enabled, 1, 'Bool default 1 returned');
    };

    subtest 'column_meta method' => sub {
        package MyApp::Model::MetaTest;
        use Moo;
        extends 'TestModel';
        use ORM::DSL;

        tablename 'meta_test';
        column id         => (is => 'rw', isa => 'Int', primary_key => 1);
        column name       => (is => 'rw', isa => 'Str', required => 1);
        column email      => (is => 'rw', isa => 'Str', length => 255);
        column active     => (is => 'rw', isa => 'Bool', default => 1);

        package main;

        my $id_meta = MyApp::Model::MetaTest->column_meta('id');
        is($id_meta->{primary_key}, 1, 'id is primary key');
        is($id_meta->{isa}, 'Int', 'id isa Int');

        my $name_meta = MyApp::Model::MetaTest->column_meta('name');
        is($name_meta->{isa}, 'Str', 'name isa Str');
        is($name_meta->{required}, 1, 'name is required');

        my $email_meta = MyApp::Model::MetaTest->column_meta('email');
        is($email_meta->{length}, 255, 'email has length 255');

        my $active_meta = MyApp::Model::MetaTest->column_meta('active');
        is($active_meta->{isa}, 'Bool', 'active isa Bool');
        is($active_meta->{default}, 1, 'active has default 1');

        my $missing_meta = MyApp::Model::MetaTest->column_meta('nonexistent');
        is(keys %$missing_meta, 0, 'returns empty hash for missing column');
    };

    subtest 'schema_name method' => sub {
        package MyApp::Model::SchemaTest;
        use Moo;
        extends 'ORM::Model';
        use ORM::DSL;

        tablename 'schema_test';
        column id => (is => 'rw', isa => 'Int', primary_key => 1);

        package main;

        is(MyApp::Model::SchemaTest->schema_name, undef, 'plain model returns undef');

        # Test with app:: schema
        package MyApp::Model::app::User;
        use Moo;
        extends 'ORM::Model';
        use ORM::DSL;

        tablename 'app_users';
        column id => (is => 'rw', isa => 'Int', primary_key => 1);

        package main;

        is(MyApp::Model::app::User->schema_name, 'app', 'extracts app schema');
    };
};

subtest 'ORM::Model - Basic attributes' => sub {
    my $myApp = MyApp::DB->new();
    my @modelClass = ORM::Schema->get_all_models_for_app($myApp);
    for my $modelClass (@modelClass) {
        eval "require $modelClass";
        $modelClass->import;

        next if !$modelClass->can('table');
        ok($modelClass->table, "Got table name from $modelClass");

        printf("\tFound model class '%s'\n", $modelClass);
        if (my $table = $modelClass->table) {
            printf("\t\t-> manages table '%s'\n",
                $modelClass->table // 'N/A'
            );
        }
    }
    # create_test_db($myApp);
};

done_testing;

__END__
if (0) {
    subtest 'ORM::Model - column definition' => sub {        
        my @cols = @{MyApp::Model::User->columns};
        is(\@cols, array { item 'id'; item 'name'; item 'email'; item 'age'; item 'active' }, 'columns defined');
        
        is(MyApp::Model::User->primary_key, 'id', 'primary key is id');
        
        my $meta = MyApp::Model::User->column_meta('email');
        is($meta->{required}, 1, 'email is required');
        is($meta->{unique}, 1, 'email is unique');
        
        my $user = MyApp::Model::User->new(
            name  => 'John',
            email => 'john@test.com',
            age   => 25,
        );
        
        is($user->name, 'John', 'name getter');
        $user->name('Jane');
        is($user->name, 'Jane', 'name setter returns self');
        
        is($user->email, 'john@test.com', 'email getter');
        is($user->age, 25, 'age getter');
    };

    subtest 'ORM::Schema - table operations' => sub {
        my $dbh = create_test_db();
        my $schema = ORM::Schema->new(dbh => $dbh);
        
        ok(!$schema->table_exists('users'), 'users table does not exist yet');
        
        $schema->create_table(MyApp::Model::User->new);
        
        ok($schema->table_exists('users'), 'users table created');
        
        my @cols = $schema->table_info('users');
        is(scalar @cols, 5, 'all columns created');
        
        my %col_names = map { $_->{COLUMN_NAME} => 1 } @cols;
        ok($col_names{id}, 'id column exists');
        ok($col_names{name}, 'name column exists');
        ok($col_names{email}, 'email column exists');
        ok($col_names{age}, 'age column exists');
        ok($col_names{active}, 'active column exists');
        
        $dbh->disconnect;
    };


    subtest 'ORM::Schema - migrate adds columns' => sub {
        package MyApp::Model::app::person;
        use ORM::Model '-base', '-signatures';
        
        column id    => (is => 'rw', isa => 'Int', primary_key => 1);
        column name  => (is => 'rw', isa => 'Str');
        column email => (is => 'rw', isa => 'Str');
        column age   => (is => 'rw', isa => 'Int');
        
        sub table { 'people' }
        
        package main;
        
        my $schema = ORM::Schema->new;    
        $schema->migrate(MyApp::Model::app::person->new);
        
        my @cols = $schema->table_info('people');
        is(scalar @cols, 3, 'migrate added email column');
        
        subtest 'create' => sub {
            my $user = MyApp::Model::app::person->create({
                name  => 'Alice',
                email => 'alice@test.com',
                age   => 28,
            });
            $user->save;

            ok($user->id, 'id auto-generated');
            is($user->name, 'Alice', 'name set');
            is($user->email, 'alice@test.com', 'email set');
        };
        
        subtest 'find' => sub {
            my $user = MyApp::Model::app::person->find(1);
            
            ok($user, 'found user');
            is($user->name, 'Alice', 'name correct');
            is($user->email, 'alice@test.com', 'email correct');
        };
        
        subtest 'update' => sub {
            my $user = MyApp::Model::app::person->find(1);
            $user->name('Alice Updated')->update;
            
            my $user2 = MyApp::Model::app::person->find(1);
            is($user2->name, 'Alice Updated', 'name updated');
        };
        
        subtest 'where' => sub {
            MyApp::Model::app::person->create({
                name  => 'Bob',
                email => 'bob@test.com',
                age   => 35,
            });
            
            my @users = MyApp::Model::app::person->where({ age => 35 });
            is(scalar @users, 1, 'found one user with age 35');
            is($users[0]->name, 'Bob', 'correct user');
            
            my @all = MyApp::Model::app::person->all;
            is(scalar @all, 2, 'all returns all records');
        };
        
        subtest 'where - chainable ResultSet' => sub {
            MyApp::Model::User->create({
                name  => 'Carol',
                email => 'carol@test.com',
                age   => 42,
            });
            MyApp::Model::User->create({
                name  => 'Dave',
                email => 'dave@test.com',
                age   => 42,
            });
            
            my @age42 = MyApp::Model::app::person->where({ age => 42 });
            is(scalar @age42, 2, 'found two users with age 42');
            
            my @ordered = sort { $a->name cmp $b->name } @age42;
            is($ordered[0]->name, 'Carol', 'Carol is first alphabetically');
            is($ordered[1]->name, 'Dave', 'Dave is second alphabetically');
            
            my @limited = MyApp::Model::app::person->where({ age => 42 })->limit(1)->all;
            is(scalar @limited, 1, 'limit(1) returns one record');
            
            my @with_offset = MyApp::Model::app::person->where({ age => 42 })->order('name')->offset(1)->all;
            is(scalar @with_offset, 1, 'offset(1) returns one record');
            is($with_offset[0]->name, 'Dave', 'offset skips first record');
        };
        
        subtest 'first' => sub {
            my @users = MyApp::Model::app::person->all;
            my $first = MyApp::Model::app::person->first;
            ok($first, 'first returns first record');
            is($first->id, $users[0]->id, 'correct first record');
        };

        subtest 'count' => sub {
            my $count = MyApp::Model::app::person->count;
            is($count, scalar MyApp::Model::app::person->all, 'count returns correct number of records');
        };
        
        subtest 'save' => sub {
            my $user = MyApp::Model::app::person->new(
                name  => 'Charlie',
                email => 'charlie@test.com',
            );
            
            $user->save;
            ok($user->id, 'save inserted new record');
            
            $user->age(40)->save;
            
            my $user2 = MyApp::Model::app::person->find($user->id);
            is($user2->age, 40, 'save updated existing record');
        };
        
        subtest 'to_hash' => sub {
            my $user = MyApp::Model::app::person->find(1);
            my $hash = $user->to_hash;
            
            is($hash->{name}, $user->name, 'to_hash includes name');
            is($hash->{email}, $user->email, 'to_hash includes email');
            ok(!exists $hash->{dbh}, 'to_hash excludes dbh');
        };
        


        subtest 'ORM::Schema - DDL generation for SQLite' => sub {
            my $schema = ORM::Schema->new(driver => 'sqlite');

            my $sql = $schema->ddl_for_class('MyApp::Model::User', 'sqlite');
            like($sql, qr/CREATE TABLE users/,       'contains CREATE TABLE');
            like($sql, qr/id INTEGER PRIMARY KEY AUTOINCREMENT/,
                'SQLite auto-increment syntax');
            like($sql, qr/name TEXT NOT NULL/,        'name is TEXT NOT NULL');
            like($sql, qr/email TEXT/,                'email is TEXT');
            like($sql, qr/age INTEGER/,              'age is INTEGER');
            like($sql, qr/active INTEGER/,           'active is INTEGER');
            unlike($sql, qr/VARCHAR/,               'no VARCHAR for SQLite');
        };

        subtest 'ORM::Schema - DDL generation for MySQL' => sub {
            my $schema = ORM::Schema->new(driver => 'mysql');

            my $sql = $schema->ddl_for_class('MyApp::Model::User', 'mysql');
            like($sql, qr/CREATE TABLE users/,       'contains CREATE TABLE');
            like($sql, qr/id INTEGER PRIMARY KEY AUTO_INCREMENT/,
                'MySQL auto-increment syntax');
            like($sql, qr/name VARCHAR\(255\) NOT NULL/, 'name is VARCHAR(255)');
            like($sql, qr/email VARCHAR\(255\)/,     'email is VARCHAR(255)');
            like($sql, qr/age INTEGER/,              'age is INTEGER');
            like($sql, qr/active INTEGER/,           'active is INTEGER with default');
            unlike($sql, qr/AUTOINCREMENT/,          'no SQLite AUTOINCREMENT');
        };

        subtest 'ORM::Schema - DDL with length and types' => sub {
            package MyApp::Model::app::article;
            use ORM::Model 'ORM::Model', '-signatures';

            column id          => (is => 'rw', isa => 'Int', primary_key => 1);
            column title       => (is => 'rw', isa => 'Str', length => 100, required => 1);
            column body        => (is => 'rw', isa => 'Text');
            column published   => (is => 'rw', isa => 'Bool', default => 0);
            column rating      => (is => 'rw', isa => 'Float');
            column created_at  => (is => 'rw', isa => 'Timestamp');

            sub table { 'articles' }

            package main;

            my $schema = ORM::Schema->new(driver => 'mysql');
            my $sql = $schema->ddl_for_class('MyApp::Model::app::article', 'mysql');

            like($sql, qr/title VARCHAR\(100\) NOT NULL/, 'length option respected');
            like($sql, qr/body TEXT/,                      'Text maps to TEXT');
            like($sql, qr/published TINYINT\(1\)/,         'Bool maps to TINYINT(1)');
            like($sql, qr/rating DOUBLE/,                  'Float maps to DOUBLE');
            like($sql, qr/created_at TIMESTAMP/,           'Timestamp maps to TIMESTAMP');

            my $sqlite_sql = $schema->ddl_for_class('MyApp::Model::Article', 'sqlite');
            like($sqlite_sql, qr/title TEXT NOT NULL/,     'SQLite: Str is TEXT');
            like($sqlite_sql, qr/body TEXT/,               'SQLite: Text is TEXT');
            like($sqlite_sql, qr/published INTEGER/,       'SQLite: Bool is INTEGER');
            like($sqlite_sql, qr/rating REAL/,             'SQLite: Float is REAL');
            like($sqlite_sql, qr/created_at TEXT/,         'SQLite: Timestamp is TEXT');
        };

        subtest 'ORM::Model - string length validation' => sub {
            package MyApp::Model::app::ShortName;
            use ORM::Model 'ORM::Model', '-signatures';

            column id   => (is => 'rw', isa => 'Int', primary_key => 1);
            column code => (is => 'rw', isa => 'Str', length => 5);

            sub table { 'short_names' }

            package main;

            my $obj = MyApp::Model::app::ShortName->new;
            $obj->code('ABCDE');
            is($obj->code, 'ABCDE', 'value within length accepted');

            my $died = dies { $obj->code('ABCDEF') };
            like($died, qr/exceeds maximum length of 5/, 'value exceeding length rejected');
        };

        subtest 'ORM::Model - Bool coercion' => sub {
            package MyApp::Model::app::Flags;
            use ORM::Model 'ORM::Model', '-signatures';

            column id      => (is => 'rw', isa => 'Int', primary_key => 1);
            column enabled => (is => 'rw', isa => 'Bool', default => 1);
            column hidden  => (is => 'rw', isa => 'Bool', default => 0);

            sub table { 'flags' }

            package main;

            my $obj = MyApp::Model::app::Flags->new;

            $obj->enabled('yes');
            is($obj->enabled, 1, 'truthy string coerced to 1');

            $obj->enabled(0);
            is($obj->enabled, 0, 'zero stays 0');

            $obj->enabled('');
            is($obj->enabled, 0, 'empty string coerced to 0');

            $obj->enabled(42);
            is($obj->enabled, 1, 'nonzero int coerced to 1');

            $obj->hidden(undef);
            is($obj->hidden, 0, 'undef not set, default returned');

            my $fresh = MyApp::Model::app::Flags->new;
            is($fresh->enabled, 1, 'Bool default 1 returned');
            is($fresh->hidden, 0, 'Bool default 0 returned');
        };
    }
}

done_testing;
