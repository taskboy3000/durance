#!/usr/bin/env perl
# Test file for include() method - JOIN + record inflation
use strict;
use warnings;
use experimental 'signatures';
use Test2::V0;
use FindBin;
use File::Basename;

use lib dirname($FindBin::Bin) . '/lib';

require Durance::Model;
require Durance::Schema;
require Durance::DSL;
require Durance::DB;

package TestDB;
use Moo;
extends 'Durance::DB';
use File::Temp qw(tempfile);

has 'temp_file' => (is => 'lazy');

sub _build_temp_file ($self) {
    my ($fh, $filename) = tempfile(SUFFIX => '.db');
    close($fh);
    return $filename;
}

sub _build_dsn ($self) {
    return "dbi:SQLite:dbname=" . $self->temp_file;
}

package TestModel;
use Moo;
extends 'Durance::Model';

sub _db_class_for { return 'TestDB'; }

package MyApp::Model::Author;
use Moo;
extends 'TestModel';
use Durance::DSL;

tablename 'authors';
column id   => (is => 'rw', isa => 'Int', primary_key => 1);
column name => (is => 'rw', isa => 'Str', required => 1);

has_many books => (is => 'rw', isa => 'MyApp::Model::Book');
has_one profile => (is => 'rw', isa => 'MyApp::Model::AuthorProfile');

package MyApp::Model::Book;
use Moo;
extends 'TestModel';
use Durance::DSL;

tablename 'books';
column id        => (is => 'rw', isa => 'Int', primary_key => 1);
column author_id => (is => 'rw', isa => 'Int');
column title     => (is => 'rw', isa => 'Str', required => 1);

belongs_to author => (is => 'rw', isa => 'MyApp::Model::Author', foreign_key => 'author_id');

package MyApp::Model::AuthorProfile;
use Moo;
extends 'TestModel';
use Durance::DSL;

tablename 'author_profiles';
column id        => (is => 'rw', isa => 'Int', primary_key => 1);
column author_id => (is => 'rw', isa => 'Int');
column bio       => (is => 'rw', isa => 'Str');

belongs_to author => (is => 'rw', isa => 'MyApp::Model::Author', foreign_key => 'author_id');

package main;

my $db = TestDB->new;
my $dbh = $db->dbh;

my $schema = Durance::Schema->new(dbh => $dbh);
$schema->create_table($_) for (
    MyApp::Model::Author->new,
    MyApp::Model::Book->new,
    MyApp::Model::AuthorProfile->new,
);

subtest 'include() method exists and returns chainable ResultSet' => sub {
    my $rs = MyApp::Model::Author->where({});
    ok($rs->can('include'), 'ResultSet can call include');
    
    my $rs_with_include = $rs->include('books');
    is(ref($rs_with_include), 'Durance::ResultSet', 'include() returns ResultSet');
    is($rs_with_include->include_specs, ['books'], 'include_specs attribute set');
};

subtest 'include() with belongs_to (to-one)' => sub {
    $dbh->do("DELETE FROM books");
    $dbh->do("DELETE FROM authors");
    $dbh->do("DELETE FROM author_profiles");
    
    my $author = MyApp::Model::Author->create({ name => 'Alice' });
    my $book = MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 1' });
    my $book2 = MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 2' });
    
    my @books = MyApp::Model::Book->where({})->include('author')->all;
    
    is(scalar(@books), 2, 'got 2 books');
    
    my $first_book = $books[0];
    ok($first_book->author, 'author is loaded');
    is($first_book->author->name, 'Alice', 'author name is correct');
    is($first_book->author->id, $author->id, 'author id is correct');
};

subtest 'include() with has_many (to-many)' => sub {
    $dbh->do("DELETE FROM books");
    $dbh->do("DELETE FROM authors");
    $dbh->do("DELETE FROM author_profiles");
    
    my $author1 = MyApp::Model::Author->create({ name => 'Alice' });
    my $author2 = MyApp::Model::Author->create({ name => 'Bob' });
    
    MyApp::Model::Book->create({ author_id => $author1->id, title => 'Alice Book 1' });
    MyApp::Model::Book->create({ author_id => $author1->id, title => 'Alice Book 2' });
    MyApp::Model::Book->create({ author_id => $author2->id, title => 'Bob Book 1' });
    
    my @authors = MyApp::Model::Author->where({})->include('books')->all;
    
    is(scalar(@authors), 2, 'got 2 authors');
    
    my ($alice) = grep { $_->name eq 'Alice' } @authors;
    ok($alice->books, 'books relationship loaded');
    is(scalar(@{$alice->books}), 2, 'Alice has 2 books');
    
    my ($bob) = grep { $_->name eq 'Bob' } @authors;
    is(scalar(@{$bob->books}), 1, 'Bob has 1 book');
};

subtest 'include() with has_one (to-one)' => sub {
    $dbh->do("DELETE FROM books");
    $dbh->do("DELETE FROM authors");
    $dbh->do("DELETE FROM author_profiles");
    
    my $author = MyApp::Model::Author->create({ name => 'Alice' });
    MyApp::Model::AuthorProfile->create({ author_id => $author->id, bio => 'Great writer' });
    
    my @authors = MyApp::Model::Author->where({})->include('profile')->all;
    
    is(scalar(@authors), 1, 'got 1 author');
    ok($authors[0]->profile, 'profile is loaded');
    is($authors[0]->profile->bio, 'Great writer', 'profile bio is correct');
};

subtest 'include() with multiple relationships' => sub {
    $dbh->do("DELETE FROM books");
    $dbh->do("DELETE FROM authors");
    $dbh->do("DELETE FROM author_profiles");
    
    my $author = MyApp::Model::Author->create({ name => 'Alice' });
    MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 1' });
    MyApp::Model::AuthorProfile->create({ author_id => $author->id, bio => 'Bio' });
    
    my @authors = MyApp::Model::Author->where({})->include('books', 'profile')->all;
    
    is(scalar(@authors), 1, 'got 1 author');
    ok($authors[0]->books, 'books loaded');
    ok($authors[0]->profile, 'profile loaded');
    is(scalar(@{$authors[0]->books}), 1, 'has 1 book');
    is($authors[0]->profile->bio, 'Bio', 'profile correct');
};

subtest 'include() with WHERE conditions' => sub {
    $dbh->do("DELETE FROM books");
    $dbh->do("DELETE FROM authors");
    $dbh->do("DELETE FROM author_profiles");
    
    my $author = MyApp::Model::Author->create({ name => 'Alice' });
    MyApp::Model::Book->create({ author_id => $author->id, title => 'Book A' });
    MyApp::Model::Book->create({ author_id => $author->id, title => 'Book B' });
    
    my @authors = MyApp::Model::Author->where({ name => 'Alice' })->include('books')->all;
    
    is(scalar(@authors), 1, 'filtered to 1 author');
    is(scalar(@{$authors[0]->books}), 2, 'author has 2 books');
};

subtest 'include() error - invalid relationship' => sub {
    my $exception = dies {
        MyApp::Model::Author->where({})->include('nonexistent')->all;
    };
    ok($exception, 'dies on invalid relationship');
    like($exception, qr/no relationship named/, 'error message mentions relationship');
};

subtest 'include() works with belongs_to' => sub {
    $dbh->do("DELETE FROM books");
    $dbh->do("DELETE FROM authors");
    
    my $author = MyApp::Model::Author->create({ name => 'Alice' });
    MyApp::Model::Book->create({ author_id => $author->id, title => 'Test Book' });
    
    my @books = MyApp::Model::Book->where({})->include('author')->all;
    is(scalar(@books), 1, 'got 1 book');
    ok($books[0]->author, 'author loaded');
    is($books[0]->author->name, 'Alice', 'author name correct');
};

done_testing;
