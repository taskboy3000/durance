# Intention: ActiveRecord-Style ORM for Perl

## Problem

The current `lib/ORM/` provides basic CRUD functionality but lacks the convenience
and elegance of Ruby's ActiveRecord.

## Goal

Enhance the Perl ORM to work like Ruby's ActiveRecord, providing:

- Intuitive model definitions with declarative syntax
- Chainable query methods (where, order, limit, etc.)
- Association support (has_many, belongs_to)
- Migrations system
- Callbacks (Validations before/after create, update, delete)
- Multi-RDBMS support (SQLite, MySQL, PostgreSQL, Oracle)

## Current State

- `lib/ORM/Model.pm` — Metaprogramming for column definitions, dbh management
- `lib/ORM/Schema.pm` — Schema management (single database at a time)
- `lib/ORM/DB.pm` — Database connection manager base class
- `t/MyApp/Model/` — Example models

## Design

### Database Configuration

The ORM uses a simple has-a relationship for database connections. Models do not
inherit from a DB class; instead, they look up the corresponding DB class when
needed.

**Convention:** Given a model class, derive the DB class by replacing `Model` with `DB`:

    MyApp::Model::User      → MyApp::DB
    MyApp::Model::app::user → MyApp::DB
    Analytics::Model::Report → Analytics::DB

#### Creating a DB Class

Users create an application-specific DB class that inherits from `ORM::DB`:

```perl
package MyApp::DB;
use ORM::DB -base;

has dsn             => 'dbi:SQLite:dbname=myapp.db';
has driver_options  => sub { { RaiseError => 1, AutoCommit => 1 } };

1;
```

The DB class provides:
- `dsn` - DBI data source name
- `username` - Database username (default: '')
- `password` - Database password (default: '')
- `driver_options` - Hashref of DBI connect options
- `dbh()` - Returns connected DBI handle (with process-level pooling)

#### Using Models

Once the DB class is defined, models can automatically obtain connections:

```perl
package MyApp::Model::User;
use ORM::Model;

column id   => (is => 'rw', isa => 'Int', primary_key => 1);
column name => (is => 'rw', isa => 'Str');

sub table { 'users' }

1;

# Usage - dbh is derived automatically from MyApp::DB
my $user = MyApp::Model::User->create({ name => 'John' });
my @users = MyApp::Model::User->all;
```

#### Explicit DB Class Override

If you need to use a different DB class for a specific model:

```perl
package MyApp::Model::Legacy::User;
use ORM::Model;

db_class 'Legacy::DB';  # Explicitly use Legacy::DB instead of MyApp::DB

column id   => (is => 'rw', isa => 'Int', primary_key => 1);
column name => (is => 'rw', isa => 'Str');

sub table { 'users' }

1;
```

### Schema Management

ORM::Schema manages database tables based on model definitions. It can create
tables and sync schema to match model definitions.

**Automatic dbh Derivation:**

```perl
use ORM::Schema;
use MyApp::Model::User;

# Schema derives dbh from MyApp::DB automatically
my $schema = ORM::Schema->new(model_class => 'MyApp::Model::User');
$schema->sync_table('MyApp::Model::User');

# Or pass dbh directly
my $schema = ORM::Schema->new(dbh => $dbh);
$schema->sync_table('MyApp::Model::User');
```

**Methods:**

```perl
# Create table for a model
$schema->create_table_for_class('MyApp::Model::User');

# Sync table (create if not exists, migrate if needed)
$schema->sync_table('MyApp::Model::User');

# Check for pending changes
my @pending = @{$schema->pending_changes('MyApp::Model::User')};

# Table operations (require dbh to be set)
$schema->table_exists('users');
$schema->table_info('users');
```

### Model Definitions

```perl
package MyApp::Model::User;
use ORM::Model;

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column name       => (is => 'rw', isa => 'Str', required => 1);
column email      => (is => 'rw', isa => 'Str', unique => 1);
column created_at => (is => 'rw', isa => 'Str');
column updated_at => (is => 'rw', isa => 'Str');

has_many accounts => (is => 'rw', isa => 'MyApp::Model::Account');

validates email => (is => 'rw', isa => 'Str', format => qr/@/);

sub table { 'users' }

1;
```

```perl
package MyApp::Model::Account;
use ORM::Model;

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column user_id    => (is => 'rw', isa => 'Int', required => 1);
column domain     => (is => 'rw', isa => 'Str', required => 1);
column created_at => (is => 'rw', isa => 'Str');
column updated_at => (is => 'rw', isa => 'Str');

belongs_to user => (
    is => 'rw', 
    isa => 'MyApp::Model::User',        
    foreign_key => 'user_id'
);

sub table { 'accounts' }

1;
```

### Usage Examples

```perl
# Create
my $user = MyApp::Model::User->create({ name => 'John', email => 'john@example.com' });

# Read
my $user = MyApp::Model::User->find(1);
my @users = MyApp::Model::User->where({ active => 1 });
my @users = MyApp::Model::User->all;

# Update
$user->name('Jane');
$user->save;

# Delete
$user->delete;

# Associations
my $account = MyApp::Model::Account->create(
    user_id => $user->id,
    domain  => 'example.com',
);

# Access related objects
my $owner = $account->user;           # belongs_to: get the User
my @accounts = $user->accounts;        # has_many: get all Accounts

# Convenience: create_association methods
my $new_account = $user->create_account(domain => 'https://facebook.com');
```

### Validation Strategy

**Immediate validation on set** — The ORM automatically generates setter methods
based on validation rules defined in the model:

```perl
# User writes only this:
column email => (is => 'rw', isa => 'Str', required => 1, length => 255);
validates email => (format => qr/@/);

# ORM automatically generates setter with validation:
# - format validation (via validates)
# - length enforcement (via column length option)
# - Bool coercion (truthy values become 1, falsy become 0)
```

**Length enforcement:** When a column has a `length` option, the ORM validates
that assigned values do not exceed the specified length. This applies regardless
of database type, so SQLite users get the same protection as MySQL users.

**Bool coercion:** Columns with `isa => 'Bool'` automatically coerce values
using Perl truthiness: truthy values become 1, falsy values become 0.

### Supported Column Types

| ORM Type  | SQLite  | MySQL        | Setter Behavior |
|-----------|---------|--------------|-----------------|
| Int       | INTEGER | INTEGER      | No coercion     |
| Str       | TEXT    | VARCHAR(n)   | Length enforced  |
| Text      | TEXT    | TEXT         | No length limit  |
| Bool      | INTEGER | TINYINT(1)   | Coerced to 0/1  |
| Float     | REAL    | DOUBLE       | No coercion     |
| Timestamp | TEXT    | TIMESTAMP    | No coercion     |

For Str columns on MySQL, the length defaults to 255. Set `length => n` to
override.

### Multi-RDBMS Support

The ORM supports SQLite and MySQL/MariaDB. The database driver is detected
automatically from the DBI handle. DDL generation adapts to the target
database.

**Inspecting generated DDL:**

```perl
my $schema = ORM::Schema->new(driver => 'mysql');
my $sql = $schema->ddl_for_class('MyApp::Model::User');
# Returns: CREATE TABLE users (id INTEGER PRIMARY KEY AUTO_INCREMENT, ...)

my $sqlite_sql = $schema->ddl_for_class('MyApp::Model::User', 'sqlite');
# Returns: CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, ...)
```

**Optional SQL::Translator support:** If SQL::Translator is installed, the
`pending_changes` method will also report type mismatches between model
definitions and the database. Without it, only missing columns are detected.

### Database Naming Conventions

- Table names: plural nouns (e.g., `users`, `accounts`)
- Column names: lowercase with underscores (e.g., `user_id`, `created_at`)
- Package names: include schema/database name as namespace

### Required Columns

| Column      | Type          | Description                                      |
|-------------|---------------|--------------------------------------------------|
| `id`        | INTEGER       | Primary key, auto-incremented by the database   |
| `created_at`| TIMESTAMP     | Set by the ORM when the record is first persisted|
| `updated_at`| TIMESTAMP     | Updated by the ORM whenever the record is modified|

### Foreign Keys

- Foreign key constraints are optional in the database schema
- Any column ending with `_id` is treated as a potential foreign key
- The ORM infers associations from column naming:
  - `user_id` in `accounts` implies `belongs_to :user`
  - Inverse table automatically gets `has_many :accounts`

### Auto-Sync Strategy

The ORM uses a declarative migration approach (similar to Rails "schema.rb"):

1. Each model class defines the desired schema state
2. The ORM compares against actual DB state
3. Generates and executes DDL to reconcile differences
4. No separate migration files — schema is derived from Perl classes

**Advantages:**
- No need to write sequential migration files
- Schema is source-of-truth in model classes
- Automatic detection of needed changes

**Trade-offs:**
- Less control over exact DDL execution order
- May not handle all complex schema changes (renames, data migrations)

### Sync Behavior

| Change Type | ORM Action |
|-------------|------------|
| New column | ALTER TABLE ADD COLUMN |
| Column type mismatch | Warn (may require manual migration) |
| New default value | ALTER TABLE ALTER COLUMN (if supported) |
| New NOT NULL | Warn (requires data migration first) |
| Removed column | Warn (data loss — requires manual migration) |
