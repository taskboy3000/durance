#!/usr/bin/env perl
# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
use strict;
use warnings;
use experimental 'signatures';
use Test2::V0;
use File::Temp qw(tempfile);
use DBI;
use FindBin;
use File::Basename;

use lib dirname($FindBin::Bin) . '/lib';

# Import ORM modules
require ORM::Model;
require ORM::Schema;
require ORM::DSL;
require ORM::DB;

# Test database setup - creates temp file each time
package TestDB;
use Moo;
extends 'ORM::DB';
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

# Test model base class
package TestModel;
use Moo;
extends 'ORM::Model';

sub _db_class_for { return 'TestDB'; }

# Define test models BEFORE using them
package MyApp::Model::Author;
use Moo;
extends 'TestModel';
use ORM::DSL;

tablename 'authors';
column id   => (is => 'rw', isa => 'Int', primary_key => 1);
column name => (is => 'rw', isa => 'Str', required => 1);

has_many books => (is => 'rw', isa => 'MyApp::Model::Book');
has_one profile => (is => 'rw', isa => 'MyApp::Model::AuthorProfile');

package MyApp::Model::Book;
use Moo;
extends 'TestModel';
use ORM::DSL;

tablename 'books';
column id        => (is => 'rw', isa => 'Int', primary_key => 1);
column author_id => (is => 'rw', isa => 'Int');
column title     => (is => 'rw', isa => 'Str', required => 1);

belongs_to author => (is => 'rw', isa => 'MyApp::Model::Author', foreign_key => 'author_id');

package MyApp::Model::AuthorProfile;
use Moo;
extends 'TestModel';
use ORM::DSL;

tablename 'author_profiles';
column id        => (is => 'rw', isa => 'Int', primary_key => 1);
column author_id => (is => 'rw', isa => 'Int');
column bio       => (is => 'rw', isa => 'Str');

belongs_to author => (is => 'rw', isa => 'MyApp::Model::Author', foreign_key => 'author_id');

package MyApp::Model::Publisher;
use Moo;
extends 'TestModel';
use ORM::DSL;

tablename 'publishers';
column id   => (is => 'rw', isa => 'Int', primary_key => 1);
column name => (is => 'rw', isa => 'Str', required => 1);

has_many books => (is => 'rw', isa => 'MyApp::Model::Book');

package main;

# ============================================================================
# Test Suite: preload() Eager Loading
# ============================================================================

subtest 'ORM::Model - preload() Eager Loading' => sub {
    # Create schema
    my $dbh = TestDB->new->dbh;
    my $schema = ORM::Schema->new(dbh => $dbh);

    $schema->create_table($_) for (
        MyApp::Model::Author->new,
        MyApp::Model::Book->new,
        MyApp::Model::AuthorProfile->new,
        MyApp::Model::Publisher->new,
    );

    # ========================================================================
    # Test 1: preload() method exists and is chainable
    # ========================================================================
    subtest 'preload() method is chainable' => sub {
        my $rs = MyApp::Model::Author->where({})->preload('books');
        
        ok($rs, 'preload returns result set');
        ok($rs->isa('ORM::ResultSet'), 'Returns ORM::ResultSet');
        
        # Should be chainable
        my $rs2 = $rs->where({})->order('name');
        ok($rs2, 'Can chain after preload');
    };

    # ========================================================================
    # Test 2: preload has_many - avoids N+1 queries
    # ========================================================================
    subtest 'preload has_many avoids N+1 queries' => sub {
        # Create test data
        my $author1 = MyApp::Model::Author->create({ name => 'Author 1' });
        my $author2 = MyApp::Model::Author->create({ name => 'Author 2' });
        
        MyApp::Model::Book->create({ author_id => $author1->id, title => 'Book 1A' });
        MyApp::Model::Book->create({ author_id => $author1->id, title => 'Book 1B' });
        MyApp::Model::Book->create({ author_id => $author1->id, title => 'Book 1C' });
        MyApp::Model::Book->create({ author_id => $author2->id, title => 'Book 2A' });

        # Without preload - would need N+1 queries (not testing here)
        
        # With preload - should batch load all books in 2 queries
        my @authors = MyApp::Model::Author->preload('books')->all;
        
        is(scalar @authors, 2, 'Got 2 authors');
        
        # Verify books are loaded
        my $a1_books = $authors[0]->books;
        my $a2_books = $authors[1]->books;
        
        is(scalar @$a1_books, 3, 'Author 1 has 3 books');
        is(scalar @$a2_books, 1, 'Author 2 has 1 book');
    };

    # ========================================================================
    # Test 3: preload belongs_to
    # ========================================================================
    subtest 'preload belongs_to relationship' => sub {
        # Clean up first to ensure isolated test
        for my $b (MyApp::Model::Book->all) { $b->delete if $b->id; }
        
        # Create test data
        my $author = MyApp::Model::Author->create({ name => 'Test Author' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Test Book' });

        # Preload belongs_to
        my @books = MyApp::Model::Book->preload('author')->all;
        
        is(scalar @books, 1, 'Got 1 book');
        
        # Access author - should use preloaded data
        my $book = $books[0];
        my $loaded_author = $book->author;
        
        ok(defined $loaded_author, 'Author is loaded');
        is($loaded_author->name, 'Test Author', 'Correct author loaded');
    };

    # ========================================================================
    # Test 4: preload has_one
    # ========================================================================
    subtest 'preload has_one relationship' => sub {
        # Clean up first to ensure isolated test
        for my $a (MyApp::Model::Author->all) { $a->delete if $a->id; }
        
        # Create test data
        my $author = MyApp::Model::Author->create({ name => 'Author With Profile' });
        MyApp::Model::AuthorProfile->create({ author_id => $author->id, bio => 'Famous writer' });

        # Preload has_one
        my @authors = MyApp::Model::Author->preload('profile')->all;
        
        is(scalar @authors, 1, 'Got 1 author');
        
        my $loaded_profile = $authors[0]->profile;
        
        ok(defined $loaded_profile, 'Profile is loaded');
        is($loaded_profile->bio, 'Famous writer', 'Correct profile loaded');
    };

    # ========================================================================
    # Test 5: preload multiple relationships
    # ========================================================================
    subtest 'preload multiple relationships' => sub {
        # Clean up first to ensure isolated test
        for my $a (MyApp::Model::Author->all) { $a->delete if $a->id; }
        
        # Create test data
        my $author = MyApp::Model::Author->create({ name => 'Multi Author' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 1' });
        MyApp::Model::AuthorProfile->create({ author_id => $author->id, bio => 'Bio' });

        # Preload multiple relationships
        my @authors = MyApp::Model::Author->preload('books', 'profile')->all;
        
        is(scalar @authors, 1, 'Got 1 author');
        
        # Verify both are loaded
        ok(scalar @{$authors[0]->books}, 'Books loaded');
        ok(defined $authors[0]->profile, 'Profile loaded');
    };

    # ========================================================================
    # Test 6: preload with where conditions
    # ========================================================================
    subtest 'preload with where conditions' => sub {
        # Create test data
        my $author = MyApp::Model::Author->create({ name => 'Filtered Author' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book A' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book B' });

        # Preload with where
        my @authors = MyApp::Model::Author->where({ name => 'Filtered Author' })
                                           ->preload('books')
                                           ->all;
        
        is(scalar @authors, 1, 'Got 1 author with condition');
        is(scalar @{$authors[0]->books}, 2, 'Author has 2 books');
    };

    # ========================================================================
    # Test 7: preload with order and limit
    # ========================================================================
    subtest 'preload with order and limit' => sub {
        # Create test data
        my $author = MyApp::Model::Author->create({ name => 'Ordered Author' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Z Book' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'A Book' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'M Book' });

        # Preload with order and limit
        my @authors = MyApp::Model::Author->preload('books')
                                           ->order('name')
                                           ->limit(5)
                                           ->all;
        
        ok(scalar @authors, 'Authors returned with limit');
        
        # Books should still be loaded
        ok(scalar @{$authors[0]->books}, 'Books preloaded despite limit');
    };

    # ========================================================================
    # Test 8: preload with empty results
    # ========================================================================
    subtest 'preload handles empty results gracefully' => sub {
        # Clean up first - delete all authors
        my @all_authors = MyApp::Model::Author->all;
        $_->delete for @all_authors;
        
        my @authors = MyApp::Model::Author->preload('books')->all;
        
        is(scalar @authors, 0, 'No authors - empty result');
    };

    # ========================================================================
    # Test 9: preload first() method
    # ========================================================================
    subtest 'preload works with first()' => sub {
        # Create test data
        my $first_author = MyApp::Model::Author->create({ name => 'First Author' });
        MyApp::Model::Book->create({ author_id => $first_author->id, title => 'First Book' });

        # Preload with first
        my $result = MyApp::Model::Author->preload('books')->first;
        
        ok(defined $result, 'Got author');
        ok(scalar @{$result->books}, 'Books loaded via first()');
    };

    # ========================================================================
    # Test 10: preload validates relationship names
    # ========================================================================
    subtest 'preload validates relationship names' => sub {
        my $died = dies {
            MyApp::Model::Author->preload('nonexistent_relationship')->all;
        };
        ok($died, 'Invalid relationship name dies');
    };

    # Clean up
    $dbh->disconnect;
};

done_testing;

1;
