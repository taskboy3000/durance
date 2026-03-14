use strict;
use warnings;
use experimental 'signatures';

use File::Basename;
use FindBin;
BEGIN {
    $::PROJ_ROOT = dirname($FindBin::Bin);
}
use lib ("$::PROJ_ROOT/lib", "$::PROJ_ROOT/t");

use File::Temp qw(tempfile);
use Test2::V0;

use MyApp::DB;

my $db_file = File::Temp->new(SUFFIX => '.db');
my $db_path = $db_file->filename;
$db_file = undef;

my $db = MyApp::DB->new(dsn => "dbi:SQLite:$db_path");

my $dbh = $db->dbh;
$dbh->do('CREATE TABLE authors (id INTEGER PRIMARY KEY, name TEXT)');
$dbh->do('CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT)');
$dbh->do('CREATE TABLE author_books (author_id INTEGER, book_id INTEGER)');

{
    package MyApp::Model::Author;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'authors';
    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str');

    many_to_many books => (
        through => 'author_books',
        using   => 'book_id',
        isa     => 'MyApp::Model::Book',
    );

    sub db { $db }

    1;
}

{
    package MyApp::Model::Book;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'books';
    column id    => (is => 'rw', isa => 'Int', primary_key => 1);
    column title => (is => 'rw', isa => 'Str');

    many_to_many authors => (
        through => 'author_books',
        using   => 'author_id',
        isa     => 'MyApp::Model::Author',
    );

    sub db { $db }

    1;
}

subtest 'many_to_many - define relationship' => sub {
    my $rels = MyApp::Model::Author->many_to_many_relations;
    ok($rels, 'many_to_many_relations method exists');
    is(keys %$rels, 1, 'one many_to_many relationship');
    ok(exists $rels->{books}, 'books relationship defined');
    is($rels->{books}{through}, 'author_books', 'through table correct');
    is($rels->{books}{using}, 'book_id', 'using column correct');
};

subtest 'many_to_many - create and link records' => sub {
    my $author = MyApp::Model::Author->create({ name => 'Alice' });
    ok($author->id, 'author created with id');

    my $book1 = MyApp::Model::Book->create({ title => 'Book One' });
    my $book2 = MyApp::Model::Book->create({ title => 'Book Two' });

    $dbh->do('INSERT INTO author_books (author_id, book_id) VALUES (?, ?)',
        {}, $author->id, $book1->id);
    $dbh->do('INSERT INTO author_books (author_id, book_id) VALUES (?, ?)',
        {}, $author->id, $book2->id);

    my @books = $author->books;
    is(scalar(@books), 2, 'author has 2 books');
    my %titles = map { $_->title => 1 } @books;
    ok($titles{'Book One'}, 'contains Book One');
    ok($titles{'Book Two'}, 'contains Book Two');
};

subtest 'many_to_many - reverse direction' => sub {
    my $book = MyApp::Model::Book->find(1);
    my @authors = $book->authors;
    is(scalar(@authors), 1, 'book has 1 author');
    is($authors[0]->name, 'Alice', 'author is Alice');
};

subtest 'many_to_many - empty relationship' => sub {
    my $new_author = MyApp::Model::Author->create({ name => 'Bob' });
    my @books = $new_author->books;
    is(scalar(@books), 0, 'new author has no books');
};

subtest 'many_to_many - all_relations includes many_to_many' => sub {
    my $all = MyApp::Model::Author->all_relations;
    ok(exists $all->{books}, 'books in all_relations');
    is($all->{books}, 'many_to_many', 'books is many_to_many type');
};

$db->disconnect_all;

unlink $db_path if -e $db_path;

done_testing;
