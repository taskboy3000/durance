# Durance

A lightweight ActiveRecord-style ORM for Perl using Moo and DBI.

## Installation

### From CPAN

2026-03-14: NOT YET AVAILABLE ON CPAN

```bash
cpan Durance
```

### From Source

```bash
perl Makefile.PL
make
make install
```

### Development Dependencies

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
- Relationships (has_many, belongs_to, has_one, many_to_many)
- SQL JOIN support
- Eager loading (preload)
- Schema migration
- Validations
- SQL logging
- Embedded POD in every Perl module

## Relationships

### has_many

```perl
has_many posts => ( is => 'rw', isa => 'MyApp::Model::Post' );
```

### belongs_to

```perl
belongs_to user => ( is => 'rw', isa => 'MyApp::Model::User' );
```

### has_one

```perl
has_one profile => ( is => 'rw', isa => 'MyApp::Model::Profile' );
```

### many_to_many

```perl
# Define on both sides of the relationship
package MyApp::Model::Author;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'authors';
column id   => ( is => 'rw', isa => 'Int', primary_key => 1 );
column name => ( is => 'rw', isa => 'Str' );

many_to_many books => (
    through => 'author_books',
    using   => 'book_id',
    isa     => 'MyApp::Model::Book',
);

# Usage
my @books = $author->books;
```

## Supported Databases

- **SQLite3** - Tested and supported
- **MariaDB** - In theory (not yet tested)

## Using Durance with Mojolicious

Durance integrates seamlessly with Mojolicious applications through convention-based setup
and automatic schema management.

### Directory Structure

```
lib/
  MyApp/
    DB.pm              # Database connection class
    Model/
      User.pm          # Your model classes
      Post.pm
  MyApp.pm             # Mojolicious application
```

### 1. Create Database Connection Class

```perl
# lib/MyApp/DB.pm
package MyApp::DB;
use Moo;
extends 'Durance::DB';

sub _build_dsn {
    my $self = shift;
    my $config = $ENV{MOJO_CONFIG} || 'myapp.conf';
    
    # In production, read from config file or environment
    return $ENV{DATABASE_URL} || 'dbi:SQLite:dbname=myapp.db';
}

sub _build_username { $ENV{DB_USER} || '' }
sub _build_password { $ENV{DB_PASS} || '' }

1;
```

### 2. Create Model Classes

```perl
# lib/MyApp/Model/User.pm
package MyApp::Model::User;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'users';

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column name       => (is => 'rw', isa => 'Str', required => 1);
column email      => (is => 'rw', isa => 'Str');
column created_at => (is => 'rw', isa => 'Str');
column updated_at => (is => 'rw', isa => 'Str');

has_many posts => (is => 'rw', isa => 'MyApp::Model::Post');
validates email => (format => qr/@/);

1;
```

```perl
# lib/MyApp/Model/Post.pm
package MyApp::Model::Post;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'posts';

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column user_id    => (is => 'rw', isa => 'Int');
column title      => (is => 'rw', isa => 'Str', required => 1);
column body       => (is => 'rw', isa => 'Str');
column created_at => (is => 'rw', isa => 'Str');

belongs_to user => (is => 'rw', isa => 'MyApp::Model::User', foreign_key => 'user_id');

1;
```

### 3. Mojolicious Application Setup

#### Development Mode (Auto-Migration)

Automatically migrate schema changes on startup. Ideal for development.

```perl
# lib/MyApp.pm
package MyApp;
use Mojo::Base 'Mojolicious', -signatures;

sub startup ($self) {
    my $config = $self->plugin('Config');
    
    # Auto-migrate all models in development
    if ($self->mode eq 'development') {
        require Durance::Schema;
        require MyApp::DB;
        
        my $db = MyApp::DB->new;
        my $schema = Durance::Schema->new(dbh => $db->dbh);
        
        # Migrate all models automatically
        $schema->migrate_all($db);
        
        $self->log->info("Database schema synchronized");
    }
    
    # Routes
    my $r = $self->routes;
    $r->get('/')->to('main#index');
    $r->get('/users')->to('users#list');
    $r->get('/users/:id')->to('users#show');
    $r->post('/users')->to('users#create');
}

1;
```

#### Production Mode (Validation Only)

Validate schema on startup but don't auto-migrate. Dies if schema is invalid.

```perl
sub startup ($self) {
    my $config = $self->plugin('Config');
    
    # In production, validate schema but don't auto-migrate
    if ($self->mode eq 'production') {
        require Durance::Schema;
        require MyApp::DB;
        require MyApp::Model::User;
        require MyApp::Model::Post;
        
        my $db = MyApp::DB->new;
        my $schema = Durance::Schema->new(dbh => $db->dbh);
        
        # Dies with helpful error if schema is invalid
        $schema->ensure_schema_valid(MyApp::Model::User->new);
        $schema->ensure_schema_valid(MyApp::Model::Post->new);
        
        $self->log->info("Database schema validated");
    }
    
    # Routes...
}
```

### 4. Using Models in Controllers

Use models directly in your controller actions:

```perl
# lib/MyApp/Controller/Users.pm
package MyApp::Controller::Users;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use MyApp::Model::User;

sub list ($self) {
    # Get all users
    my @users = MyApp::Model::User->where({})->order('name')->all;
    $self->render(json => [map { $_->to_hash } @users]);
}

sub show ($self) {
    my $id = $self->param('id');
    my $user = MyApp::Model::User->find($id);
    
    return $self->reply->not_found unless $user;
    
    # Eager load posts to avoid N+1 queries
    my @users = MyApp::Model::User->where({id => $id})->include('posts')->all;
    $self->render(json => $users[0]->to_hash);
}

sub create ($self) {
    my $data = $self->req->json;
    
    # Validation errors are caught by Durance
    my $user = eval { MyApp::Model::User->create($data) };
    
    if ($@) {
        return $self->render(json => {error => "$@"}, status => 400);
    }
    
    $self->render(json => $user->to_hash, status => 201);
}

1;
```

### 5. Configuration File

```perl
# myapp.conf
{
    database => {
        dsn      => 'dbi:SQLite:dbname=myapp.db',
        username => '',
        password => ''
    }
}
```

For production with MySQL:

```perl
# myapp.production.conf
{
    database => {
        dsn      => 'dbi:mysql:database=myapp_prod;host=db.example.com',
        username => 'dbuser',
        password => 'secret'
    }
}
```

Update your DB class to use configuration:

```perl
# lib/MyApp/DB.pm
package MyApp::DB;
use Moo;
extends 'Durance::DB';
use Mojo::File qw(path);
use Mojo::JSON qw(decode_json);

sub _build_dsn {
    # Read from environment or config file
    return $ENV{DATABASE_URL} if $ENV{DATABASE_URL};
    
    my $mode = $ENV{MOJO_MODE} || 'development';
    my $config_file = "myapp.$mode.conf";
    
    if (-e $config_file) {
        my $config = decode_json(path($config_file)->slurp);
        return $config->{database}{dsn};
    }
    
    return 'dbi:SQLite:dbname=myapp.db';  # fallback
}

1;
```

### 6. SQL Logging in Development

Enable SQL query logging for debugging:

```bash
# Development
ORM_SQL_LOGGING=1 morbo script/myapp

# See queries in console:
# [Sat Mar 14 14:30:15 2026][12345] SQL (1.234 ms): SELECT * FROM users WHERE id = ? [42]
```

### 7. Best Practices

**Connection Pooling**
- Durance::DB automatically pools connections at the class level
- Each model class gets one shared connection
- Safe for pre-forking servers (Hypnotoad)

**Schema Migration**
- Development: Use `migrate_all()` for automatic schema sync
- Production: Use `ensure_schema_valid()` to catch schema drift
- Manual migrations: Use `sync_table()` for individual models

**Eager Loading**
- Use `preload()` for separate queries (avoids N+1)
- Use `include()` for single JOIN query (better performance)

```perl
# N+1 problem (bad)
my @users = MyApp::Model::User->all;
for my $user (@users) {
    my @posts = $user->posts;  # Separate query per user!
}

# Preload (good) - 2 queries total
my @users = MyApp::Model::User->where({})->preload('posts')->all;

# Include (best) - 1 query total
my @users = MyApp::Model::User->where({})->include('posts')->all;
```

**Error Handling**
```perl
sub create ($self) {
    my $data = $self->req->json;
    
    my $user = eval { MyApp::Model::User->create($data) };
    if ($@) {
        $self->log->error("Failed to create user: $@");
        return $self->render(json => {error => 'Invalid data'}, status => 400);
    }
    
    $self->render(json => $user->to_hash, status => 201);
}
```

**Transactions**
```perl
sub transfer ($self) {
    my $dbh = MyApp::Model::User->db->dbh;
    
    eval {
        $dbh->begin_work;
        
        # Multiple operations
        my $from = MyApp::Model::Account->find($from_id);
        my $to = MyApp::Model::Account->find($to_id);
        
        $from->balance($from->balance - $amount)->update;
        $to->balance($to->balance + $amount)->update;
        
        $dbh->commit;
    };
    
    if ($@) {
        $dbh->rollback;
        return $self->render(json => {error => 'Transfer failed'}, status => 500);
    }
    
    $self->render(json => {success => 1});
}
```

## Testing

```bash
prove -l t/
```

## Author

AI project managed by Joe Johnston <jjohn@taskboy.com>.  Opencode was used to generate most of the files in this repo.  Some hand-editing was done, as if by an animal, by Y.T.

## License

Perl Artistic License
