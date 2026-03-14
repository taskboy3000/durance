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

use File::Temp qw(tempfile);
use Test2::V0;

use MyApp::DB;

my $db_file = File::Temp->new(SUFFIX => '.db');
my $db_path = $db_file->filename;
$db_file = undef;

my $db = MyApp::DB->new(dsn => "dbi:SQLite:$db_path");

my $dbh = $db->dbh;
$dbh->do('CREATE TABLE companies (id INTEGER PRIMARY KEY, name TEXT)');
$dbh->do('CREATE TABLE employees (id INTEGER PRIMARY KEY, company_id INTEGER, name TEXT, department TEXT)');

{
    package MyApp::Model::Company;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'companies';
    column id   => (is => 'rw', isa => 'Int', primary_key => 1);
    column name => (is => 'rw', isa => 'Str');

    has_many employees => (is => 'rw', isa => 'MyApp::Model::Employee');

    sub db { $db }

    1;
}

{
    package MyApp::Model::Employee;
    use Moo;
    extends 'Durance::Model';
    use Durance::DSL;

    tablename 'employees';
    column id         => (is => 'rw', isa => 'Int', primary_key => 1);
    column company_id => (is => 'rw', isa => 'Int');
    column name       => (is => 'rw', isa => 'Str');
    column department => (is => 'rw', isa => 'Str');

    belongs_to company => (is => 'rw', isa => 'MyApp::Model::Company', foreign_key => 'company_id');

    sub db { $db }

    1;
}

my $acme = MyApp::Model::Company->create({ name => 'Acme Corp' });
my $globex = MyApp::Model::Company->create({ name => 'Globex Inc' });

MyApp::Model::Employee->create({ company_id => $acme->id, name => 'Alice', department => 'Engineering' });
MyApp::Model::Employee->create({ company_id => $acme->id, name => 'Bob', department => 'Sales' });
MyApp::Model::Employee->create({ company_id => $globex->id, name => 'Carol', department => 'Engineering' });

subtest 'Column aliasing - belongs_to JOIN (tests column collision)' => sub {
    my @emps = MyApp::Model::Employee->where({})
        ->add_joins('company')
        ->order('employees.name')
        ->all;

    is(scalar(@emps), 3, 'JOIN returns all employees');
    
    # Find Alice by id (id=1)
    my $alice = (grep { $_->id == 1 } @emps)[0];
    ok($alice, 'Alice exists');
    
    # With column aliasing, employee name should be preserved
    is($alice->name, 'Alice', 'employee name is Alice (not overwritten by company name)');
    ok($alice->company_id, 'company_id is set');
    
    my $company = $alice->company;
    ok($company, 'company relationship works');
    is($company->name, 'Acme Corp', 'company name is Acme Corp');
    is($company->id, $acme->id, 'company id matches');
};

subtest 'Column aliasing - has_many JOIN' => sub {
    my @cos = MyApp::Model::Company->where({})
        ->add_joins('employees')
        ->order('companies.name')
        ->all;

    # Note: has_many JOINs duplicate rows (one per employee)
    # This is expected behavior - use DISTINCT or preload for different behavior
    ok(scalar(@cos) >= 2, 'JOIN returns at least 2 companies');
    
    # Get unique companies
    my %unique;
    for my $c (@cos) {
        $unique{$c->id} = $c;
    }
    my @unique_companies = values %unique;
    
    my $acme_result = (grep { $_->name eq 'Acme Corp' } @unique_companies)[0];
    ok($acme_result, 'Acme exists');
    
    is($acme_result->name, 'Acme Corp', 'company name preserved');
    
    my @emps = $acme_result->employees;
    is(scalar(@emps), 2, 'Acme has 2 employees');
};

subtest 'Column aliasing - both columns accessible' => sub {
    my @emps = MyApp::Model::Employee->where({})
        ->add_joins('company')
        ->all;

    for my $emp (@emps) {
        ok(defined $emp->name, 'employee name defined: ' . ($emp->name // 'undef'));
        my $company = $emp->company;
        ok(defined $company->name, 'company name defined: ' . ($company->name // 'undef'));
    }
};

$db->disconnect_all;

unlink $db_path if -e $db_path;

done_testing;
