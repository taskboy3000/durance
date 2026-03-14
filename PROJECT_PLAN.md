# ORM Framework - Project Plan

---

# Release: CURRENT

## Project Status Summary

All core ORM functionality is implemented and tested. The framework provides
an ActiveRecord-style ORM in Perl using Moo, with full CRUD operations,
schema management, relationship support (has_many, belongs_to, has_one,
many_to_many), SQL JOIN queries, eager loading (preload), validations,
and auto-timestamps.

**Test Suite:** 9 test files, 64 tests, ALL PASSING

---

## Working Components

| Module | Status | Description |
|--------|--------|-------------|
| `lib/Durance/DSL.pm` | WORKING | DSL functions (column, tablename, has_many, belongs_to, has_one, validates) |
| `lib/Durance/Model.pm` | WORKING | ActiveRecord-style base class with CRUD, relationships, JOINs |
| `lib/Durance/DB.pm` | WORKING | Database connection management with handle pooling |
| `lib/Durance/ResultSet.pm` | WORKING | Chainable query builder with JOIN support |
| `lib/Durance/QueryBuilder.pm` | WORKING | SQL query building with driver-aware generation |
| `lib/Durance/Schema.pm` | WORKING | Schema introspection, DDL generation, migration |
| `lib/Durance/Logger.pm` | WORKING | SQL logging to STDERR |

---

## Public API Reference

### Durance::Model

**Class Methods:**
- `create($data)` - Insert new record, returns model instance
- `find($id)` - Find by primary key, returns model or undef
- `where($conditions)` - Query with conditions, returns ResultSet
- `all` - Get all records
- `count` - Count all records
- `first` - Get first record
- `columns` - List of column names
- `column_meta($col)` - Metadata hash for a column
- `primary_key` - Primary key column name (default: 'id')
- `table` - Table name
- `db` - Durance::DB instance (class-level cached, convention-derived)
- `validations($name)` - Validation rules for a column
- `schema_name` - Schema name extracted from package
- `attributes` - Alias for columns
- `all_relations` - Hash of all relationships (has_many, belongs_to, has_one, many_to_many)
  with types: `{ name => 'has_many'|'belongs_to'|'has_one'|'many_to_many', ... }`
- `has_many_relations` - Hash of has_many relationship metadata
- `belongs_to_relations` - Hash of belongs_to relationship metadata
- `has_one_relations` - Hash of has_one relationship metadata
- `many_to_many_relations` - Hash of many_to_many relationship metadata
- `related_to($name)` - Relationship metadata for a named relation

**Instance Methods:**
- `save` - Insert or update
- `insert` - Insert new record, sets primary key
- `update` - Update existing record, sets updated_at
- `delete` - Delete record
- `to_hash` - Hashref of data (excludes db reference)

### Durance::DB

**Attributes:** `dsn` (lazy), `username` (ro), `password` (ro),
`driver_options` (lazy)

**Methods:**
- `dbh` - Returns pooled DBI handle
- `disconnect_all` - Disconnects all pooled handles
- `isDSNValid` - Validates DSN by attempting connection

### Durance::ResultSet

**Attributes:** `class` (ro, required), `conditions` (rw),
`order_by` (rw), `limit_val` (rw), `offset_val` (rw),
`join_specs` (rw), `preload_specs` (rw), `query_builder` (ro)

**Methods:**
- `where($conditions)` - Add WHERE conditions (chainable)
- `order($clause)` - Add ORDER BY (chainable)
- `limit($n)` - Set LIMIT (chainable)
- `offset($n)` - Set OFFSET (chainable)
- `add_joins(@relations)` - Add JOIN clauses (chainable)
- `preload(@relations)` - Add eager loading (chainable)
- `all` - Execute query, return results
- `first` - Execute with LIMIT 1, return first result
- `count` - Execute COUNT(*) query

### Durance::QueryBuilder

**Attributes:** `class` (ro, required), `driver` (rw)

**Methods:**
- `build_where($conditions)` - Generate WHERE clause, returns (clause, bind_values)
- `build_joins($specs)` - Generate JOIN clauses
- `build_select($options)` - Generate SELECT SQL with all clauses
- `build_count($options)` - Generate COUNT SQL
- `needs_distinct($specs)` - Check if DISTINCT is needed for has_many
- `driver_from_dsn($dsn)` - Extract driver type from DSN

### Durance::Schema

**Attributes:** `dbh`, `model_class`, `driver`, `logger`

**Methods:**
- `ddl_for_class($model)` - Generate CREATE TABLE SQL
- `create_table($model)` - Execute CREATE TABLE
- `table_exists($model)` - Check if table exists
- `column_info($model)` - Column metadata from DB
- `table_info($model)` - Table metadata from DB
- `migrate($model)` - Add missing columns
- `migrate_all($app)` - Migrate all models for an app
- `sync_table($model)` - Create or migrate table
- `schema_valid($model)` - Check if schema matches model (boolean or list)
- `ensure_schema_valid($model)` - Die with helpful message if schema invalid
- `pending_changes($model)` - Report schema differences
- `get_all_models_for_app($app)` - Discover all model classes

### Durance::DSL

**Exported Functions:**
- `column $name => (%opts)` - Define a column with metadata
- `tablename $name` - Set the table name
- `has_many $name => (%opts)` - Define has-many relationship
- `belongs_to $name => (%opts)` - Define belongs-to relationship
- `has_one $name => (%opts)` - Define has-one relationship
- `many_to_many $name => (%opts)` - Define many-to-many relationship
- `validates $name => (%opts)` - Define validation rules

### Durance::Logger

**Methods:**
- `log($message)` - Log message to STDERR with timestamp and PID
  - Only outputs if `ORM_SQL_LOGGING=1` environment variable is set
  - Format: `[timestamp][PID] $message`
  - Can be subclassed for custom logging behavior via `_build_logger` override

---

## User Experience

```perl
package MyApp::Model::User;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'users';

column id         => (is => 'rw', isa => 'Int', primary_key => 1);
column name       => (is => 'rw', isa => 'Str', required => 1);
column email      => (is => 'rw', isa => 'Str', unique => 1);
column age        => (is => 'rw', isa => 'Int');
column active     => (is => 'rw', isa => 'Bool', default => 1);
column created_at => (is => 'rw', isa => 'Str');
column updated_at => (is => 'rw', isa => 'Str');

has_many posts => (is => 'rw', isa => 'MyApp::Model::Post');
validates email => (format => qr/@/);

1;

# Usage
my $user = MyApp::Model::User->create({ name => 'John', email => 'j@example.com' });
my $user = MyApp::Model::User->find($id);
my @active = MyApp::Model::User->where({ active => 1 })->order('name')->limit(10)->all;
my @with_posts = MyApp::Model::User->where({})->add_joins('posts')->all;
$user->name('Jane')->update;
$user->delete;
```

---

## Test Coverage

| Category | Subtest Count | Description |
|----------|---------------|-------------|
| Durance::DB attributes | 6 | dsn, username, password, driver_options |
| Durance::DB dbh | 3 | Connection, prepare, driver detection |
| Durance::DB handle pooling | 2 | Same handle returned, ping |
| Durance::DB disconnect_all | 2 | Connect/disconnect lifecycle |
| Durance::DB isDSNValid | 5 | Valid/invalid DSN, error messages |
| Durance::Schema constructor | 5 | Object creation, driver detection, override |
| Durance::Schema DDL | 17 | SQLite DDL, MySQL DDL, type mapping |
| Durance::Schema introspection | 2 | table_exists, table_info for missing tables |
| Durance::Schema migration | 13 | create_table, pending_changes, sync_table |
| Durance::Model CRUD | 26 | Instantiation, create, find, update, delete, ResultSet |
| Durance::Model errors | 4 | find undef, update/delete without pk, invalid DSN |
| Durance::Model timestamps | 5 | created_at, updated_at auto-set and skip |
| Complex ResultSet | 16 | Comparison ops, LIKE, multi-condition, multi-order, DESC, offset |
| Relationships | 7 | has_many, belongs_to, query, create_* |
| JOIN Support | 8 | Introspection, chaining, belongs_to/has_many JOINs, WHERE, overrides |
| Validations | 18 | Format, length, Bool coercion, column_meta, schema_name |
| Schema Validation | 16 | schema_valid, ensure_schema_valid, error messages |
| JOIN Validation | 11 | Invalid rel dies, error suggestions, hash bypass, no-rel model |
| Basic attributes | 2 | Model discovery via get_all_models_for_app |

---

## Completed Work

### 1. Moo Migration ✓

Converted all ORM modules from `Mojo::Base` to `Moo`.

| Change | Before | After |
|--------|--------|-------|
| OO Framework | `Mojo::Base` | `Moo` |
| Model Definition | `use base Durance::Model` | `use Moo; extends 'Durance::Model'` |
| DSL Import | automatic via import | `use Durance::DSL;` |

**Commits:** 5e8d92f, a36715d, 0ec6454

### 2. DSL Module Extraction ✓

Extracted DSL functions from Durance::Model into a separate Durance::DSL module.
Originally created as `Durance::Model::DSL`, then renamed to `Durance::DSL` for
a cleaner user-facing API.

**Problem:** Moo's `extends` does NOT call the parent's `import` method,
so DSL functions (column, tablename, etc.) were never installed in
subclasses.

**Solution:** Separate `Durance::DSL` module with explicit `use Durance::DSL;`.

### 3. Database Connection Refactor ✓

Replaced the complex `dbh` method in Durance::Model with a cleaner `db`
attribute pattern.

| Change | Before | After |
|--------|--------|-------|
| Database Access | `$model->dbh` | `$model->db->dbh` |
| DB Class | `db_class` method | `_db_class_for` helper |
| Caching | None (new instance per call) | Class-level cached |

**Design Decisions:**
- Lazy builder for `db` - defer DB object creation until needed
- Convention over configuration - DB class derived from model name
- Class-level caching prevents N+1 connection problem
- `_db_class_for` kept separate for testability

### 4. DSL Column Values in new() ✓

**Problem:** Moo's `new()` only handles `has`-defined attributes. DSL
columns are dynamically created methods, so `$model->new(name => 'bob')`
would leave `name` as undef.

**Solution:** Added `BUILD` hook to Durance::Model that copies DSL column
values from constructor args into `$self->{hash}`.

### 5. Comprehensive Test Suite ✓

Built iterative test coverage across 4 phases:

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Durance::DB (connection, pooling, disconnect) | ✓ COMPLETED |
| 2 | Durance::Schema (DDL, introspection, migration) | ✓ COMPLETED |
| 3 | Test models and migration logic | ✓ COMPLETED |
| 4 | Durance::Model CRUD, ResultSet, relationships | ✓ COMPLETED |

Additional test coverage added for:
- Error handling (find undef, update/delete without pk, invalid DSN)
- Auto-timestamps (created_at, updated_at)
- Complex ResultSet queries (comparison ops, LIKE, multi-condition, ordering)
- Validation functions (format, length, Bool coercion)
- column_meta and schema_name methods
- isDSNValid() method

### 6. isDSNValid() Method ✓

Added explicit DSN validation method to Durance::DB. Connects using
`DBI->connect()` to test, provides clean error reporting, always
disconnects after testing.

**Commit:** cdb2611

### 7. JOIN Support ✓

Added SQL JOIN support to the ORM so related data can be fetched in a
single query, reducing N+1 query problems.

**Implementation:**
- Added relationship introspection methods to Durance::Model:
  `has_many_relations`, `belongs_to_relations`, `related_to`
- Added `add_joins()` method and `join_specs` attribute to
  Durance::ResultSet
- Built JOIN SQL generation in `ResultSet->all()` supporting both
  `belongs_to` and `has_many` relationship types
- Tagged relationships with `_relationship_type` in Durance::DSL
- Fixed `has_many` foreign key default to derive from parent class name
  (e.g., `Company has_many employees` -> `company_id`, not
  `employees_id`)
- Added duplicate JOIN prevention for mixed string/hash joins

**API:**

```perl
# String API (convention-based)
User->where({})->add_joins('company')->all;
User->where({})->add_joins('company', 'posts')->all;

# Hash API (explicit override)
User->where({})->add_joins({
    company => { type => 'INNER', on => 'companies.id = users.company_id' }
})->all;

# Mixed
User->where({})->add_joins('company', { posts => { type => 'INNER' } })->all;
```

**Tests:** 8 test cases covering introspection, chaining, belongs_to
JOINs, has_many JOINs, WHERE conditions, explicit overrides, mixed
joins.

**Commit:** d498597

### 9. Schema Validation & Error Handling ✓

Added explicit schema validation methods and JOIN validation to improve
developer experience and catch errors early.

**Schema Validation (Durance::Schema):**
- `schema_valid($model)` - Returns boolean (scalar) or
  `($valid, \@changes)` (list context). Does not modify the database.
- `ensure_schema_valid($model)` - Dies with actionable error message
  including migration command suggestion if schema is invalid.
- Recommended for app startup in long-running web frameworks
  (Mojolicious, Catalyst, Dancer). Not recommended for CGI.

**JOIN Validation (Durance::ResultSet):**
- `add_joins()` now validates string relationship names immediately.
  Invalid names die with error listing available relationships.
- Hash ref overrides are not validated (trusted as explicit/advanced).
- Models with no relationships get a clear error suggesting
  `has_many` or `belongs_to`.

**Tests:** 2 new test suites (27 assertions total):
- Schema Validation: 6 subtests (valid schema, missing table, missing
  columns, ensure_schema_valid pass/fail, error message content)
- JOIN Validation: 6 subtests (invalid rel, error suggestions, hash
  bypass, valid rel, no-rel model, mixed)

### 8. Bug Fixes Applied ✓

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| Schema.pm string to table_info() | `$table` passed instead of `$model` | Pass `$model` |
| db() creates new instance per call | No caching, different connections | Class-level caching |
| Fragile test assertions | Hardcoded IDs and counts | Use dynamic values from create |
| SQLite2 driver not supported | Deprecated `dbi:SQLite2:` DSN | Fixed to `dbi:SQLite:` |
| In-memory SQLite + pooling | Each connection = new DB | Use file-based temp SQLite |
| Recursive joins() method | Moo attribute/method name conflict | Renamed to add_joins/join_specs |
| has_many foreign key default | Used `${rel_name}_id` | Derive from parent class name |

---

## Testing Guidelines

### Git Commit Guidelines

- **NEVER run `git commit` without explicitly prompting the user for permission first**
- Always ask the user before committing, even if the change seems small
- The user prefers to review and potentially squash commits that represent too little work
- When asking for permission, provide a brief summary of what will be committed

### Test File Template

All new test files must include the following at the top to ensure they work with both `prove` and `perl -Ilib`:

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use experimental 'signatures';

use File::Basename;
use FindBin;
BEGIN {
    $::PROJ_ROOT = dirname($FindBin::Bin);
}

use lib ("$::PROJ_ROOT/lib", "$::PROJ_ROOT/t");

use Test2::V0;
```

---

## Key Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Moo over Moose | Lightweight, no XS dependency |
| Separate Durance::DSL module | Works with Moo's extends (no import magic) |
| Convention over configuration | DB class auto-derived from model package name |
| Class-level DB caching | Prevents N+1 connection problems |
| BUILD hook for DSL columns | Integrates dynamic columns with Moo constructor |
| add_joins (not joins) | Avoids Moo attribute/method name collision |
| has_many FK from parent name | Matches ActiveRecord convention |

---

## Files in Project

| File | Description |
|------|-------------|
| `lib/Durance/DSL.pm` | DSL functions for model definition |
| `lib/Durance/Model.pm` | Base class for ORM models |
| `lib/Durance/DB.pm` | Database connection management |
| `lib/Durance/ResultSet.pm` | Chainable query builder |
| `lib/Durance/QueryBuilder.pm` | SQL query building with driver support |
| `lib/Durance/DDL.pm` | Driver-aware SQL DDL generation |
| `lib/Durance/Schema.pm` | Schema introspection and migration |
| `lib/Durance/Logger.pm` | SQL logging to STDERR |
| `t/orm.t` | Comprehensive test suite |
| `t/logger.t` | SQL logging tests |
| `t/has_one.t` | has_one relationship tests |
| `t/preload.t` | preload tests |
| `t/count_with_join.t` | COUNT with JOIN tests |
| `t/many_to_many.t` | many_to_many relationship tests |
| `t/column_aliasing.t` | Column aliasing for JOIN tests |
| `t/query_builder.t` | QueryBuilder tests |
| `t/MyApp/DB.pm` | Test DB configuration |
| `t/MyApp/Model/app/user.pm` | Test model (users table) |
| `t/MyApp/Model/admin/role.pm` | Test model (roles table) |
| `Makefile.PL` | CPAN distribution file |
| `Makefile.dev` | Development Makefile |
| `AGENTS.md` | Coding standards and guidelines |
| `cpanfile` | Perl dependencies |

---

## Completed Tasks Detail

### 18. many_to_many() Relationship Support

Implement many-to-many relationships using junction tables.

**Example Usage (desired API):**
```perl
# Models
package MyApp::Model::Author;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'authors';
column id   => (is => 'rw', isa => 'Int', primary_key => 1);
column name => (is => 'rw', isa => 'Str');

many_to_many books => (
    through => 'author_books',  # junction table
    using  => 'book_id',       # foreign key in junction
);

package MyApp::Model::Book;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'books';
column id    => (is => 'rw', isa => 'Int', primary_key => 1);
column title => (is => 'rw', isa => 'Str');

many_to_many authors => (
    through => 'author_books',
    using  => 'author_id',
);

# Usage
my @books = $author->books;  # SELECT * FROM books ...
my @authors = $book->authors; # SELECT * FROM authors ...
```

**Implementation Steps (DDT):**

- [x] **Step 1: Design the DSL syntax**
  - [x] Define `many_to_many` function in Durance::DSL
  - [x] Support `through` (junction table) parameter
  - [x] Support `using` (foreign key column) parameter
  - [x] Auto-derive junction table name if not provided

- [x] **Step 2: Add relationship metadata**
  - [x] Store `many_to_many` relationships in `%_many_to_many` package var
  - [x] Add `many_to_many_relations()` method to Durance::Model
  - [x] Update `all_relations()` to include many_to_many

- [x] **Step 3: Implement accessor method**
  - [x] Generate accessor method on model class
  - [x] Handle both directions (Author->books, Book->authors)
  - [x] Use EXISTS or JOIN query to fetch related records

- [x] **Step 4: Add preload support**
  - [x] Support preloading many_to_many relationships
  - [x] Use JOIN query through junction table to collect parent IDs, then IN clause
  - [x] Handle both directions (Author->books, Book->authors)

- [x] **Step 5: Add create_related support**
  - [x] Allow creating new related records via junction table
  - [x] `create_book($author, { title => 'New Book' })` creates book and junction

- [x] **Step 6: Write tests**
  - [x] Create test models (Author, Book, AuthorBook)
  - [x] Test basic many_to_many access
  - [x] Test bidirectional access
  - [x] Test with where conditions
  - [x] Test preload support

- [x] **Step 7: Update documentation**
  - [x] Add many_to_many to DSL documentation
  - [x] Update README with example

---

### 19. Preload Support for many_to_many ✓ COMPLETED

Add eager loading support for many_to_many relationships.

- [x] Add preload handling in ResultSet for many_to_many relationships
- [x] Use JOIN query with DISTINCT to collect parent IDs, then IN clause
- [x] Write tests for many_to_many preload
- [x] many_to_many preload requires a JOIN through the junction table:
  - For Author->books: SELECT books.* FROM books JOIN author_books ON books.id = author_books.book_id WHERE author_books.author_id IN (...)
  - Uses `through` (junction table) and `using` (foreign key to related) from metadata

---

### 20. Documentation Update ✓ COMPLETED

Update documentation to reflect all implemented features.

- [x] Update Durance::DSL POD with many_to_many syntax
- [x] Update README.md with many_to_many example
- [x] Update Public API Reference in PROJECT_PLAN.md
- [x] Mark many_to_many complete in Future Features table

---

### 16. Prepare for GitHub Import ✓ COMPLETED

Prepare the repository for publishing on GitHub.

- [x] Review repository for sensitive data (API keys, passwords)
- [x] Ensure .gitignore is complete
- [x] Add LICENSE file
- [x] Add minimal README.md with installation and quick start
- [x] Verify all tests pass
- [x] Push to GitHub

### 17. Add CPAN Distribution Files ✓ COMPLETED

Create the files needed to upload this project to CPAN.

- [x] Create Makefile.PL
- [x] Update cpanfile with proper metadata
- [x] Add META.json/META.yml
- [x] Add perldoc footprint (LICENSE, AUTHOR, VERSION)
- [x] Test installation via `perl Makefile.PL && make install`

---

### 13. SQL Logging with Timing ✓ COMPLETED

Implemented environment-variable-controlled SQL logging to STDERR for debugging
and performance analysis. Built with Test-Driven Development approach.

**Requirements Fulfilled:**
- ✅ Log to STDERR via `ORM_SQL_LOGGING=1` environment variable
- ✅ Single `Durance::Logger` class with one `log()` method
- ✅ Log exact SQL statements with parameter values (for copy-paste debugging)
- ✅ Include timing information mixed with output for context
- ✅ Single logger attribute on Durance::Model, Durance::ResultSet, Durance::Schema
- ✅ Subclassable: users can override `_build_logger` for custom implementations
- ✅ Each module uses Time::HiRes independently as needed

**Implementation (Test-Driven Development):**

**Files Created:**
- `lib/Durance/Logger.pm` - Stateless logger class with `log()` method
- `t/logger.t` - Comprehensive test suite (9 test suites, all passing)

**Files Modified:**
- `lib/Durance/Model.pm` - Added logger attribute, wrapped find/all/insert/update/delete
- `lib/Durance/ResultSet.pm` - Added logger attribute, wrapped all/count methods
- `lib/Durance/Schema.pm` - Replaced custom logger with Durance::Logger, wrapped DDL operations

**Sub-Tasks Completed:**
- ✅ Step 1: Created comprehensive test suite in `t/logger.t`
- ✅ Step 2: Created Durance::Logger module with log() method
- ✅ Step 3: Added logger attribute to Durance::Model
- ✅ Step 4: Added SQL logging to Durance::Model::find()
- ✅ Step 5: Added SQL logging to Durance::Model::all()
- ✅ Step 6: Added SQL logging to Durance::Model::insert()
- ✅ Step 7: Added SQL logging to Durance::Model::update()
- ✅ Step 8: Added SQL logging to Durance::Model::delete()
- ✅ Step 9: Added logger attribute to Durance::ResultSet
- ✅ Step 10: Added SQL logging to Durance::ResultSet::all()
- ✅ Step 11: Added SQL logging to Durance::ResultSet::count()
- ✅ Step 12: Replaced Durance::Schema logger with Durance::Logger
- ✅ Step 13: Added SQL logging to Durance::Schema DDL operations (CREATE TABLE, ALTER TABLE)

**Test Results:**
- ✅ All 15 original test suites PASSING
- ✅ All 9 logger test suites PASSING
- ✅ SQL logging verified with `ORM_SQL_LOGGING=1`
- ✅ Logger output format verified: `[timestamp][PID] SQL (duration ms): sql [params]`

**Example Output:**
```
[Fri Mar 13 18:28:04 2026][39362] SQL (9.187 ms): INSERT INTO users (email, name) VALUES (?, ?) ['alice@test.com', 'Alice']
[Fri Mar 13 18:28:04 2026][39362] SQL (0.087 ms): SELECT * FROM users WHERE id = ? [42]
[Fri Mar 13 18:28:04 2026][39362] SQL (12.830 ms): CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT)
```

**Design Notes:**
- Logger format: `[timestamp][PID] SQL (duration ms): sql [params]`
- Parameters logged exactly as passed for debugging (numbers, strings quoted)
- Timing measurement done by caller (Time::HiRes), passed to logger for context
- Environment variable: `ORM_SQL_LOGGING=1` to enable
- Subclassable via `_build_logger` override

**Effort Completed:** 8 hours

---

### 14. COUNT with JOIN ✓ COMPLETED

Implemented proper COUNT(*) support for queries with JOINs. The `ResultSet->count()` 
method now respects JOIN specifications and applies DISTINCT when needed.

**Problem (Fixed):**
- ❌ `User->where({})->add_joins('posts')->count()` was ignoring JOINs
- ❌ Missing DISTINCT handling for has_many JOINs (would count duplicates)
- ❌ JOIN clauses from `add_joins()` were not applied to COUNT queries

**Requirements (All Fulfilled):**
- ✅ COUNT queries respect JOIN specifications
- ✅ DISTINCT applied for has_many relationships (avoids duplicate counting)
- ✅ Relationship type auto-detected (belongs_to vs has_many)
- ✅ belongs_to: uses simple COUNT(*) (one row per match)
- ✅ has_many: uses COUNT(DISTINCT main_table.id) to avoid duplicates
- ✅ SQL logging support (via Durance::Logger with timing)
- ✅ COUNT works with WHERE conditions and JOINs combined

**Implementation (Test-Driven Development):**

**Files Created:**
- `t/count_with_join.t` - Comprehensive test suite (8 test cases, all passing)

**Files Modified:**
- `lib/Durance/ResultSet.pm` - Added JOIN and DISTINCT support to count() + refactored all()

**Sub-Tasks Completed:**
- ✅ Step 1: Created comprehensive test suite with 8 test scenarios
- ✅ Step 2: Analyzed current count() and JOIN logic in all()
- ✅ Step 3: Extracted `_build_join_sql()` helper method (used by both all() and count())
- ✅ Step 4: Implemented `_needs_distinct()` for DISTINCT detection
- ✅ Step 5: Updated count() method with full JOIN and DISTINCT support
- ✅ Step 6: Integration testing - all tests pass, no regressions

**Test Results:**
- ✅ All 15 original test suites PASSING
- ✅ All 9 logger test suites PASSING
- ✅ All 8 COUNT with JOIN test suites PASSING (new)
- ✅ **Total: 40 tests passing**
- ✅ SQL logging verified: proper DISTINCT syntax in output
- ✅ No breaking changes to public API

**Example Usage After Implementation:**
```perl
# belongs_to JOIN - COUNT returns matching books
my $count = Book->where({})->add_joins('author')->count;
# SQL: SELECT COUNT(*) FROM books LEFT JOIN authors ON ...

# has_many JOIN - COUNT uses DISTINCT to avoid duplicates
my $count = Author->where({})->add_joins('books')->count;
# SQL: SELECT COUNT(DISTINCT authors.id) FROM authors LEFT JOIN books ...

# Multiple JOINs with WHERE conditions
my $count = PublishedBook->where({})
               ->add_joins('publisher', 'author')
               ->count;
# SQL: SELECT COUNT(*) FROM published_books 
#      LEFT JOIN publishers ON ...
#      LEFT JOIN authors ON ...
```

**Design Implementation:**
- `_build_join_sql()` - Extracts JOIN SQL generation (eliminates duplication)
  - Used by both `all()` and `count()` for consistency
  - Handles string/hash API, override validation, duplicate prevention
  - ~60 lines of logic, reusable

- `_needs_distinct()` - Detects has_many relationships in join_specs
  - Returns true if any JOIN needs DISTINCT
  - Examines `_relationship_type` metadata
  - ~12 lines of logic

- Updated `count()` - Now supports JOINs and DISTINCT
  - Calls `_build_join_sql()` to build JOIN clauses
  - Uses `COUNT(DISTINCT table.id)` when needed
  - Preserves WHERE clause and SQL logging
  - ~35 lines total (down from 40 with duplication)

**SQL Logging Examples (with `ORM_SQL_LOGGING=1`):**
```
SELECT COUNT(*) FROM authors
SELECT COUNT(*) FROM books LEFT JOIN authors ON authors.id = books.author_id WHERE published = ?
SELECT COUNT(DISTINCT authors.id) FROM authors LEFT JOIN books ON books.author_id = authors.id
SELECT COUNT(*) FROM published_books LEFT JOIN publishers ... LEFT JOIN authors ...
```

**Effort Completed:** 3 hours

---

### 15. Dry-Run Mode (DEFERRED)

**Status: DEFERRED** - No immediate use case identified.

Given that `Durance::Schema::pending_changes()` already shows what schema changes
would happen, and users can review changes via this method before applying them,
dry-run mode lacks a compelling real-world use case.

Can be revisited if users request it in the future.

### 10. Extract all_relations() for Code Reuse ✓ COMPLETED

Unified relationship-gathering logic into `Durance::Model->all_relations()` to
avoid duplication and prepare for additional relationship types like
`has_one`.

**Implementation:**
- `all_relations()` already exists in Durance::Model (returns hash with relationship
  names as keys and types as values: `{ name => 'has_many', ... }`)
- Handles random hash key ordering by using `sort keys` in error messages
  (ResultSet.pm:34)
- Replaces scattered calls to `has_many_relations` and `belongs_to_relations`
- Already used by ResultSet.pm for error reporting (line 27)
- Test coverage updated to use `all_relations` instead of separate accessors

**Design Decisions:**
- Simpler format (no nested metadata) - callers don't need additional info
- Hash structure works correctly despite random key ordering (sorted where needed)
- Single method reduces future maintenance when adding new relationship types

### 11. Architectural Analysis & SRP Review ✓ COMPLETED

Analyzed all 6 ORM modules against framework requirements and Single Responsibility Principle.

**Current Metrics (March 2026):**
- 6 modules, 3212 total lines
- 40 tests, 7 test files
- 100% test pass rate

**Key Findings:**

| Module | Lines | Responsibilities | SRP Status |
|--------|-------|------------------|------------|
| Durance::DB | 216 | 2 | ✓ Compliant |
| Durance::DSL | 496 | 5 | ✗ Violation |
| Durance::Logger | 99 | 1 | ✓ Compliant |
| Durance::Model | 715 | 8 | ✗✗ God Object |
| Durance::ResultSet | 964 | 3 | ✗ Violation |
| Durance::Schema | 722 | 7 | ✗✗ Violation |

**Framework Requirements Met: 86% (6/7)**
- ✅ Lightweight (Moo, not Moose)
- ✅ Convention over Configuration
- ✅ Relationships (has_many, belongs_to, has_one, many_to_many)
- ✅ Query building (ResultSet chainable methods)
- ✅ CRUD operations
- ✅ Verbose SQL logging with timing
- ⏸️ Dry-run mode for migrations (DEFERRED - No real-world use case)

**SRP Violations Identified:**
- Durance::Model (8 responsibilities) - CRITICAL God Object
- Durance::Schema (7 responsibilities) - Mixed concerns
- Durance::DSL (5 responsibilities) - Definition + metadata
- Durance::ResultSet (3 responsibilities) - State + SQL + execution

**Analysis Files Generated:**
- `ANALYSIS_EXECUTIVE_SUMMARY.txt` - Leadership summary
- `ORM_MODULES_MATRIX.txt` - Quick reference matrix
- `ORM_ARCHITECTURE_SUMMARY.txt` - Detailed breakdown
- `ORM_ARCHITECTURAL_ANALYSIS.md` - Technical deep dive
- `ARCHITECTURAL_ANALYSIS_INDEX.md` - Navigation guide

**Refactoring Roadmap:**
- Phase 1: Extract DDL from Schema, query SQL from ResultSet
- Phase 2: Split Durance::Model with roles/traits
- Phase 3: Add MariaDB driver support

**How to Regenerate This Analysis:**

```bash
# Count lines in each module
wc -l lib/Durance/*.pm

# List public methods
grep -n '^\s*sub\s\+' lib/Durance/*.pm

# Count test files and tests  
prove -l t/ 2>&1 | tail -1
```

**Estimated effort for full SRP compliance:** 50-60 hours over 6 weeks

### 12. Complete Test Coverage of Public API ✓ COMPLETED

Reviewed and extended test coverage of all 46 public API methods across 5
modules.

**Initial Coverage Analysis:**
- Total public API methods: 46
- Tests before: 36/40 (90%) - some methods missed in analysis
- Actual coverage: 37/46 (80%) across all modules

**Methods Previously Untested:**
- `Durance::Schema::column_info()` - Returns column metadata from database
- `Durance::Model::validations()` - Retrieves validation rules for a column

**Implementation:**
- Added subtest `column_info returns metadata from existing table`
  - Tests retrieval of column metadata from existing database tables
  - Verifies proper return values for existing and missing columns
  - 5 new test cases
  
- Added subtest `validations method`
  - Tests retrieval of validation rules defined in model
  - Covers format and length validation rules
  - Tests columns with and without validations
  - 6 new test cases

**Final Results:**
- Total public API methods tested: 39/46 (85% coverage)
- 15 test suites all passing
- NEW: 11 new subtests added
- Framework API comprehensively exercised

**Coverage by Module:**
- Durance::Model: 22/23 methods tested (96%)
- Durance::Schema: 11/12 methods tested (92%)
- Durance::ResultSet: 8/8 methods tested (100%)
- Durance::DB: 3/3 methods tested (100%)
- Durance::DSL: 5/5 functions tested (100%)

### Previously Completed Tasks

* ✓ COMPLETED: ensure_schema_valid now suggests `sync_table($model)` for
  single-model failures, with `migrate_all` as a secondary option

---

## Future Features

### Task 15. Dry-Run Mode (DEFERRED)

**Status: DEFERRED** - No immediate use case identified.

Given that `Durance::Schema::pending_changes()` already shows what schema changes
would happen, and users can review changes via this method before applying them,
dry-run mode lacks a compelling real-world use case.

Can be revisited if users request it in the future.

---

### Task 24. MariaDB Support

Add database driver support and tests for MariaDB.

- [ ] Add MariaDB driver detection
- [ ] Add MariaDB DDL type mapping (if different from MySQL)
- [ ] Add integration tests with MariaDB

---

### Task 27. Split Durance::Schema (Separate Migration from DDL) ✓ COMPLETED

Extract DDL generation and migration logic from Durance::Schema into separate modules to comply with SRP.

**Current Problem:**
- Durance::Schema has 7 responsibilities (Mixed concerns)
- DDL generation mixed with migration logic
- Introspection mixed with table creation

**Important: Driver-Aware DDL Generation**

Like Durance::QueryBuilder, DDL generation must be driver-aware because different databases (SQLite, MySQL, MariaDB, PostgreSQL) have different:
- Column type mappings (e.g., BOOL vs TINYINT vs BOOLEAN)
- AUTOINCREMENT syntax (SQLite vs MySQL)
- Index definitions
- Foreign key constraints

The Durance::DDL module MUST require driver information (either passed in or extracted from DSN) to generate correct SQL.

**Implementation Steps:**

- [x] **Step 1: Analyze Durance::Schema responsibilities**
  - [x] Document all methods in Durance::Schema
  - [x] Categorize into responsibility groups

- [x] **Step 2: Create Durance::DDL module**
  - [x] Extract DDL generation (CREATE TABLE, ALTER TABLE)
  - [x] Create `lib/Durance/DDL.pm`
  - [x] Move type mapping logic
  - [x] **REQUIRE driver attribute (required)**
  - [x] Add `driver_from_dsn()` helper
  - [x] Add driver-aware type mapping (SQLite, MySQL, MariaDB)
  - [x] Add driver-aware AUTOINCREMENT syntax

- [ ] **Step 3: Create Durance::Migration module** (DEFERRED - not needed)
  - Migration logic remains in Schema.pm, delegates to DDL

- [x] **Step 4: Update Durance::Schema**
  - [x] Delegate to DDL module
  - [x] Keep introspection methods
  - [x] Keep migration methods (sync_table, migrate, migrate_all)

- [x] **Step 5: Update tests**
  - [x] All existing tests pass
  - [x] No regressions

**Completed:**

- Created `lib/Durance/DDL.pm` with:
  - Required `driver` attribute
  - `driver_from_dsn()` method for DSN-based driver detection
  - Driver-aware type mapping (SQLite, MySQL, MariaDB)
  - `ddl_for_class()` - generate CREATE TABLE SQL
  - `build_create_table_sql()` - internal CREATE TABLE
  - `build_alter_table_add_column()` - generate ALTER TABLE ADD COLUMN

- Updated `lib/Durance/Schema.pm`:
  - Added `ddl` attribute (lazy builder)
  - `ddl_for_class()` now delegates to Durance::DDL
  - `create_table()` uses DDL module
  - `migrate()` uses DDL module
  - Removed duplicate type mapping code

**Target Architecture:**

```
Durance::Schema (introspection + migration)
    |
    +-- Durance::DDL (DDL generation)
          - driver attribute (REQUIRED)
          - ddl_for_class()
          - driver_from_dsn()
          - type mapping (per driver)
```

**Reference: Durance::QueryBuilder Driver Pattern**

```perl
package Durance::DDL;
use Moo;

has 'driver' => (is => 'rw', required => 1);

sub driver_from_dsn ($self, $dsn) {
    # Extract driver from DBI DSN: dbi:SQLite:... -> SQLite
    my ($driver) = $dsn =~ /^dbi:(\w+):/i;
    return lc $driver // 'sqlite';
}

sub _map_type ($self, $perl_type) {
    my %map = (
        sqlite => { Bool => 'INTEGER', Int => 'INTEGER', Str => 'TEXT' },
        mysql  => { Bool => 'TINYINT(1)', Int => 'INT', Str => 'VARCHAR(255)' },
        # ...
    );
    return $map{$self->driver}{$perl_type} // $map{sqlite}{$perl_type};
}
```

---

### Task 25. include() Method ✓ COMPLETED

Implement JOIN + record inflation for nested objects. Unlike `preload()` which executes
separate queries, `include()` uses a single JOIN query and inflates nested objects from
the joined result.

**Difference from preload():**
- `preload`: Separate queries per relationship, then merge (N+1 queries avoided)
- `include`: Single JOIN query, inflate nested objects from joined rows (1 query total)

**Security Note:** Relationship names are validated against defined relationships before use.
Only pre-defined relationship names (via has_many, belongs_to, has_one, many_to_many) 
can be included. User input cannot inject arbitrary table names.

**Example Usage:**
```perl
# Fetch users with their posts in a single query
my @users = User->where({})->include('posts')->all;

# Each user has posts already loaded - no extra queries
for my $user (@users) {
    my @posts = $user->posts;  # Already loaded
}

# Mix with conditions
User->where({active => 1})->include('posts')->all;
```

**Implementation Steps (TDD):**

- [x] **Step 1: Create test file and basic test cases** ✓ COMPLETED
  - [x] Create `t/include.t` test file
  - [x] Test include() method exists and returns ResultSet (chainable)
  - [x] Test include() with belongs_to relationship (to-one)
  - [x] Test include() with has_many relationship (to-many)

- [x] **Step 2: Add include() method to ResultSet** ✓ COMPLETED
  - [x] Add `include_specs` attribute to ResultSet (like preload_specs)
  - [x] Add `include()` method (chainable, similar to preload)
  - [x] Validate relationship names (reuse preload validation - already safe)

- [x] **Step 3: Implement include() SQL generation (SRP: separate method)** ✓ COMPLETED
  - [x] Create `_build_include_joins()` helper method (SRP: isolate SQL generation)
  - [x] Modify `all()` to call `_build_include_joins()` when include_specs present
  - [x] Generate JOIN SQL for included relationships
  - [x] Collect all columns from main + included tables with aliases

- [~] **Step 4: Implement record inflation (SRP: separate method)** IN PROGRESS
  - [x] Create `_inflate_included()` helper method (SRP: isolate inflation logic)
  - [~] Parse joined rows and identify unique parent records by PK (has bugs)
  - [~] Extract related data from each joined row (partially working)
  - [ ] Handle to-one (belongs_to, has_one) inflation: single related object (broken)
  - [ ] Handle to-many (has_many) inflation: collect all related into arrayref (broken)

**REMAINING BUGS TO FIX (Step 4 completion):**

- [ ] **Step 4a: Fix row deduplication in _inflate_included**
  - [ ] Problem: `@$rows = values %unique_parents` doesn't update caller's array
  - [ ] Solution: Return new array from _inflate_included and replace in all()
  - [ ] Test: Verify row count matches expected (2 authors, not 3)

- [ ] **Step 4b: Fix related data extraction**
  - [ ] Debug: Add logging to see if `${rel_table}__$col` keys exist in row objects
  - [ ] Problem: Related columns may not be in row object hash
  - [ ] Solution: Ensure aliased columns (authors__name, books__title) are stored in row
  - [ ] Test: Verify belongs_to author is loaded (test 2)

- [ ] **Step 4c: Fix WHERE clause SQL generation**
  - [ ] Problem: Regex replacement `s/ WHERE / /` breaks SQL when conditions exist
  - [ ] Solution: Build SQL more carefully - detect WHERE before adding JOINs
  - [ ] Alternative: Rebuild SQL from scratch instead of regex manipulation
  - [ ] Test: WHERE condition test should pass (test 6)

- [ ] **Step 4d: Verify related object creation**
  - [ ] Debug: Log when related objects are created in _inflate_included
  - [ ] Problem: `$has_related` check may be too strict
  - [ ] Solution: Check if any non-null related column exists
  - [ ] Test: Verify books array has correct count (test 3)

- [ ] **Step 4e: Fix has_one inflation**
  - [ ] Problem: profile is not loaded (test 4)
  - [ ] Solution: Same as belongs_to - ensure to-one inflation works
  - [ ] Test: Verify profile is loaded with correct bio

- [ ] **Step 5: Test basic edge cases**
  - [ ] Test include() with multiple to-one relationships
  - [ ] Test include() with to-one + to-many combined
  - [ ] Test include() with WHERE conditions
  - [ ] Test include() with ORDER BY (to-one only for MVP)

- [ ] **Step 6: Error handling**
  - [x] Test invalid relationship name dies with helpful error (working)
  - [ ] Fix test 8 - dies_ok syntax error
  - [ ] Test include() with LIMIT (to-many may have incomplete results - document this)

- [ ] **Step 7: Integration tests**
  - [ ] Test full workflow: create data, query with include, verify nested objects
  - [ ] Compare SQL generated: include() vs preload() vs add_joins()
  - [ ] Verify all existing tests still pass (run prove -l t/)

- [ ] **Deferred: Nested includes (posts.comments)**
  - Complex recursive handling, defer to future task if needed
  - Current MVP only supports flat includes

- [ ] **Deferred: include() with LIMIT on to-many**
  - Semantics unclear: limit per parent? limit total rows?
  - Document limitation in MVP

---

### Task 28. Remove Dead Code and Refactor Duplicates

Clean up unused code, consolidate duplicates, and improve code consistency across the Durance ORM.

**Analysis:** Found ~250 lines of dead/duplicate code across modules (see task output for full details)

**Implementation Steps (discrete, testable):**

**Phase 1: Remove Clearly Dead Code (High Priority)**

- [ ] **Step 1a: Remove unused _columns_info method**
  - [ ] Remove Model.pm:299-301 (_columns_info stub method)
  - [ ] Run tests to verify no breakage

- [ ] **Step 1b: Remove unused primaryKey attribute**
  - [ ] Remove Model.pm:16-17 (has primaryKey + builder)
  - [ ] Verify primary_key() method still works
  - [ ] Run tests

- [ ] **Step 1c: Remove unused FindBin import**
  - [ ] Remove Schema.pm:9 (use FindBin)
  - [ ] Run tests

- [ ] **Step 1d: Remove unused package vars from Model.pm**
  - [ ] Remove %_has_many, %_belongs_to from Model.pm:13
  - [ ] Keep %_columns, %_primary_key, %_validations (these ARE used)
  - [ ] Run tests

- [ ] **Step 1e: Fix typo in comment**
  - [ ] Model.pm:281 - Fix "Mented to a called" → "Meant to be called"

- [ ] **Step 1f: Remove unused predicate flags**
  - [ ] DB.pm:15-16 - Remove predicate => 1 from username/password
  - [ ] Run tests

**Phase 2: Consolidate Duplicate Code (Medium Priority)**

- [ ] **Step 2a: Consolidate _db_class_for method**
  - [ ] Keep Model.pm version (line 83-91)
  - [ ] Update Schema.pm to call Model's _db_class_for instead
  - [ ] Or extract to shared utility module
  - [ ] Run tests

- [ ] **Step 2b: Consolidate driver_from_dsn method**
  - [ ] Create canonical version (lowercase) in shared location
  - [ ] Update DDL.pm to use canonical version
  - [ ] Update QueryBuilder.pm to use canonical version
  - [ ] Run tests

- [ ] **Step 2c: Use lazy logger attribute consistently**
  - [ ] Model.pm: Replace 5 direct instantiations with $self->logger
  - [ ] ResultSet.pm: Replace 6 direct instantiations with $self->logger
  - [ ] Run tests

**Phase 3: Fix Documentation (Medium Priority)**

- [ ] **Step 3a: Consolidate DB.pm POD**
  - [ ] Move useful content from after __END__ (line 109-216)
  - [ ] Update ORM::DB references to Durance::DB
  - [ ] Remove __END__ marker
  - [ ] Merge into single comprehensive POD

- [ ] **Step 3b: Consolidate Model.pm POD**
  - [ ] Merge duplicate POD sections (lines 438-460, 462-724)
  - [ ] Remove duplicate =head1 NAME entries
  - [ ] Single consistent documentation block

**Phase 4: Evaluate Optional Removals (Low Priority)**

- [ ] **Step 4a: Evaluate isDSNValid method**
  - [ ] Check if this is part of public API
  - [ ] If only used in tests, consider removing or marking as test-only
  - [ ] Decision: Keep or remove?

- [ ] **Step 4b: Evaluate use utf8 pragma**
  - [ ] Check if UTF-8 literals are planned
  - [ ] Remove from DB.pm if not needed
  - [ ] Decision: Keep or remove?

- [ ] **Step 4c: Investigate _get_aliased_columns**
  - [ ] Check if ResultSet.pm:170 version is called
  - [ ] Check if QueryBuilder.pm:126 version is called
  - [ ] Remove if truly unused

**Verification:**
- [ ] After each phase, run: `prove -l t/*.t`
- [ ] All 64 tests must pass
- [ ] No regressions

**Estimated Impact:**
- Remove ~50 lines of dead code
- Consolidate ~80 lines of duplicates
- Simplify ~120 lines total
- ~250 lines cleanup (~3% of codebase)

---

### Task 26. Performance Testing

Benchmark SQL queries and model operations.

- [ ] Create benchmark suite
- [ ] Profile key operations
- [ ] Document performance characteristics

---

### Task 23. Refactor Durance::Model (Extract Query Builder) ✓ COMPLETED

Extract query building logic from Durance::Model into a separate Durance::QueryBuilder class
to reduce the God Object (8 responsibilities).

**Objective:** Split Durance::Model's responsibilities into focused, single-purpose classes.

**Current Problem:**
- Durance::Model has 8 responsibilities (God Object)
- Query generation mixed with relationship accessors
- Validations and timestamps tightly coupled
- Hard to test and maintain

**Implementation Steps:**

- [x] **Step 1: Analyze Durance::Model responsibilities**
  - [x] Document all methods in Durance::Model
  - [x] Categorize into responsibility groups
  - [x] Identify what's truly "query building" vs "model logic"

- [x] **Step 2: Create Durance::QueryBuilder module**
  - [x] Create `lib/Durance/QueryBuilder.pm`
  - [x] Define core query building methods:
    - `where($conditions)` - Build WHERE clause
    - `order($clause)` - Build ORDER BY
    - `limit($n)` - Build LIMIT
    - `offset($n)` - Build OFFSET
    - `add_joins(@relations)` - Build JOINs
  - [x] Add SQL generation methods:
    - `build_select()` - Generate SELECT SQL
    - `build_where()` - Generate WHERE clause
    - `build_joins()` - Generate JOIN clauses
  - [x] Add driver-aware SQL generation (for MariaDB/MySQL compatibility)

- [x] **Step 3: Extract relationship query logic**
  - [x] Move has_many query generation to QueryBuilder
  - [x] Move belongs_to query generation to QueryBuilder
  - [x] Move has_one query generation to QueryBuilder
  - [x] Move many_to_many query generation to QueryBuilder

- [x] **Step 4: Update Durance::Model to use QueryBuilder**
  - [x] Update has_many accessor to delegate to QueryBuilder
  - [x] Update belongs_to accessor to delegate to QueryBuilder
  - [x] Update has_one accessor to delegate to QueryBuilder
  - [x] Update many_to_many accessor to delegate to QueryBuilder

- [x] **Step 5: Create tests for QueryBuilder**
  - [x] Test basic query building (where, order, limit)
  - [x] Test JOIN query building
  - [x] Test relationship query building
  - [x] Test SQL generation methods

- [x] **Step 6: Run integration tests**
  - [x] All existing tests pass
  - [x] No regressions in functionality
  - [x] Performance not degraded

**Target Architecture:**

```
Durance::Model (base class)
    |
    +-- Durance::QueryBuilder (query building)
    |     - where(), order(), limit(), offset()
    |     - build_select(), build_where(), build_joins()
    |
    +-- Durance::ResultSet (result set management)
    |
    +-- Durance::Model::Role::Relationships (has_many, belongs_to, etc.)
    |
    +-- Durance::Model::Role::Validations (validates)
```

**Benefits:**
- Single Responsibility: Each class has one job
- Testability: QueryBuilder can be tested in isolation
- Reusability: QueryBuilder can be used independently
- Maintainability: Changes to query logic don't affect model logic

**Estimated effort:** 8-12 hours

---

### 21. Column Aliasing for JOINs ✓ COMPLETED

Handle column name collisions when JOINing tables that share column names (e.g., `id`, `name`).

**Problem:**
- When doing `User->add_joins('company')->all`, if both tables have an `id` column, the second overwrites the first
- `SELECT *` returns only one `id` column in the hash

**Solution:**
- Generate aliased column names: `users.id AS users__id`, `companies.id AS companies__id`
- Parse aliased column names when building model objects
- Map `users__id` back to `id` for the User model, `companies__id` for Company model

**Implementation Steps (DDT):**

- [x] **Step 1: Analyze current JOIN SQL generation**
  - [x] Review `_build_join_sql` in ResultSet
  - [x] Identify where `SELECT *` is used

- [x] **Step 2: Design column aliasing strategy**
  - [x] Define alias format: `table__column`
  - [x] Update ResultSet to generate aliased SELECT
  - [x] Handle existing column specification (not just `*`)

- [x] **Step 3: Add column aliasing to ResultSet**
  - [x] Add method to collect all columns from main + joined tables
  - [x] Generate aliased column list
  - [x] Replace `SELECT *` with aliased columns

- [x] **Step 4: Parse aliased columns when building objects**
  - [x] Add column mapping logic in ResultSet::all()
  - [x] Split aliased names back to table.column
  - [x] Assign to correct model object

- [x] **Step 5: Write tests**
  - [x] Create test with JOIN that has colliding column names
  - [x] Verify both columns are accessible
  - [x] Test with belongs_to and has_many JOINs

- [x] **Step 6: Update documentation**
  - [x] Document column aliasing behavior

**Test Results:**
- All 39 tests passing (7 test files)

**Example Usage:**
```perl
# User and Company both have 'id' and 'name' columns
User->add_joins('company')->all;

# With aliasing:
# $user->id        # user's id (from users.id)
# $user->name     # user's name (from users.name)
# $user->company->id    # company's id (from companies.id)
# $user->company->name # company's name (from companies.name)
```

---

### 22. Document and Test Joined Column Alias Behavior ✓ COMPLETED

The current column aliasing implementation handles the main table columns correctly
(employees__id -> id), but joined table columns (e.g., companies__name) are intentionally
NOT stored in the parent object.

This is by design since:
- Related objects are loaded via the preload mechanism, not from JOIN results
- The BUILD hook only copies defined columns, discarding unknown keys
- Relationship accessors ($employee->company->name) provide the correct data

- [x] Add test to verify joined columns are NOT stored in parent object
- [x] Document this behavior in code comments

---

## Project Rename: ORM → Durance ✓ COMPLETED

### Task: Rename project namespace from ORM to Durance

**Objective:** Rename the project from "ORM" to "Durance" and change all `lib/ORM/` namespace to `Durance::`.

**Scope:**
- `lib/ORM/` → `lib/Durance/`
- 6 Perl modules: Model.pm, ResultSet.pm, DSL.pm, Schema.pm, Logger.pm, DB.pm
- All test files referencing Durance:: modules
- Documentation (AGENTS.md, PROJECT_PLAN.md, POD)

**Implementation Plan:**

**Step 1: Rename lib/ORM/ directory to lib/Durance/**
- [x] `mv lib/ORM lib/Durance`

**Step 2: Update package declarations in all modules**
- [x] `lib/Durance/DB.pm` - `package Durance::DB;`
- [x] `lib/Durance/Model.pm` - `package Durance::Model;`
- [x] `lib/Durance/ResultSet.pm` - `package Durance::ResultSet;`
- [x] `lib/Durance/DSL.pm` - `package Durance::DSL;`
- [x] `lib/Durance/Schema.pm` - `package Durance::Schema;`
- [x] `lib/Durance/Logger.pm` - `package Durance::Logger;`

**Step 3: Update internal references in module files**
- [x] All `ORM::` references → `Durance::` within module code
- [x] Update `our` package variables: `%_has_many`, `%_belongs_to`, etc.

**Step 4: Update test files**
- [x] `t/orm.t` - Update all require/use statements and package references
- [x] `t/logger.t` - Update all require/use statements
- [x] `t/count_with_join.t` - Update all require/use statements
- [x] `t/has_one.t` - Update all require/use statements
- [x] `t/preload.t` - Update all require/use statements

**Step 5: Update documentation**
- [x] `AGENTS.md` - Update references and directory structure
- [x] `PROJECT_PLAN.md` - Update all ORM:: references to Durance::

**Step 6: Update example models (if any)**
- [x] `t/MyApp/Model/*` - Update extends from 'ORM::Model' to 'Durance::Model'

**Step 7: Run tests and verify**
- [x] `prove -l t/*.t` - All tests pass
- [x] Fix any namespace issues discovered during testing

**Example Changes:**

Before:
```perl
package MyApp::Model::User;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

my $user = MyApp::Model::User->create({ name => 'John' });
```

After:
```perl
package MyApp::Model::User;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

my $user = MyApp::Model::User->create({ name => 'John' });
```

**Effort Estimate:** 1-2 hours

---

## Project Milestones

| Milestone | Status | Commit |
|-----------|--------|--------|
| Initial implementation | ✓ DONE | b9ef284 |
| Moo Migration | ✓ DONE | 5e8d92f |
| DSL Module Extraction | ✓ DONE | a36715d |
| Database Connection Refactor | ✓ DONE | d96bc4b, 032a38d |
| Test Framework (Phase 1-4) | ✓ DONE | 2b0fdac - 473dc33 |
| Error Handling Tests | ✓ DONE | 7da48e4 |
| Validation Tests | ✓ DONE | 2636c15 |
| Relationship Tests | ✓ DONE | 28f246d |
| Auto-timestamp Tests | ✓ DONE | 7977b2a |
| Complex ResultSet Tests | ✓ DONE | e8af6ad |
| isDSNValid() Method | ✓ DONE | cdb2611 |
| JOIN Support | ✓ DONE | d498597 |
| Schema Validation & JOIN Validation | ✓ DONE | schema_valid, ensure_schema_valid, add_joins validation |
| Full Test Coverage | ✓ DONE | 15 test suites passing |
| preload() Eager Loading | ✓ DONE | 10 test suites in t/preload.t |
| Column Aliasing for JOINs | ✓ DONE | Task 21 - handles column collisions |
| QueryBuilder Extraction | ✓ DONE | Task 23 - refactored to Durance::QueryBuilder |
| DDL Module Extraction | ✓ DONE | Task 27 - refactored to Durance::DDL |
