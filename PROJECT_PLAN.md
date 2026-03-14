# ORM Framework - Project Plan

---

# Release: CURRENT

## Project Status Summary

All core ORM functionality is implemented and tested. The framework provides
an ActiveRecord-style ORM in Perl using Moo, with full CRUD operations,
schema management, relationship support, SQL JOIN queries, validations,
and auto-timestamps.

**Test Suite:** 15 test suites, ALL PASSING

```
ok 1 - Durance::DB - attributes and methods
ok 2 - Durance::Schema - constructor and attributes
ok 3 - Durance::Schema - DDL generation
ok 4 - Durance::Schema - table introspection
ok 5 - Durance::Schema - table creation and migration
ok 6 - Durance::Model - CRUD operations
ok 7 - Durance::Model - Error handling
ok 8 - Durance::Model - Auto-timestamps
ok 9 - Durance::Model - Complex ResultSet Queries
ok 10 - Durance::Model - Relationship functions
ok 11 - Durance::Model - JOIN Support
ok 12 - Durance::Model - Validation functions
ok 13 - Durance::Schema - Schema Validation
ok 14 - Durance::ResultSet - JOIN Validation
ok 15 - Durance::Model - Basic attributes
1..15
```

---

## Working Components

| Module | Status | Description |
|--------|--------|-------------|
| `lib/ORM/DSL.pm` | WORKING | DSL functions (column, tablename, has_many, belongs_to, validates) |
| `lib/ORM/Model.pm` | WORKING | ActiveRecord-style base class with CRUD, relationships, JOINs |
| `lib/ORM/DB.pm` | WORKING | Database connection management with handle pooling |
| `lib/ORM/ResultSet.pm` | WORKING | Chainable query builder with JOIN support |
| `lib/ORM/Schema.pm` | WORKING | Schema introspection, DDL generation, migration |

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
- `all_relations` - Hash of all relationships (both has_many and belongs_to)
  with types: `{ name => 'has_many'|'belongs_to', ... }`
- `has_many_relations` - Hash of has_many relationship metadata
- `belongs_to_relations` - Hash of belongs_to relationship metadata
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
`join_specs` (rw)

**Methods:**
- `where($conditions)` - Add WHERE conditions (chainable)
- `order($clause)` - Add ORDER BY (chainable)
- `limit($n)` - Set LIMIT (chainable)
- `offset($n)` - Set OFFSET (chainable)
- `add_joins(@relations)` - Add JOIN clauses (chainable)
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
| `lib/ORM/DSL.pm` | DSL functions for model definition |
| `lib/ORM/Model.pm` | Base class for ORM models |
| `lib/ORM/DB.pm` | Database connection management |
| `lib/ORM/ResultSet.pm` | Chainable query builder |
| `lib/ORM/Schema.pm` | Schema introspection and migration |
| `lib/ORM/Logger.pm` | SQL logging to STDERR (to be created) |
| `t/orm.t` | Comprehensive test suite (15 test suites) |
| `t/logger.t` | SQL logging tests (to be created) |
| `t/MyApp/DB.pm` | Test DB configuration |
| `t/MyApp/Model/app/user.pm` | Test model (users table) |
| `t/MyApp/Model/admin/role.pm` | Test model (roles table) |
| `AGENTS.md` | Coding standards and guidelines |
| `cpanfile` | Perl dependencies |

---

## Pending Tasks

### 16. Prepare for GitHub Import

Prepare the repository for publishing on GitHub.

- [ ] Review repository for sensitive data (API keys, passwords)
- [ ] Ensure .gitignore is complete
- [ ] Add LICENSE file (Apache 2.0)
- [ ] Add minimal README.md with installation and quick start
- [ ] Verify all tests pass
- [ ] Tag release version

### 17. Add CPAN Distribution Files

Create the files needed to upload this project to CPAN.

- [ ] Create Build.PL or Makefile.PL
- [ ] Update cpanfile with proper metadata
- [ ] Add META.json/META.yml
- [ ] Add perldoc footprint (LICENSE, AUTHOR, VERSION)
- [ ] Test installation via `cpan .`
- [ ] Register on PAUSE and request namespace (Durance::*)

**Detailed Implementation Plan:**

**Step 1: Add VERSION and proper POD to each module**
- Add `$VERSION = '0.01';` to each Durance::* module
- Add standard POD header: `=head1 NAME`, `=head1 VERSION`, `=head1 DESCRIPTION`, `=head1 AUTHOR`, `=head1 LICENSE`
- Example:
  ```perl
  our $VERSION = '0.01';
  
  1;
  =pod
  
  =head1 NAME
  
  Durance::Model - ActiveRecord-style ORM base class
  
  =head1 VERSION
  
  Version 0.01
  
  =head1 AUTHOR
  
  Joe Johnston <jjohn@taskboy.com>
  
  =head1 LICENSE
  
  Perl Artistic License
  
  =cut
  ```

**Step 2: Create Makefile.PL**
- Use ExtUtils::MakeMaker or Module::Build
- Define PREREQ_PM (runtime dependencies)
- Define TEST_REQUIRES (test dependencies)
- Set VERSION_FROM to extract version from lib/Durance/Model.pm
- Set LICENSE to 'perl'
- Example:
  ```perl
  use ExtUtils::MakeMaker;
  
  WriteMakefile(
      NAME              => 'Durance',
      VERSION_FROM      => 'lib/Durance/Model.pm',
      AUTHOR            => 'Joe Johnston <jjohn@taskboy.com>',
      ABSTRACT          => 'Lightweight ActiveRecord-style ORM',
      LICENSE           => 'perl',
      PREREQ_PM         => {
          'Moo'          => 0,
          'DBI'          => 0,
          'DBD::SQLite'  => 0,
      },
      TEST_REQUIRES     => {
          'Test2::Suite' => 0,
      },
      META_MERGE        => {
          'meta-spec' => 2,
          resources    => {
              repository => {
                  type => 'git',
                  url  => 'https://github.com/taskboy3000/durance.git',
              },
          },
      },
  );
  ```

**Step 3: Update cpanfile**
- Remove App::cpanminus (not needed for distribution)
- Add File::Spec (core, no need to specify)
- Keep only runtime and test deps

**Step 4: Create META.json (optional)**
- Will be generated by Makefile.PL
- Can manually add for immediate use

**Step 5: Test installation**
- Run `perl Makefile.PL`
- Run `make install`
- Or test via `cpan .`

**Step 6: Register PAUSE namespace**
- Go to https://pause.perl.org/
- Create account if needed
- Request upload permission for Durance::*
- Upload distribution via PAUSE

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
- `lib/ORM/Logger.pm` - Stateless logger class with `log()` method
- `t/logger.t` - Comprehensive test suite (9 test suites, all passing)

**Files Modified:**
- `lib/ORM/Model.pm` - Added logger attribute, wrapped find/all/insert/update/delete
- `lib/ORM/ResultSet.pm` - Added logger attribute, wrapped all/count methods
- `lib/ORM/Schema.pm` - Replaced custom logger with Durance::Logger, wrapped DDL operations

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
- `lib/ORM/ResultSet.pm` - Added JOIN and DISTINCT support to count() + refactored all()

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
- ✅ **Total: 32 tests passing**
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

### 10. Extract all_relations() for Code Reuse ✓ IN PROGRESS

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

Performed comprehensive analysis of all 5 ORM modules against framework
requirements and Single Responsibility Principle.

**Key Findings:**

| Module | Responsibilities | SRP Status |
|--------|------------------|------------|
| Durance::DB | 2 | ✓ Compliant |
| Durance::DSL | 5 | ✗ Violation |
| Durance::Model | 8 | ✗✗ God Object |
| Durance::ResultSet | 3 | ✗ Violation |
| Durance::Schema | 7 | ✗✗ Violation |

**Framework Requirements Met: 67% (6/9)**
- ✅ Lightweight
- ✅ Convention over Configuration
- ✅ Relationships (has_many, belongs_to, JOINs)
- ✅ Query building (ResultSet chainable methods)
- ✅ CRUD operations
- ✅ **Verbose SQL logging with timing** (COMPLETED - Task 13)
- ⏸️ **Dry-run mode for migrations** (DEFERRED - No real-world use case)

**SRP Violations Identified:**
- Durance::Model (8 responsibilities) - CRITICAL God Object
- Durance::Schema (7 responsibilities) - Mixed concerns
- Durance::DSL (5 responsibilities) - Definition + SQL generation
- Durance::ResultSet (3 responsibilities) - State + SQL gen + execution

**Deliverables Generated:**
- `ANALYSIS_EXECUTIVE_SUMMARY.txt` - Leadership summary
- `ORM_MODULES_MATRIX.txt` - Quick reference matrix
- `ORM_ARCHITECTURE_SUMMARY.txt` - Detailed breakdown
- `ORM_ARCHITECTURAL_ANALYSIS.md` - Technical deep dive
- `ARCHITECTURAL_ANALYSIS_INDEX.md` - Navigation guide

**Refactoring Roadmap Created:**
- Phase 1: Add dry-run mode + SQL logging (56% → 78% compliance)
- Phase 2: Extract query builder + split Durance::Model (improve SRP)
- Phase 3: Refactor DSL + deduplicate code

Estimated effort: 50-60 hours over 6 weeks

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

### Near Term

| Feature | Description | Priority | Status |
|---------|-------------|----------|--------|
| `has_one()` | One-to-one relationship support | Medium | ✓ COMPLETED |
| `preload()` | Eager loading (2 queries, avoids N+1) | Medium | ✓ COMPLETED |
| COUNT with JOIN | Special handling for COUNT queries with JOINs | Medium | ✓ COMPLETED |

### 17. preload() - ✓ COMPLETED

Implement eager loading to avoid N+1 query problems. This is an **optional** feature 
that users explicitly enable when they want to pre-load related records efficiently.

**Problem:**
- N+1 query problem: Loading 100 users with their posts requires 101 queries (1 + 100)
- Current solutions: `add_joins()` uses SQL JOIN which duplicates rows for has_many
- Need alternative: preload() uses 2 queries to batch-load related records

**Understanding preload() vs add_joins():**

| Aspect | add_joins() | preload() |
|--------|--------------|-----------|
| Queries | 1 query with JOIN | 2 queries (main + related) |
| Row duplication | Yes (duplicates main records) | No (separate result sets) |
| Best for | Filtering by related data | Loading related data |
| Use case | "Find users with active posts" | "Show all users with their posts" |

**Requirements:**
- ✅ Add `preload()` method to ResultSet (chainable like where())
- ✅ Preload has_many relationships (batch load all related records)
- ✅ Preload belongs_to relationships (single query)
- ✅ Preload has_one relationships (single query)
- ✅ Store preloaded data in model instances
- ✅ Subsequent relationship accessors use cached data (no extra queries)
- ✅ Support multiple preloads: `->preload('posts', 'comments')`
- ✅ SQL logging support (via Durance::Logger)
- ✅ Chain with other methods: `->where(...)->preload(...)->all()`
- ✅ No breaking changes to existing API

**Test-Driven Development Implementation Plan:**

**Step 1: Create comprehensive test suite** (`t/preload.t`)
- Test preload has_many relationship
- Test preload belongs_to relationship
- Test preload has_one relationship
- Test multiple preloads in one call
- Test preload with where() conditions
- Test preload with order() and limit()
- Test preload returns correct data (not duplicated)
- Test preload with empty results
- Test preload caches data (no extra queries)
- Test preload SQL logging shows 2 queries

**Step 2: Add preload() method to ResultSet**
- Add `preload_specs` attribute to ResultSet (array ref)
- Add `preload()` chainable method
- Validate relationship names against model's all_relations()
- Store preload specifications for later execution

**Step 3: Implement eager loading logic in all()**
- After main query executes, check if preload_specs exist
- For each preload specification:
  - Extract related records in batch query
  - Map related records to parent record IDs
  - Store in model instances for later access
- Use lazy loading pattern: store in model instance hash

**Step 4: Implement cached relationship access**
- Modify has_many accessor to check for preloaded data first
- Modify belongs_to accessor to check for preloaded data first
- Modify has_one accessor to check for preloaded data first
- Return cached data if available, otherwise query normally

**Step 5: Update ResultSet first() method**
- Ensure preloading works with first() too

**Step 6: SQL logging for preloads**
- Log each preload query separately
- Show total queries executed

**Step 7: Integration testing**
- Run full test suite (t/orm.t + t/preload.t)
- Verify no regressions

**Example Usage After Implementation:**
```perl
# Model definitions
package MyApp::Model::User;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'users';
column id   => (is => 'rw', isa => 'Int', primary_key => 1);
column name => (is => 'rw', isa => 'Str');

has_many posts => (is => 'rw', isa => 'MyApp::Model::Post');
has_one profile => (is => 'rw', isa => 'MyApp::Model::Profile');
belongs_to company => (is => 'rw', isa => 'MyApp::Model::Company');

package MyApp::Model::Post;
use Moo;
extends 'Durance::Model';
use Durance::DSL;

tablename 'posts';
column id      => (is => 'rw', isa => 'Int', primary_key => 1);
column user_id => (is => 'rw', isa => 'Int');
column title   => (is => 'rw', isa => 'Str');

belongs_to user => (is => 'rw', isa => 'MyApp::Model::User');

1;

# Usage - preload has_many
my @users = User->preload('posts')->all;
# SQL 1: SELECT * FROM users
# SQL 2: SELECT * FROM posts WHERE user_id IN (1, 2, 3, ...)

for my $user (@users) {
    my @posts = $user->posts;  # Uses preloaded data - no extra query!
}

# Usage - preload multiple relationships
my @users = User->preload('posts', 'profile')->all;
# SQL 1: SELECT * FROM users
# SQL 2: SELECT * FROM posts WHERE user_id IN (...)
# SQL 3: SELECT * FROM profiles WHERE user_id IN (...)

# Usage - preload with where conditions
my @users = User->where({ active => 1 })
                ->preload('posts')
                ->order('name')
                ->all;
# SQL 1: SELECT * FROM users WHERE active = 1 ORDER BY name
# SQL 2: SELECT * FROM posts WHERE user_id IN (...) AND ...

# Usage - preload belongs_to
my @posts = Post->preload('user')->all;
# SQL 1: SELECT * FROM posts
# SQL 2: SELECT * FROM users WHERE id IN (...)

for my $post (@posts) {
    my $user = $post->user;  # Uses preloaded data!
}

# Comparison: Without preload (N+1 problem)
my @users = User->all;
for my $user (@users) {
    my @posts = $user->posts;  # Each call = 1 query!
}
# 1 + N queries (slow!)
```

**Design Notes:**
- Preload stores data in model instances using a private hash key
- Relationship accessors check cache first before querying
- Cache is instance-specific (per model object)
- Preload queries use WHERE ... IN (...) for efficiency
- Empty preloads handled gracefully (no queries if no parent records)

**Key Differences from add_joins():**

| Feature | add_joins() | preload() |
|---------|--------------|-----------|
| Query count | 1 | 2+ |
| Row duplication | Yes | No |
| Filtering | Can filter by related data | Cannot filter |
| Data access | Flat in results | Nested in objects |
| Memory | Lower (shared rows) | Higher (separate objects) |

**Implementation Summary:**

- ✅ All 10 test cases passing in `t/preload.t`
- ✅ Works with has_many, belongs_to, and has_one relationships
- ✅ Batch loading via WHERE ... IN (...) for efficiency
- ✅ Cached in model instances for subsequent access
- ✅ Chainable with where(), order(), limit()
- ✅ SQL logging shows preload queries

**Test Results:**
- Total tests: 52 passing (15 orm + 9 logger + 8 count_with_join + 10 has_one + 10 preload)

**Effort Estimate:** 4-5 hours

### Long Term

| Feature | Description | Priority | Status |
|---------|-------------|----------|--------|
| MariaDB support | Add database driver support and tests for MariaDB | Low | Pending |
| `many_to_many()` | Junction table relationships | Low | Pending |
| `include()` | JOIN + record inflation for nested objects | Low | Pending |
| Column aliasing | Handle column name collisions in JOINs | Low | Pending |
| Performance testing | Benchmark SQL queries and model operations | Low | Pending |

### Deferred Features

| Feature | Description | Priority | Reason |
|---------|-------------|----------|--------|
| Dry-run mode | Report SQL without executing | Medium | No real-world use case; pending_changes() covers schema review |

---

## Project Rename: ORM → Durance

### Task: Rename project namespace from ORM to Durance

**Objective:** Rename the project from "ORM" to "Durance" and change all `lib/ORM/` namespace to `Durance::`.

**Scope:**
- `lib/ORM/` → `lib/Durance/`
- 6 Perl modules: Model.pm, ResultSet.pm, DSL.pm, Schema.pm, Logger.pm, DB.pm
- All test files referencing Durance:: modules
- Documentation (AGENTS.md, PROJECT_PLAN.md, POD)

**Implementation Plan:**

**Step 1: Rename lib/ORM/ directory to lib/Durance/**
- [ ] `mv lib/ORM lib/Durance`

**Step 2: Update package declarations in all modules**
- [ ] `lib/Durance/DB.pm` - `package Durance::DB;`
- [ ] `lib/Durance/Model.pm` - `package Durance::Model;`
- [ ] `lib/Durance/ResultSet.pm` - `package Durance::ResultSet;`
- [ ] `lib/Durance/DSL.pm` - `package Durance::DSL;`
- [ ] `lib/Durance/Schema.pm` - `package Durance::Schema;`
- [ ] `lib/Durance/Logger.pm` - `package Durance::Logger;`

**Step 3: Update internal references in module files**
- [ ] All `Durance::` references → `Durance::` within module code
- [ ] Update `our` package variables: `%_has_many`, `%_belongs_to`, etc.

**Step 4: Update test files**
- [ ] `t/orm.t` - Update all require/use statements and package references
- [ ] `t/logger.t` - Update all require/use statements
- [ ] `t/count_with_join.t` - Update all require/use statements
- [ ] `t/has_one.t` - Update all require/use statements
- [ ] `t/preload.t` - Update all require/use statements

**Step 5: Update documentation**
- [ ] `AGENTS.md` - Update references and directory structure
- [ ] `PROJECT_PLAN.md` - Update all Durance:: references to Durance::

**Step 6: Update example models (if any)**
- [ ] `t/MyApp/Model/*` - Update extends from 'Durance::Model' to 'Durance::Model'

**Step 7: Run tests and verify**
- [ ] `prove -l t/*.t` - All tests pass
- [ ] Fix any namespace issues discovered during testing

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
