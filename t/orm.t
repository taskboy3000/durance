#!/usr/bin/env perl
use strict;
use warnings;
use lib ('lib', 't', ($ENV{PERL5LIB} || '.'));

use Test2::V0;
use DBI;
use File::Temp qw(tempfile);
use ORM::Model;
use ORM::Schema;
use MyApp::Model::User;
use MyApp::Model::Post;

my $TEST_DBH;

sub create_test_db {
    my ($fh, $filename) = tempfile(SUFFIX => '.db', UNLINK => 1);
    close $fh;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$filename", '', '', { RaiseError => 1 });
    return $dbh;
}

sub configure_test_db {
    my ($dbh) = @_;
    $TEST_DBH = $dbh;
    
    no strict 'refs';
    *{"MyApp::DB::dbh"} = sub {
        return $TEST_DBH;
    };
}

subtest 'ORM::Model - Basic attributes' => sub {
    my $dbh = create_test_db();
    
    my $obj = ORM::Model->new(dbh => $dbh);
    is($obj->dbh, $dbh, 'dbh getter works');
    
    my $obj2 = ORM::Model->new;
    $obj2->dbh($dbh);
    is($obj2->dbh, $dbh, 'dbh setter works');
    
    $dbh->disconnect;
};

subtest 'ORM::Model - table name derivation' => sub {
    is(ORM::Model->table, 'orm_models', 'table name derived correctly');
};

subtest 'ORM::Model - column definition' => sub {
    my $dbh = create_test_db();
    
    my @cols = @{MyApp::Model::User->columns};
    is(\@cols, array { item 'id'; item 'name'; item 'email'; item 'age'; item 'active' }, 'columns defined');
    
    is(MyApp::Model::User->primary_key, 'id', 'primary key is id');
    
    my $meta = MyApp::Model::User->column_meta('email');
    is($meta->{required}, 1, 'email is required');
    is($meta->{unique}, 1, 'email is unique');
    
    $dbh->disconnect;
};

subtest 'ORM::Model - instance attribute access' => sub {
    my $dbh = create_test_db();
    
    my $user = MyApp::Model::User->new(
        name  => 'John',
        email => 'john@test.com',
        age   => 25,
        dbh   => $dbh,
    );
    
    is($user->name, 'John', 'name getter');
    $user->name('Jane');
    is($user->name, 'Jane', 'name setter returns self');
    
    is($user->email, 'john@test.com', 'email getter');
    is($user->age, 25, 'age getter');
    
    $dbh->disconnect;
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

subtest 'ORM::Schema - create table for class' => sub {
    my $dbh = create_test_db();
    my $schema = ORM::Schema->new(dbh => $dbh);
    
    ok(!$schema->table_exists('posts'), 'posts table does not exist');
    
    $schema->create_table_for_class('MyApp::Model::Post');
    
    ok($schema->table_exists('posts'), 'posts table created via class');
    
    $dbh->disconnect;
};

subtest 'ORM::Schema - migrate adds columns' => sub {
    my $dbh = create_test_db();
    
    $dbh->do('CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT)');
    
    my $schema = ORM::Schema->new(dbh => $dbh);
    
    package MyApp::Model::Person;
    use Mojo::Base 'ORM::Model', '-signatures';
    use ORM::Model;
    
    column id    => (is => 'rw', isa => 'Int', primary_key => 1);
    column name  => (is => 'rw', isa => 'Str');
    column email => (is => 'rw', isa => 'Str');
    
    sub table { 'people' }
    
    package main;
    
    $schema->migrate(MyApp::Model::Person->new);
    
    my @cols = $schema->table_info('people');
    is(scalar @cols, 3, 'migrate added email column');
    
    $dbh->disconnect;
};

subtest 'ORM::Model - CRUD operations' => sub {
    my $dbh = create_test_db();
    my $schema = ORM::Schema->new(dbh => $dbh);
    $schema->create_table_for_class('MyApp::Model::User');
    
    configure_test_db($dbh);
    
    subtest 'create' => sub {
        my $user = MyApp::Model::User->create({
            name  => 'Alice',
            email => 'alice@test.com',
            age   => 28,
        });
        
        ok($user->id, 'id auto-generated');
        is($user->name, 'Alice', 'name set');
        is($user->email, 'alice@test.com', 'email set');
    };
    
    subtest 'find' => sub {
        my $user = MyApp::Model::User->find(1);
        
        ok($user, 'found user');
        is($user->name, 'Alice', 'name correct');
        is($user->email, 'alice@test.com', 'email correct');
    };
    
    subtest 'update' => sub {
        my $user = MyApp::Model::User->find(1);
        $user->name('Alice Updated')->update;
        
        my $user2 = MyApp::Model::User->find(1);
        is($user2->name, 'Alice Updated', 'name updated');
    };
    
    subtest 'where' => sub {
        MyApp::Model::User->create({
            name  => 'Bob',
            email => 'bob@test.com',
            age   => 35,
        });
        
        my @users = MyApp::Model::User->where({ age => 35 });
        is(scalar @users, 1, 'found one user with age 35');
        is($users[0]->name, 'Bob', 'correct user');
        
        my @all = MyApp::Model::User->all;
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
        
        my @age42 = MyApp::Model::User->where({ age => 42 });
        is(scalar @age42, 2, 'found two users with age 42');
        
        my @ordered = sort { $a->name cmp $b->name } @age42;
        is($ordered[0]->name, 'Carol', 'Carol is first alphabetically');
        is($ordered[1]->name, 'Dave', 'Dave is second alphabetically');
        
        my @limited = MyApp::Model::User->where({ age => 42 })->limit(1)->all;
        is(scalar @limited, 1, 'limit(1) returns one record');
        
        my @with_offset = MyApp::Model::User->where({ age => 42 })->order('name')->offset(1)->all;
        is(scalar @with_offset, 1, 'offset(1) returns one record');
        is($with_offset[0]->name, 'Dave', 'offset skips first record');
    };
    
    subtest 'delete' => sub {
        my $user = MyApp::Model::User->find(2);
        $user->delete;
        
        my $deleted = MyApp::Model::User->find(2);
        ok(!$deleted, 'user deleted');
        
        my @remaining = MyApp::Model::User->all;
        is(scalar @remaining, 3, 'three users remain');
    };
    
    subtest 'save' => sub {
        my $user = MyApp::Model::User->new(
            name  => 'Charlie',
            email => 'charlie@test.com',
            dbh   => $dbh,
        );
        
        $user->save;
        ok($user->id, 'save inserted new record');
        
        $user->age(40)->save;
        
        my $user2 = MyApp::Model::User->find($user->id);
        is($user2->age, 40, 'save updated existing record');
    };
    
    subtest 'to_hash' => sub {
        my $user = MyApp::Model::User->find(1);
        my $hash = $user->to_hash;
        
        is($hash->{name}, 'Alice Updated', 'to_hash includes name');
        is($hash->{email}, 'alice@test.com', 'to_hash includes email');
        ok(!exists $hash->{dbh}, 'to_hash excludes dbh');
    };
    
    $dbh->disconnect;
};

subtest 'ORM::Model - global dbh' => sub {
    my $dbh = create_test_db();
    
    ORM::Model->dbh($dbh);
    is(ORM::Model->dbh, $dbh, 'global dbh set');
    
    my $user = MyApp::Model::User->new(name => 'Test', email => 'test@test.com');
    is($user->dbh, $dbh, 'instance inherits global dbh');
    
    $dbh->disconnect;
};

subtest 'ORM::Model - error handling' => sub {
    skip_all 'Error handling tests need review for new auto-connect behavior';
};

done_testing;
