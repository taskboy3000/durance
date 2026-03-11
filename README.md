# ORM - ActiveRecord-Style ORM for Perl

A lightweight ActiveRecord-style ORM for Perl using DBI and Mojo::Base.

## Installation

Install dependencies:

```bash
cpanm --installdeps .
```

Or manually:

```bash
cpan DBI DBD::SQLite Mojo::Base Carp
```

## Quick Start

### 1. Create a Database Class

Create a class that inherits from `ORM::DB` and defines your connection:

```perl
# lib/MyApp/DB.pm
package MyApp::DB;
use ORM::DB -base;

has dsn             => 'dbi:SQLite:dbname=myapp.db';
has driver_options  => sub { { RaiseError => 1, AutoCommit => 1 } };

1;
```

### 2. Create Model Classes

```perl
# lib/MyApp/Model/User.pm
package MyApp::Model::User;
use Mojo::Base 'ORM::Model', '-signatures';
use ORM::Model qw(column);

column id       => (is => 'rw', isa => 'Int', primary_key => 1);
column name     => (is => 'rw', isa => 'Str', required => 1);
column email    => (is => 'rw', isa => 'Str', unique => 1);
column age      => (is => 'rw', isa => 'Int');
column active   => (is => 'rw', isa => 'Int', default => 1);

sub table { 'users' }

1;
```

### 3. Use in Your Application

```perl
use MyApp::Model::User;

# Create
my $user = MyApp::Model::User->create({
    name  => 'John Doe',
    email => 'john@example.com',
    age   => 30,
});
say "Created user with ID: ", $user->id;

# Read
my $user = MyApp::Model::User->find(1);
say $user->name;

# Update
$user->name('Jane Doe')->update;

# Delete
$user->delete;

# Query
my @active_users = MyApp::Model::User->where({ active => 1 })->order('name')->limit(10)->all;
```

## How It Works

### Database Connection Discovery

Given a model class, the ORM automatically derives the DB class by replacing `Model` with `DB`:

| Model Class | DB Class |
|-------------|----------|
| `MyApp::Model::User` | `MyApp::DB` |
| `MyApp::Model::app::user` | `MyApp::DB` |
| `Analytics::Model::Report` | `Analytics::DB` |

The DB class is lazy-loaded when first needed.

### Override DB Class

To use a different DB class for a specific model:

```perl
package MyApp::Model::Legacy::User;
use ORM::Model;

db_class 'Legacy::DB';  # Explicitly use Legacy::DB

# ...
```

## Complete Mojo::Lite Example

Here's a minimal Mojo::Lite web application:

```perl
# app.pl
use Mojolicious::Lite;
use MyApp::DB;
use MyApp::Model::User;

# Ensure table exists
my $dbh = MyApp::DB->dbh;
$dbh->do(q{
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE,
        age INTEGER,
        active INTEGER DEFAULT 1
    )
});

get '/' => sub {
    my $c = shift;
    my @users = MyApp::Model::User->where({ active => 1 })->all;
    $c->render(json => [@users]);
};

get '/user/:id' => sub {
    my $c = shift;
    my $user = MyApp::Model::User->find($c->param('id'));
    $c->render(json => $user ? $user->to_hash : {});
};

post '/user' => sub {
    my $c = shift;
    my $user = MyApp::Model::User->create($c->req->json);
    $c->render(json => { id => $user->id });
};

put '/user/:id' => sub {
    my $c = shift;
    my $user = MyApp::Model::User->find($c->param('id'));
    $user->name($c->param('name'))->update if $user;
    $c->render(json => { success => !!$user });
};

del '/user/:id' => sub {
    my $c = shift;
    my $user = MyApp::Model::User->find($c->param('id'));
    $user->delete if $user;
    $c->render(json => { success => !!$user });
};

app->start;
```

Run with:

```bash
perl app.pl daemon
```

## Model Definition Reference

### column

```perl
column id => (
    is          => 'rw',       # read-write access
    isa         => 'Int',      # data type
    primary_key => 1,          # is primary    => 1,          # NOT NULL
    unique      => 1 key
    required,          # UNIQUE constraint
    default     => 1,          # default value
);
```

Supported types: `Int`, `Str`, `Text`, `Bool`, `Float`, `Timestamp`

### Relationships

```perl
# has_many
has_many accounts => (is => 'rw', isa => 'MyApp::Model::Account');

# belongs_to
belongs_to user => (
    is          => 'rw',
    isa         => 'MyApp::Model::User',
    foreign_key => 'user_id',
);
```

## API Reference

### Class Methods

- `create(\%data)` - Create and insert a new record
- `find($id)` - Find by primary key
- `where(\%conditions)` - Query with conditions
- `all()` - Get all records
- `columns()` - Get column names
- `column_meta($name)` - Get column metadata
- `table()` - Get table name

### Instance Methods

- `new(%attrs)` - Create instance (not persisted)
- `save()` - Insert or update
- `insert()` - Insert new record
- `update()` - Update existing record
- `delete()` - Delete record
- `to_hash()` - Get data as hashref

### ResultSet Methods

Chainable query methods:

- `where(\%conditions)` - Add conditions
- `order('column')` - Add ORDER BY
- `limit($n)` - Add LIMIT
- `offset($n)` - Add OFFSET
- `all()` - Execute and return results
- `first()` - Execute and return first result
- `count()` - Return matching records

## count of Directory Structure

Typical project structure:

```
myapp/
├── lib/
│   ├── MyApp/
│   │   ├── DB.pm           # Database configuration
│   │   └── Model/
│   │       └── User.pm     # Model classes
│   └── MyApp.pm            # Main application class
├── t/
│   └── model.t             # Tests
├── app.pl                  # Mojo::Lite app
└── cpanfile               # Dependencies
```

## Testing

Run tests:

```bash
prove -l t/
```

Or:

```bash
perl -Ilib t/orm.t
```

## License

Apache License 2.0
