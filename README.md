# Durance

A lightweight ActiveRecord-style ORM for Perl using Moo and DBI.

## Installation

```bash
cpanm --installdeps .
```

## Quick Start

### 1. Create a Database Class

```perl
package MyApp::DB;
use Moo;
extends 'Durance::DB';

has dsn => ( is => 'lazy', default => sub { 'dbi:SQLite:dbname=myapp.db' } );

1;
```

### 2. Create Model Classes

```perl
package MyApp::Model::User;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'users';

column id       => ( is => 'rw', isa => 'Int', primary_key => 1 );
column name     => ( is => 'rw', isa => 'Str', required => 1 );
column email    => ( is => 'rw', isa => 'Str', unique => 1 );

has_many posts => ( is => 'rw', isa => 'MyApp::Model::Post' );

1;
```

### 3. Use in Your Application

```perl
use MyApp::Model::User;

# Create
my $user = MyApp::Model::User->create({ name => 'John', email => 'j@example.com' });

# Read
my $user = MyApp::Model::User->find(1);

# Query
my @users = MyApp::Model::User->where({ active => 1 })->order('name')->limit(10)->all;

# Update
$user->name('Jane')->update;

# Delete
$user->delete;
```

## Features

- CRUD operations
- Relationships (has_many, belongs_to, has_one)
- SQL JOIN support
- Eager loading (preload)
- Schema migration
- Validations
- SQL logging
- Embedded POD in every Perl module

## Supported Databases

- **SQLite3** - Tested and supported
- **MariaDB** - In theory (not yet tested)

## Testing

```bash
prove -l t/
```

## Author

AI project managed by Joe Johnston <jjohn@taskboy.com>.  Opencode was used to generate most of the files in this repo.  Some hand-editing was done, as if by an animal, by Y.T.

## License

Perl Artistic License
