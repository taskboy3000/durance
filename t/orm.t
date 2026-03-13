#!/usr/bin/env perl
# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
use strict;
use warnings;

use File::Basename;
use FindBin;
BEGIN {
    $::PROJ_ROOT = dirname($FindBin::Bin);
}

use lib ("$::PROJ_ROOT/lib", "$::PROJ_ROOT/t");
use experimental 'signatures';

use Test2::V0;

use MyApp::DB;
use ORM::Schema;

our $gDBName = './MyApp/var/test.db';

sub create_test_db ($app) {
    if (-e $gDBName) {
        unlink $gDBName;
    }
    ORM::Schema->migrate_all($app);
}

subtest 'ORM::DB - attributes and methods' => sub {
    package TestDB;
    use Moo;
    extends 'ORM::DB';

    sub _build_dsn { 'dbi:SQLite:dbname=:memory:' }

    package main;

    my $db = TestDB->new;

    subtest 'attributes' => sub {
        is($db->dsn, 'dbi:SQLite:dbname=:memory:', 'dsn returns correct DSN');

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

    package main;
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
