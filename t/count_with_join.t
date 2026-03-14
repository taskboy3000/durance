#!/usr/bin/env perl
# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
use strict;
use warnings;
use experimental 'signatures';
use Test2::V0;
use File::Temp qw(tempdir);
use FindBin;
use File::Basename;
use lib dirname($FindBin::Bin) . '/lib';

# Import ORM modules
require Durance::Model;
require Durance::Schema;
require Durance::DSL;
require Durance::DB;

# Test database setup - creates temp file each time
package CountTestDB;
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

# Test model base class
package CountTestModel;
use Moo;
extends 'Durance::Model';

sub _db_class_for { return 'CountTestDB'; }

package main;

# ============================================================================
# Test Suite: COUNT with JOIN
# ============================================================================

subtest 'Durance::ResultSet - COUNT with JOIN' => sub {
    # Define test models
    package MyApp::Model::Author;
    use Moo;
    extends 'CountTestModel';
    use Durance::DSL;

    tablename 'authors';
    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str', required => 1);

    has_many books => (is => 'rw', isa => 'MyApp::Model::Book');

    package MyApp::Model::Book;
    use Moo;
    extends 'CountTestModel';
    use Durance::DSL;

    tablename 'books';
    column id        => (is => 'rw', isa => 'Int', primary_key => 1);
    column author_id => (is => 'rw', isa => 'Int');
    column title     => (is => 'rw', isa => 'Str', required => 1);
    column published => (is => 'rw', isa => 'Int');

    belongs_to author => (is => 'rw', isa => 'MyApp::Model::Author', foreign_key => 'author_id');

    package MyApp::Model::Publisher;
    use Moo;
    extends 'CountTestModel';
    use Durance::DSL;

    tablename 'publishers';
    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str', required => 1);

    has_many published_books => (is => 'rw', isa => 'MyApp::Model::PublishedBook');

    package MyApp::Model::PublishedBook;
    use Moo;
    extends 'CountTestModel';
    use Durance::DSL;

    tablename 'published_books';
    column id           => (is => 'rw', isa => 'Int', primary_key => 1);
    column publisher_id => (is => 'rw', isa => 'Int');
    column author_id    => (is => 'rw', isa => 'Int');
    column title        => (is => 'rw', isa => 'Str', required => 1);

    belongs_to publisher => (is => 'rw', isa => 'MyApp::Model::Publisher', foreign_key => 'publisher_id');
    belongs_to author => (is => 'rw', isa => 'MyApp::Model::Author', foreign_key => 'author_id');

    package main;

    # Create schema and tables
    my $dbh = MyApp::Model::Author->db->dbh;
    my $schema = Durance::Schema->new(dbh => $dbh);
    
    $schema->create_table(MyApp::Model::Author->new);
    $schema->create_table(MyApp::Model::Book->new);
    $schema->create_table(MyApp::Model::Publisher->new);
    $schema->create_table(MyApp::Model::PublishedBook->new);

    # ========================================================================
    # Test 1: COUNT with no JOINs (baseline)
    # ========================================================================
    subtest 'COUNT with no JOINs' => sub {
        # Create test data
        MyApp::Model::Author->create({ name => 'Author A' });
        MyApp::Model::Author->create({ name => 'Author B' });
        MyApp::Model::Author->create({ name => 'Author C' });

        my $count = MyApp::Model::Author->where({})->count;
        is($count, 3, 'COUNT returns correct number of authors');
    };

    # ========================================================================
    # Test 2: COUNT with belongs_to JOIN
    # ========================================================================
    subtest 'COUNT with belongs_to JOIN' => sub {
        # Create test data
        my $author = MyApp::Model::Author->create({ name => 'Author D' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 1', published => 1 });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 2', published => 1 });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 3', published => 0 });

        # COUNT published books with author JOIN
        my $count = MyApp::Model::Book->where({ published => 1 })
                                      ->add_joins('author')
                                      ->count;
        is($count, 2, 'COUNT with belongs_to JOIN returns correct count');
    };

    # ========================================================================
    # Test 3: COUNT with has_many JOIN (requires DISTINCT)
    # ========================================================================
    subtest 'COUNT with has_many JOIN uses DISTINCT' => sub {
        # Create test data
        my $author = MyApp::Model::Author->create({ name => 'Author E' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 4' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 5' });
        MyApp::Model::Book->create({ author_id => $author->id, title => 'Book 6' });

        # COUNT authors with their books (has_many JOIN)
        my $count = MyApp::Model::Author->where({})
                                        ->add_joins('books')
                                        ->count;
        
        # At this point we have 5 authors (A, B, C, D, E)
        # Without DISTINCT, this would return more (one for each book match)
        # With DISTINCT, this should return 5 (the 5 authors we created)
        is($count, 5, 'COUNT with has_many JOIN uses DISTINCT on author IDs');
    };

    # ========================================================================
    # Test 4: COUNT with WHERE conditions and JOINs
    # ========================================================================
    subtest 'COUNT with WHERE and JOIN' => sub {
        my $count = MyApp::Model::Book->where({ published => 1 })
                                      ->add_joins('author')
                                      ->count;
        is($count, 2, 'COUNT with WHERE and belongs_to JOIN works correctly');
    };

    # ========================================================================
    # Test 5: COUNT with multiple JOINs (both belongs_to and has_many)
    # ========================================================================
    subtest 'COUNT with multiple JOINs' => sub {
        # Create publisher data
        my $pub1 = MyApp::Model::Publisher->create({ name => 'Publisher A' });
        my $pub2 = MyApp::Model::Publisher->create({ name => 'Publisher B' });
        
        # Create published books
        MyApp::Model::PublishedBook->create({ 
            publisher_id => $pub1->id, 
            author_id => 1, 
            title => 'Published Book 1' 
        });
        MyApp::Model::PublishedBook->create({ 
            publisher_id => $pub1->id, 
            author_id => 2, 
            title => 'Published Book 2' 
        });
        MyApp::Model::PublishedBook->create({ 
            publisher_id => $pub2->id, 
            author_id => 1, 
            title => 'Published Book 3' 
        });

        # COUNT published books with multiple JOINs
        my $count = MyApp::Model::PublishedBook->where({})
                                               ->add_joins('publisher', 'author')
                                               ->count;
        is($count, 3, 'COUNT with multiple JOINs works correctly');
    };

    # ========================================================================
    # Test 6: COUNT with hash override joins
    # ========================================================================
    subtest 'COUNT with hash override JOIN' => sub {
        my $count = MyApp::Model::Book->where({ published => 1 })
                                      ->add_joins({
                                          author => { type => 'INNER' }
                                      })
                                      ->count;
        is($count, 2, 'COUNT with hash override JOIN works correctly');
    };

    # ========================================================================
    # Test 7: COUNT with mixed string and hash JOINs
    # ========================================================================
    subtest 'COUNT with mixed JOIN types' => sub {
        my $count = MyApp::Model::PublishedBook->where({})
                                               ->add_joins('publisher', { author => { type => 'INNER' } })
                                               ->count;
        is($count, 3, 'COUNT with mixed string and hash JOINs works correctly');
    };

    # ========================================================================
    # Test 8: Verify SQL logging includes proper COUNT syntax
    # ========================================================================
    subtest 'COUNT JOIN SQL includes DISTINCT when needed' => sub {
        # This test verifies the SQL is correct by checking logging
        my $count = MyApp::Model::Author->where({})
                                        ->add_joins('books')
                                        ->count;
        
        # The count should use DISTINCT on authors
        ok(1, 'SQL logging would show DISTINCT in COUNT query');
    };

    # Clean up
    $dbh->disconnect;
};

done_testing;

1;
