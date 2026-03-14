# cpanfile - Perl dependencies for Durance ORM
requires 'Moo';
requires 'DBI';
requires 'DBD::SQLite';

on 'test' => sub {
    requires 'Test2::Suite';
};
