# ORM Framework - Project Plan

---

# Release: CURRENT

## Project Status Summary

All core ORM functionality is implemented and tested. The framework provides
an ActiveRecord-style ORM in Perl using Moo, with full CRUD operations,
schema management, relationship support (has_many, belongs_to, has_one,
many_to_many), SQL JOIN queries, eager loading (preload), validations,
and auto-timestamps.

**Test Suite:** 7 test files, 40 tests, ALL PASSING

---

## Working Components

| Module | Status | Description |
|--------|--------|-------------|
| `lib/Durance/DSL.pm` | WORKING | DSL functions (column, tablename, has_many, belongs_to, has_one, validates) |
| `lib/Durance/Model.pm` | WORKING | ActiveRecord-style base class with CRUD, relationships, JOINs |
| `lib/Durance/DB.pm` | WORKING | Database connection management with handle pooling |
| `lib/Durance/ResultSet.pm` | WORKING | Chainable query builder with JOIN support |
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
`join_specs` (rw), `preload_specs` (rw)

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
| `lib/Durance/Schema.pm` | Schema introspection and migration |
| `lib/Durance/Logger.pm` | SQL logging to STDERR |
| `t/orm.t` | Comprehensive test suite |
| `t/logger.t` | SQL logging tests |
| `t/has_one.t` | has_one relationship tests |
| `t/preload.t` | preload tests |
| `t/count_with_join.t` | COUNT with JOIN tests |
| `t/many_to_many.t` | many_to_many relationship tests |
| `t/column_aliasing.t` | Column aliasing for JOIN tests |
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

### Task 25. include() Method

Implement JOIN + record inflation for nested objects.

- [ ] Design include() API
- [ ] Implement include() in ResultSet
- [ ] Write tests for include()

---

### Task 26. Performance Testing

Benchmark SQL queries and model operations.

- [ ] Create benchmark suite
- [ ] Profile key operations
- [ ] Document performance characteristics

---

### Task 23. Refactor Durance::Model (Extract Query Builder)

Extract query building logic from Durance::Model into a separate Durance::QueryBuilder class
to reduce the God Object (8 responsibilities).

**Objective:** Split Durance::Model's responsibilities into focused, single-purpose classes.

**Current Problem:**
- Durance::Model has 8 responsibilities (God Object)
- Query generation mixed with relationship accessors
- Validations and timestamps tightly coupled
- Hard to test and maintain

**Implementation Steps:**

- [ ] **Step 1: Analyze Durance::Model responsibilities**
  - [ ] Document all methods in Durance::Model
  - [ ] Categorize into responsibility groups
  - [ ] Identify what's truly "query building" vs "model logic"

- [ ] **Step 2: Create Durance::QueryBuilder module**
  - [ ] Create `lib/Durance/QueryBuilder.pm`
  - [ ] Define core query building methods:
    - `where($conditions)` - Build WHERE clause
    - `order($clause)` - Build ORDER BY
    - `limit($n)` - Build LIMIT
    - `offset($n)` - Build OFFSET
    - `add_joins(@relations)` - Build JOINs
  - [ ] Add SQL generation methods:
    - `build_select()` - Generate SELECT SQL
    - `build_where()` - Generate WHERE clause
    - `build_joins()` - Generate JOIN clauses
  - [ ] Add driver-aware SQL generation (for MariaDB/MySQL compatibility)

- [ ] **Step 3: Extract relationship query logic**
  - [ ] Move has_many query generation to QueryBuilder
  - [ ] Move belongs_to query generation to QueryBuilder
  - [ ] Move has_one query generation to QueryBuilder
  - [ ] Move many_to_many query generation to QueryBuilder

- [ ] **Step 4: Update Durance::Model to use QueryBuilder**
  - [ ] Update has_many accessor to delegate to QueryBuilder
  - [ ] Update belongs_to accessor to delegate to QueryBuilder
  - [ ] Update has_one accessor to delegate to QueryBuilder
  - [ ] Update many_to_many accessor to delegate to QueryBuilder

- [ ] **Step 5: Create tests for QueryBuilder**
  - [ ] Test basic query building (where, order, limit)
  - [ ] Test JOIN query building
  - [ ] Test relationship query building
  - [ ] Test SQL generation methods

- [ ] **Step 6: Run integration tests**
  - [ ] All existing tests pass
  - [ ] No regressions in functionality
  - [ ] Performance not degraded

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
