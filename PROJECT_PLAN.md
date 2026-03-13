---

## Task Breakdown

### Task 1: Review the current implementation

#### Step 1.1: Document ORM::Model public API ✓ COMPLETED
- Read lib/ORM/Model.pm and list all public methods with their signatures
- Output: List of method names and signatures

**Findings:** Updated POD documentation in lib/ORM/Model.pm to include:
- Class methods: `create`, `find`, `where`, `all`, `columns`, `column_meta`, `primary_key`, `table`, `dbh`, `db_class`, `validations`, `schema_name`, `attributes`
- Instance methods: `save`, `insert`, `update`, `delete`, `to_hash`
- Package functions: `column`, `tablename`, `has_many`, `belongs_to`, `validates`

Missing methods added to POD: `validations`, `schema_name`, `attributes`

#### Step 1.2: Document ORM::DB public API ✓ COMPLETED
- Read lib/ORM/DB.pm and list all public methods with their signatures
- Output: List of method names and signatures

**Findings:** Updated POD documentation in lib/ORM/DB.pm:
- Fixed typo "ATTRIBUTS" → "ATTRIBUTES"
- Enhanced POD for attributes (dsn, username, password, driver_options)
- Public API includes:
  - Attributes: `dsn` (lazy), `username` (ro), `password` (ro), `driver_options` (lazy)
  - Methods: `dbh` (class method, returns DBI handle), `disconnect_all` (class method, disconnects all pooled handles)

#### Step 1.3: Document ORM::Schema public API ✓ COMPLETED
- Read lib/ORM/Schema.pm and list all public methods with their signatures
- Output: List of method names and signatures

**Findings:** Updated POD documentation in lib/ORM/Schema.pm:
- Fixed documentation mismatch (create_table_for_class → ddl_for_class)
- Added missing `get_all_models_for_app` method to POD
- Added missing `logger` attribute to ATTRIBUTES section
- Added EXAMPLE section

**Public API:**
- Attributes: `dbh`, `model_class`, `driver`, `logger`
- Methods: `ddl_for_class`, `create_table`, `table_exists`, `column_info`, `table_info`, `migrate`, `migrate_all`, `sync_table`, `pending_changes`, `get_all_models_for_app`
- Internal helpers: `_db_class_for`, `_get_dbh_for`, `_detect_driver`, `_type_for`, `_column_sql`, `_pk_sql`, `_build_columns_def`, `_build_create_table_sql`, `_get_app_library_basedir`, `_wantedForModels` (internal, not public)

#### Step 1.4: Document ORM::ResultSet public API ✓ COMPLETED

**Refactor Step 1.4.1: Convert ORM::ResultSet from Mojo::Base to Moo ✓ COMPLETED**
- Replaced `use Mojo::Base -base, -signatures` with `use experimental 'signatures'; use Moo;`
- Converted `has 'class'` to `has 'class' => (is => 'ro', required => 1)`
- Converted `has 'conditions' => sub { {} }` to `has 'conditions' => (is => 'rw', default => sub { {} })`
- Converted `has 'order_by' => sub { [] }` to `has 'order_by' => (is => 'rw', default => sub { [] })`
- Read lib/ORM/ResultSet.pm and list all public methods with their signatures
- Output: List of method names and signatures

**Findings:** Updated POD documentation in lib/ORM/ResultSet.pm:
- Added missing ATTRIBUTES section documenting class, conditions, order_by, limit_val, offset_val
- Fixed typo: "It延迟" → "It lazily"
- Fixed whitespace in example code
- Added =encoding UTF-8 to lib/ORM/Model.pm and lib/ORM/DB.pm
- Replaced UTF-8 arrows (→) with "to" in POD to avoid encoding issues

**Public API:**
- Attributes: `class` (ro, required), `conditions` (rw), `order_by` (rw), `limit_val` (rw), `offset_val` (rw)
- Methods: `where`, `order`, `limit`, `offset`, `all`, `first`, `count`

#### Step 1.5: Identify gaps ✓ COMPLETED
- List which public methods lack test coverage
- Output: Gap report

#### Step 1.6: Map Model methods to test coverage ✓ COMPLETED
- Cross-reference ORM::Model public methods with tests in t/orm.t
- Output: Mapping table of method -> test status

#### Step 1.7: Map DB/Schema methods to test coverage ✓ COMPLETED
- Cross-reference ORM::DB and ORM::Schema methods with tests in t/orm.t
- Output: Mapping table of method -> test status

---

### Step 1.5 & 1.6: Test Coverage Gap Analysis

**Status:** Current active tests fail due to broken `tablename` function in test models.

**Gap Summary:**
- Only 1 test actually runs: `ORM::Schema->get_all_models_for_app`
- ~10+ tests are commented out (lines 51-341 in t/orm.t)
- Multiple methods have **zero test coverage**

---

### Recommended Priority Order for Filling Gaps

#### Priority 1: Foundation (Must fix first)
| # | Module      | Method           | Notes |
|---|-------------|------------------|-------|
| 1 | ORM::DB     | `dbh`            | Used by all DB operations |
| 2 | ORM::DB     | `disconnect_all` | Connection pool cleanup |
| 3 | ORM::Model  | `dbh`            | Get DB handle from model |
| 4 | ORM::Model  | `db_class`       | Specify DB class |
| 5 | ORM::Schema | `ddl_for_class`  | Generate SQL without executing |
| 6 | Package fn  | `column`         | Core model definition |

#### Priority 2: Core CRUD
| # | Module | Method | Notes |
|---|--------|--------|-------|
| 7 | ORM::Model | `create` | Create new record |
| 8 | ORM::Model | `find` | Find by primary key |
| 9 | ORM::Model | `insert` | Insert new record |
| 10 | ORM::Model | `update` | Update existing record |
| 11 | ORM::Model | `save` | Insert or update |
| 12 | ORM::Model | `delete` | Delete record |

#### Priority 3: Query Operations
| # | Module | Method | Notes |
|---|--------|--------|-------|
| 13 | ORM::Model | `all` | Get all records |
| 14-19 | ORM::ResultSet | `where`, `order`, `limit`, `offset`, `all`, `first`, `count` | Query building |

#### Priority 4: Schema Management
| # | Module | Method | Notes |
|---|--------|--------|-------|
| 20-24 | ORM::Schema | `table_exists`, `create_table`, `migrate`, `sync_table`, `pending_changes` | Schema operations |

#### Priority 5: Advanced/Helper Features
| # | Module | Method | Notes |
|---|--------|--------|-------|
| 25-33 | ORM::Model | `to_hash`, `columns`, `column_meta`, `primary_key`, `validations`, `schema_name`, `attributes`, `has_many`, `belongs_to`, `validates` | Helpers & relationships |

#### Priority 6: Edge Cases
| # | Module | Method | Notes |
|---|--------|--------|-------|
| 34-37 | Various | Validation errors, Bool coercion, `column_info`, `table_info` | Error handling & introspection |

---

### Test Status Key
- ✓ = Tested and passing
- ✗ = Test exists but commented out
- **BROKEN** = Test exists but fails due to code bug
- **NOT TESTED** = No test exists

---

### Recommendation

1. **Start with Priority 1** - These are foundation methods needed to make any other tests work
2. **Skip fixing `tablename`** - Instead, use `sub table { 'users' }` method in test models (already done correctly in some test models)
3. **Use inline package definitions** - Define test models inside subtests (like lines 101-117 show) to avoid import issues
4. **One method per test subtest** - Keep tests small and focused

---

## New Task: Refactor ORM::Model Database Connection (Replace `dbh` with `db`)

### Status: COMPLETED ✓

### Goal
Replace the complex `dbh` method in `ORM::Model` with a cleaner `db` attribute that holds a reference to the user's ORM::DB subclass.

### Implementation Completed

#### Step 1: Add `db` attribute to ORM::Model ✓
- Added Moo `db` attribute with lazy builder
- Uses magic fallback to derive DB class from model name

#### Step 2: Remove old `dbh` method ✓
- Deleted the old `dbh` method and `_find_dbh` helper
- Removed `db_class` method (no longer needed)

#### Step 3: Update all internal methods ✓
- Changed `$self->dbh` → `$self->db->dbh` in:
  - `find()` ✓
  - `all()` ✓
  - `create()` ✓
  - `insert()` ✓
  - `update()` ✓
  - `delete()` ✓

#### Step 4: Update ORM::ResultSet ✓
- Modified to use `$class->db->dbh` instead of `$class->dbh`
- Updated to pass `db` to new object instances

#### Step 5: Update to_hash ✓
- Changed to exclude `db` instead of `dbh`

#### Step 6: Update POD documentation ✓
- Updated SYNOPSIS and EXAMPLES
- Documented new `db` attribute and `_build_db` override
- Removed outdated `dbh` and `db_class` documentation

### Design Decisions Applied

| Decision | Rationale |
|----------|------------|
| Remove `dbh` entirely | Cleaner interface - just use `db` |
| Lazy builder for `db` | Defer DB object creation until needed |
| Keep magic fallback | Convention over configuration - works out of box |
| Allow `_build_db` override | Explicit control when needed |

### Files Modified

1. `lib/ORM/Model.pm` - Main refactor ✓
2. `lib/ORM/ResultSet.pm` - Updated to use `db` ✓
3. `lib/ORM/Model.pm` POD - Documentation updates ✓

### Testing

- `perl -Ilib -e 'use ORM::Model; print "OK\n"'` ✓
- `perl -Ilib -e 'use ORM::ResultSet; print "OK\n"'` ✓
- Syntax check passes for both modules ✓

---

## Future Testing Work

The following testing additions will be needed after the review is complete:

- Add tests for any uncovered ORM::Model public methods
- Add tests for any uncovered ORM::DB public methods
- Add tests for any uncovered ORM::Schema public methods
- Add tests for any uncovered ORM::ResultSet public methods
- Ensure all public methods have both success and failure test cases
## Tasks Completed

* ✓ Review the current implementation - All ORM modules documented
* ✓ Replace `dbh` with `db` attribute in ORM::Model - COMPLETED
* ✓ Convert ORM::ResultSet from Mojo::Base to Moo - COMPLETED
* ✓ Fix ORM::Model inheritance with Moo - COMPLETED

## Pending Tasks

* Keep the current ORM::*pm files
* Analyze how each perl package meets the needs of the framework
* Find where modules are not using a single responsibility principle
* Revise @t/orm.t to exercise all public methods

---

## New Task: Create ORM::Model::DSL Module

### Problem Statement
The `import` method in ORM::Model installs DSL functions (`column`, `tablename`, `has_many`, `belongs_to`, `validates`) into the caller's namespace. This doesn't work with Moo's `extends` because Moo does NOT call the parent's `import` method.

### Solution
Create a separate `ORM::Model::DSL` module that users explicitly import to get the DSL functions. This provides a clean, explicit pattern that works with Moo.

### Task 1: Create lib/ORM/Model/DSL.pm

**Description:** Create a new module containing all DSL function definitions.

**Steps:**
1. Create new file `lib/ORM/Model/DSL.pm`
2. Add standard Perl module header (package, use strict, use warnings, use experimental signatures)
3. Use plain Perl (not Moo) to define the module
4. Define a `load_into($caller)` subroutine that installs all DSL functions into the caller's namespace
5. Define the DSL functions inside `load_into`:
   - `column` - lines 24-86 from ORM/Model.pm
   - `tablename` - lines 88-94 from ORM/Model.pm
   - `has_many` - lines 96-134 from ORM/Model.pm
   - `belongs_to` - lines 136-154 from ORM/Model.pm
   - `validates` - lines 156-159 from ORM/Model.pm
6. Define `import` method that calls `load_into(caller)`
7. Add POD documentation explaining usage
8. Add tests to verify the module loads and functions are exported

**Estimated lines of code:** ~200 lines

---

### Task 2: Update lib/ORM/Model.pm to use ORM::Model::DSL

**Description:** Simplify ORM::Model::import to delegate to DSL module.

**Steps:**
1. Modify `ORM::Model::import` to:
   - Check if caller wants DSL functions
   - Load and import from `ORM::Model::DSL`
   - Keep backward compatibility for existing code
2. Example:
   ```perl
   sub import {
       my $class = shift;
       # Check if caller wants DSL functions (based on @_ or heuristics)
       if (@_ || $caller ne 'ORM::Model') {
           require ORM::Model::DSL;
           ORM::Model::DSL->import(@_);
       }
   }
   ```

**Estimated changes:** ~20 lines

---

### Task 3: Update test models to use ORM::Model::DSL

**Description:** Fix the broken test models by explicitly importing DSL functions.

**Files to update:**
- `t/MyApp/Model/app/user.pm`
- `t/MyApp/Model/admin/role.pm`

**Changes:**
1. Add `use ORM::Model::DSL;` after `extends 'ORM::Model';`
2. Example:
   ```perl
   package MyApp::Model::app::user;
   use Moo;
   extends 'ORM::Model';
   use ORM::Model::DSL;
   
   tablename 'users';
   column id => ...
   ```

**Estimated changes:** 2 files, ~1 line each

---

### Task 4: Update POD documentation in lib/ORM/Model.pm

**Description:** Document the new DSL module usage pattern.

**Steps:**
1. Update SYNOPSIS to show both approaches:
   ```perl
   # Option 1: With Moo + DSL module
   package MyApp::Model::User;
   use Moo;
   extends 'ORM::Model';
   use ORM::Model::DSL;
   
   # Option 2: Direct ORM::Model (still works)
   ```
2. Add new section "DSL FUNCTIONS" documenting each function
3. Cross-reference ORM::Model::DSL

**Estimated changes:** ~50 lines of POD

---

### Task 5: Verify tests pass

**Description:** Run the test suite to ensure everything works.

**Steps:**
1. Run `perl -Ilib t/orm.t`
2. Fix any remaining issues

---

## Files Created/Modified

| File | Action |
|------|--------|
| `lib/ORM/Model/DSL.pm` | **CREATE** |
| `lib/ORM/Model.pm` | MODIFY |
| `t/MyApp/Model/app/user.pm` | MODIFY |
| `t/MyApp/Model/admin/role.pm` | MODIFY |

---

## User Experience After Changes

```perl
# User's model - clean and minimal
package MyApp::Model::User;
use Moo;
extends 'ORM::Model';
use ORM::Model::DSL;  # <-- NEW: explicitly import DSL

column id      => (is => 'rw', isa => 'Int', primary_key => 1);
column name    => (is => 'rw', isa => 'Str', required => 1);

sub table { 'users' }

1;
```

---

---

## New Task: Fix `tablename` Issue in Test Models

### Root Cause
- Moo's `extends` does NOT call the parent class's `import` method
- Therefore, `column`, `tablename`, `has_many`, `belongs_to`, `validates` functions are NOT installed
- The error "String found where operator expected" happens because Perl doesn't recognize `tablename` as a function

### Solution: Task 3 above (use ORM::Model::DSL)

---

## New Task: Rename DSL Namespace from ORM::Model::DSL to ORM::DSL

### Problem Statement
The DSL module was created as `ORM::Model::DSL` but this is verbose. A cleaner namespace `ORM::DSL` is preferred for user-facing API.

### Goal
Rename the DSL module from `ORM::Model::DSL` to `ORM::DSL`.

### Status: COMPLETED ✓

### Tasks

#### Task 1: Move DSL module to new namespace
**Status:** COMPLETED ✓
1. Created `lib/ORM/DSL.pm` (copy from `lib/ORM/Model/DSL.pm`) ✓
2. Changed package declaration from `package ORM::Model::DSL;` to `package ORM::DSL;` ✓
3. Updated POD NAME from `ORM::Model::DSL` to `ORM::DSL` ✓
4. Updated SYNOPSIS examples to use `use ORM::DSL;` ✓
5. **Removed debug print statement** on line 53 ✓
6. **Fixed `tablename` function** - Added `no strict 'refs'` inside the sub to ensure symbolic references work ✓
7. Deleted old file `lib/ORM/Model/DSL.pm` ✓

**Files:**
- CREATE: `lib/ORM/DSL.pm`
- DELETE: `lib/ORM/Model/DSL.pm`

#### Task 2: Update test models to use new namespace
**Status:** COMPLETED ✓
1. `t/MyApp/Model/app/user.pm` - Changed `use ORM::Model::DSL;` to `use ORM::DSL;` ✓
2. `t/MyApp/Model/admin/role.pm` - Changed `use ORM::Model::DSL;` to `use ORM::DSL;` ✓

#### Task 3: Update ORM::Model documentation
**Status:** COMPLETED ✓
1. Updated comment in `lib/ORM/Model.pm` Line 20 to reference `ORM::DSL` ✓

### Verification
```
$ perl -Ilib t/orm.t 2>&1
    Found model class 'MyApp::Model::app::user'
        -> manages table 'users'
    Found model class 'MyApp::Model::admin::role'
        -> manages table 'roles'
```

**Result:** The `tablename` function is correctly setting package variables and the `table()` method is successfully reading them.

### User Experience After Changes
```perl
package MyApp::Model::User;
use Moo;
extends 'ORM::Model';
use ORM::DSL;

tablename 'users';
column id => (is => 'rw', isa => 'Int', primary_key => 1);
```

### Files Modified Summary
| File | Action |
|------|--------|
| `lib/ORM/DSL.pm` | **CREATE** |
| `lib/ORM/Model/DSL.pm` | **DELETE** |
| `lib/ORM/Model.pm` | MODIFY (comment) |
| `t/MyApp/Model/app/user.pm` | MODIFY |
| `t/MyApp/Model/admin/role.pm` | MODIFY |

---

## Testing Plan: Iterative Test Coverage for ORM Framework

### Phase 1: Test ORM::DB (Database Connection)

**Step 1.1: Create a minimal test DB class**
- Create `TestDB` package in the test file that extends `ORM::DB`
- Override `_build_dsn` to use an in-memory SQLite database (`:memory:`)

**Step 1.2: Test ORM::DB attributes**
- Test `dsn` attribute returns correct DSN
- Test `username` and `password` attributes (can be empty)
- Test `driver_options` returns default hashref with `RaiseError` and `AutoCommit`

**Step 1.3: Test ORM::DB methods**
- Test `dbh` method returns a connected DBI handle
- Test handle pooling (calling `dbh` twice returns same handle)
- Test `disconnect_all` clears the pool
- Test `ping` validates connection is still alive

---

### Phase 2: Test ORM::Schema with TestDB

**Step 2.1: Test ORM::Schema constructor and attributes**
- Create `ORM::Schema` instance with `dbh` from TestDB
- Test `driver` auto-detection from dbh

**Step 2.2: Test DDL generation (no execution)**
- Test `ddl_for_class` generates valid CREATE TABLE SQL for SQLite
- Test `ddl_for_class` with explicit 'mysql' driver generates MySQL syntax
- Test type mapping (Int→INTEGER, Str→TEXT, Bool→INTEGER for SQLite)

**Step 2.3: Test table introspection**
- Test `table_exists` returns false for non-existent table
- Test `table_info` returns empty list for non-existent table

---

### Phase 3: Create Test Model & Test Migration Logic

**Step 3.1: Create a simple test model**
- Define `TestModel` package with minimal columns (id, name)
- Use `use ORM::DSL;` for DSL functions
- Define `sub table { 'test_items' }`

**Step 3.2: Test table creation**
- Test `create_table` creates the table in database
- Test `table_exists` returns true after creation
- Test `table_info` returns column metadata

**Step 3.3: Test migration/add columns**
- Add a new column to TestModel definition
- Test `migrate` adds the new column to existing table
- Test `pending_changes` reports missing columns
- Test `sync_table` creates table if missing, migrates if exists

---

### Phase 4: Test ORM::Model CRUD Operations

**Step 4.1: Test model instantiation**
- Test `new` creates instance with attributes
- Test `columns` returns list of column names
- Test `column_meta` returns metadata for a column
- Test `primary_key` returns the primary key column name

**Step 4.2: Test create operations**
- Test `create` class method creates and returns model instance
- Test `insert` instance method inserts record and sets primary key
- Test `save` on new instance performs INSERT

**Step 4.3: Test read operations**
- Test `find` retrieves record by primary key
- Test `all` retrieves all records
- Test `where` with conditions returns matching records

**Step 4.4: Test update operations**
- Test `update` modifies existing record
- Test `save` on existing instance performs UPDATE

**Step 4.5: Test delete operations**
- Test `delete` removes record from database

**Step 4.6: Test ResultSet chainable methods**
- Test `where(...)->order(...)->limit(...)->offset(...)->all`
- Test `first` returns first matching record
- Test `count` returns number of records

**Step 4.7: Test utility methods**
- Test `to_hash` returns hash without db/dbh keys
- Test `attributes` returns column list
- Test `validations` returns validation rules

---

### Summary of Discrete Steps

| Phase | Step | Description | Status |
|-------|------|-------------|--------|
| 1 | 1.1 | Create minimal TestDB class | ✓ COMPLETED |
| 1 | 1.2 | Test ORM::DB attributes | ✓ COMPLETED |
| 1 | 1.3 | Test ORM::DB methods (dbh, disconnect_all) | ✓ COMPLETED |
| 2 | 2.1 | Test ORM::Schema constructor | ✓ COMPLETED |
| 2 | 2.2 | Test DDL generation (ddl_for_class) | ✓ COMPLETED |
| 2 | 2.3 | Test table introspection | ✓ COMPLETED |
| 3 | 3.1 | Create TestModel for migration tests | ✓ COMPLETED |
| 3 | 3.2 | Test create_table | ✓ COMPLETED |
| 3 | 3.3 | Test migrate/pending_changes/sync_table | ✓ COMPLETED |
| 4 | 4.1 | Test model instantiation and metadata | ✓ COMPLETED |
| 4 | 4.2 | Test create/insert/save | ✓ COMPLETED |
| 4 | 4.3 | Test find/all/where | ✓ COMPLETED |
| 4 | 4.4 | Test update | ✓ COMPLETED |
| 4 | 4.5 | Test delete | ✓ COMPLETED |
| 4 | 4.6 | Test ResultSet chainable methods | ✓ COMPLETED |
| 4 | 4.7 | Test utility methods (to_hash, etc) | ✓ COMPLETED |

---

## Current Project State

### Working Components ✓

| Module | Status | Notes |
|--------|--------|-------|
| `lib/ORM/DSL.pm` | ✓ WORKING | Namespace fixed, all functions export correctly |
| `lib/ORM/Model.pm` | ✓ WORKING | Converted to Moo, DSL functions in separate module |
| `lib/ORM/DB.pm` | ✓ WORKING | Converted to Moo, lazy initialization working |
| `lib/ORM/ResultSet.pm` | ✓ WORKING | Converted to Moo, chainable queries working |
| `lib/ORM/Schema.pm` | ✓ WORKING | Model discovery and migration working |

### Test Status

**Current Test Output:**
```
ok 1 - ORM::DB - attributes and methods {
    ok 1 - attributes ...
    ok 2 - dbh method ...
    ok 3 - handle pooling ...
    ok 4 - disconnect_all ...
    ok 5 - isDSNValid ...
}
ok 2 - ORM::Schema - constructor and attributes
ok 3 - ORM::Schema - DDL generation
ok 4 - ORM::Schema - table introspection
ok 5 - ORM::Schema - table creation and migration
ok 6 - ORM::Model - CRUD operations
ok 7 - ORM::Model - Error handling
ok 8 - ORM::Model - Relationship functions
ok 9 - ORM::Model - Validation functions
ok 10 - ORM::Model - Basic attributes
```

**Status:** Tests are **PASSING** (10 test suites)

**Test Coverage:**
- ✓ DSL functions properly exported and functional
- ✓ `tablename` function sets package variables correctly
- ✓ `table()` method reads package variables successfully
- ✓ Model discovery via `get_all_models_for_app()`
- ✓ All modules load without errors
- ✓ Column definitions and metadata
- ✓ CRUD operations (create, find, update, delete, where, all)
- ✓ Schema operations (create_table, table_exists, migrate)
- ✓ Validation functions (format, length, Bool coercion)
- ✓ Relationship functions (has_many, belongs_to)
- ✓ ResultSet operations (order, limit, offset, first, count)
- ✓ Error handling (find not found, update/delete without pk, invalid DSN)
- ✓ column_meta and schema_name methods
- ✓ isDSNValid() method

### Test File Structure

The test file `t/orm.t` has been refactored:
- **Old structure:** Comprehensive tests (all commented out except one)
- **New structure:** Focus on getting basic functionality working
- **Current location:** Lines 29-47 (active test)
- **Old tests:** Lines 52-341 (commented out with `__END__`)

---

## Summary of Completed Work

### Major Refactoring (Commits 5e8d92f, a36715d, 0ec6454)

1. **Moo Migration** - All ORM modules converted from `Mojo::Base` to `Moo`
2. **DSL Namespace Fix** - Renamed `ORM::Model::DSL` → `ORM::DSL`
3. **Database Connection Refactor** - Changed from `dbh` method to `db` attribute
4. **Test Updates** - Updated test models to use new DSL module
5. **Documentation** - Updated POD and AGENTS.md with new standards

### Key Changes

| Change | Before | After |
|--------|--------|-------|
| DSL Module | `ORM::Model::DSL` | `ORM::DSL` |
| Database Access | `$model->dbh` | `$model->db->dbh` |
| OO Framework | `Mojo::Base` | `Moo` |
| Model Definition | `use base ORM::Model` | `use Moo; extends 'ORM::Model'` |
| DSL Import | (automatic via import) | `use ORM::DSL;` |

### Files Changed
- `lib/ORM/DSL.pm` (new)
- `lib/ORM/Model.pm` (major refactor)
- `lib/ORM/DB.pm` (major refactor)
- `lib/ORM/ResultSet.pm` (converted to Moo)
- `lib/ORM/Schema.pm` (enhanced with model discovery)
- `t/orm.t` (refactored test structure)
- `t/MyApp/Model/app/user.pm` (updated to use ORM::DSL)
- `t/MyApp/Model/admin/role.pm` (updated to use ORM::DSL)
- `AGENTS.md` (updated coding standards)
- `cpanfile` (updated dependencies)

---

## Next Steps

### Immediate Priority

1. **Uncomment and fix remaining tests** - Lines 52-341 in t/orm.t contain the original test suite that needs to be updated to work with the new framework

### Medium Term

2. **Add test coverage** - Verify all public methods have test coverage:
   - CRUD operations
   - Schema management
   - Relationship functions
   - Validation functions

3. **Add test models** - Re-add deleted models (Post, User, Permission, Account) or create new ones for testing

4. **Verify end-to-end workflow** - Test full model lifecycle from definition to database operations

### Long Term

5. **Performance testing** - Benchmark SQL queries and model operations
6. **Error handling tests** - Test failure scenarios and edge cases
7. **Documentation** - Complete POD documentation for all modules

---

## Specific Next Tasks

### Task 1: Restore and Update Full Test Suite

**Goal:** Uncomment and fix the remaining tests in t/orm.t (lines 52+)

**Approach:**
1. Read the commented-out test code
2. Update test models to use `use ORM::DSL;` instead of old patterns
3. Fix any API changes (e.g., `dbh` → `db->dbh`)
4. Uncomment tests one at a time, verifying each works

**Files to update:**
- `t/orm.t` - Uncomment lines 52-341
- May need to re-create deleted test models if needed

### Task 2: Add Comprehensive Test Models

**Goal:** Ensure we have test models for all scenarios

**Models needed:**
- `MyApp::Model::User` - Basic user model
- `MyApp::Model::Post` - Model with relationships
- `MyApp::Model::Account` - belongs_to relationship
- `MyApp::Model::Permission` - has_many relationship

**Approach:**
1. Re-create deleted model files or create new ones
2. Use the new `use ORM::DSL;` pattern
3. Test all DSL functions (column, tablename, has_many, belongs_to, validates)

### Task 3: Verify CRUD Operations

**Goal:** Ensure create, read, update, delete all work

**Test cases:**
- `create()` - Insert new record
- `find()` - Retrieve by primary key
- `all()` - Get all records
- `where()` - Query with conditions
- `update()` - Modify existing record
- `delete()` - Remove record

### Task 4: Schema Management Tests

**Goal:** Test database schema operations

**Test cases:**
- `create_table()` - Create new table
- `table_exists()` - Check if table exists
- `migrate()` - Add missing columns
- `sync_table()` - Create or migrate table
- `pending_changes()` - Report schema differences

### Task 5: Relationship Tests

**Goal:** Verify has_many and belongs_to work correctly

**Test cases:**
- `has_many` - Query related records
- `belongs_to` - Query parent record
- `create_has_many()` - Create related record with foreign key

---

## Project Milestones

| Milestone | Status | Description |
|-----------|--------|-------------|
| Moo Migration | ✓ DONE | All modules converted from Mojo::Base to Moo |
| DSL Namespace Fix | ✓ DONE | Renamed to ORM::DSL, tests passing |
| Test Framework | ✓ DONE | 10 test suites passing |
| CRUD Operations | ✓ DONE | All CRUD operations tested |
| Schema Management | ✓ DONE | Schema operations tested |
| Relationship Tests | ✓ DONE | has_many, belongs_to tested |
| Full Test Coverage | ⚠ IN PROGRESS | Core methods tested, some edge cases remain |
| isDSNValid() | ✓ DONE | Added explicit DSN validation method |

---

## Remediation: SQLite2 and In-Memory DB Issues

### Problem 1: SQLite2 Driver Not Supported
The test file `t/MyApp/DB.pm` uses deprecated `dbi:SQLite2:` DSN which is not supported.

### Problem 2: In-Memory SQLite Doesn't Work with Connection Pooling
In-memory SQLite databases are connection-specific - each new DBI connection creates a new database.

### Solution
- Step 1: Fix SQLite2 → SQLite (t/MyApp/DB.pm)
- Step 2: Use file-based temp SQLite in tests (t/orm.t)

---

## Phase 4 Fix: DSL Column Values in new()

### Problem
When calling `$model->new(name => 'bob')`:
1. Moo's `new()` only handles attributes defined via `has`
2. DSL columns are dynamically created methods, not `has` attributes
3. Moo ignores DSL column values - they never get set in `$self->{hash}`
4. Result: `$model->name()` returns undef

### Solution: Use Moo's BUILD Hook

Instead of overriding `new()`, use Moo's `BUILD` hook:

```perl
sub BUILD {
    my ($self, $args) = @_;
    
    my $class = ref $self || $self;
    my $cols = $class->columns;
    
    for my $col (@$cols) {
        if (exists $args->{$col} && defined $args->{$col}) {
            $self->{$col} = $args->{$col};
        }
    }
}
```

### Implementation
1. Add `sub BUILD` method to `lib/ORM::Model`
2. Test CRUD tests pass
3. Add count() delegate to ORM::Model (optional)

---

## Fix: Data Doesn't Persist Between Test Subtests

### Problem
- TestDB uses random temp file (`orm_test_XXXX.db`)
- Each `TestDB->new` creates new object instance
- Data doesn't persist between test subtests

### Solution: Use Fixed DB File

1. **Change TestDB DSN** to use FindBin:
   ```perl
   use FindBin;
   sub _build_dsn { "dbi:SQLite:dbname=$FindBin::Bin/MyApp/var/test.db" }
   ```

2. **Delete file at test start**:
   ```perl
   my $test_db_path = "$FindBin::Bin/MyApp/var/test.db";
   unlink $test_db_path if -e $test_db_path;
   ```

3. **Connection pooling works automatically** - Same DSN = same pooled handle

### Benefits
- Uses FindBin (not hardcoded path)
- Uses `unlink` (not rmtree)
- Connection pooling works correctly  
- Deterministic test runs

---

## Plan: Merge `_db` into `db` in ORM::Model

### Current State

| Method | Context | Purpose |
|--------|---------|---------|
| `db($self)` | instance/class | Public API - returns DB instance |
| `_db($class)` | class only | Internal - creates DB instance |
| `_db_class_for($class)` | class only | Helper - derives DB class name (separate, testable) |

### Current Usages

**Using `->_db` (class methods):**
- `find()` - lib/ORM/Model.pm:135
- `all()` - lib/ORM/Model.pm:149
- `create()` - lib/ORM/Model.pm:192
- ResultSet - lib/ORM/ResultSet.pm:73

**Using `->db` (instance methods):**
- `insert()` - lib/ORM/Model.pm:201
- `update()` - lib/ORM/Model.pm:228
- `delete()` - lib/ORM/Model.pm:263

### Proposed Changes

1. **Modify `db()`** to handle both instance and class contexts:

   ```perl
   sub db ($self) {
       my $class = ref $self || $self;
       
       # Instance: return stored db if exists
       if (ref $self && exists $self->{db}) {
           return $self->{db};
       }
       
       # Derive DB class and create instance
       my $db_class = $class->_db_class_for;
       eval "require $db_class";
       die "Cannot load DB class $db_class: $@" if $@;
       return $db_class->new;
   }
   ```

2. **Update callers** - replace `->_db` with `->db`:
   - `find()` (line 135)
   - `all()` (line 149)
   - `create()` (line 192)
   - ResultSet (line 73)

3. **Remove `_db()` method** - functionality merged into `db()`

4. **Keep `_db_class_for` unchanged** - already separate and testable

### Benefits
- Single public method `db()` for users
- `_db_class_for` remains testable in isolation
- Cleaner API - no underscore-prefixed method for common operation

### Files to Modify
- `lib/ORM/Model.pm` - Merge `_db` into `db`, update callers
- `lib/ORM/ResultSet.pm` - Update caller to use `->db` instead of `->_db`

---

## Bug Fix: Schema.pm passes string instead of model to table_info()

### Problem
Test failures in "ORM::Schema - table creation and migration":
```
Can't locate object method "table" via package "create_test"
```

### Root Cause
In `lib/ORM/Schema.pm`, the `migrate()` method at line 348 passes `$table` (string) instead of `$model` (object) to `table_info()`.

**Bug 1 - Line 348:**
```perl
for my $col ( $self->table_info($table) ) {  # BUG: $table is string
```

**Bug 2 - Line 386:**
```perl
return ["Created table: $class->table"];  # BUG: $class is string
```

### Fix Plan
1. **Line 348:** Change `$self->table_info($table)` → `$self->table_info($model)`
2. **Line 386:** Change `$class->table` → `$model->table`

### Files to Modify
- `lib/ORM/Schema.pm`

---

## Bug Fix: db() method creates new instance on every call

### Problem
Test failures in CRUD operations:
- `create()` works (inserts data)
- `find()` returns undef (can't see data from create)

### Root Cause
Each call to `$class->db` creates a NEW DB instance. When `create()` inserts and `find()` queries, they use different database connections, so data isn't visible.

### Fix Plan
Add class-level caching to `db()` method in `lib/ORM/Model.pm`:

```perl
sub db {
    my $self = shift;
    my $class = ref $self || $self;
    
    # Instance: return stored db if exists
    if (ref $self && exists $self->{db}) {
        return $self->{db};
    }
    
    # Class: check for cached db instance (package variable)
    my $cache_key = "_db_cache";
    {
        no strict 'refs';
        return $$class{$cache_key} if exists $$class{$cache_key};
        
        # Create and cache new instance
        my $db_class = $class->_db_class_for;
        eval "require $db_class";
        die "Cannot load DB class $db_class: $@" if $@;
        my $db = $db_class->new;
        $$class{$cache_key} = $db;
        
        return $db;
    }
}
```

### Files to Modify
- `lib/ORM/Model.pm` - Add class-level caching to db() method

---

## Fix Fragile Test Assertions in t/orm.t

### Problem
Tests use hardcoded IDs and counts that break when:
- Tests run in different order
- Data persists between tests
- Table is reused across test phases

### Fragile Assertions Identified

| Line | Current Code | Issue |
|------|--------------|-------|
| 338 | `find(1)` | Assumes first record has id=1 |
| 340 | `found->name eq 'Alice'` | Assumes first record is Alice |
| 343 | `scalar @all == 3` | Assumes exactly 3 records |
| 351, 355 | `find(1)` | Assumes id=1 exists |
| 360 | `find(1)` | Assumes id=1 exists |
| 364 | `scalar @all == 2` | Assumes exactly 2 records |

### Fix Plan
1. **4.3 Test find and all**: 
   - Use `$user->id` from create instead of hardcoded `1`
   - Use `first()` to find records instead of `find(1)`
   - Use `$all[-1]` or count dynamic check instead of hardcoded count

2. **4.4 Test update**:
   - Use `$user->id` from previously created user
   
3. **4.5 Test delete**:
   - Use `$user->id` from previously created user

### Files to Modify
- `t/orm.t` - Update fragile assertions to use dynamic values

---

## Test Coverage: Relationship Functions ✓ COMPLETED

### Goal
Add test coverage for `has_many`, `belongs_to`, and related helper methods.

### Current Coverage Gaps

| Method | Module | Status |
|--------|--------|--------|
| `column_meta` | ORM::Model | ❌ Not tested |
| `validations` | ORM::Model | ❌ Not tested |
| `schema_name` | ORM::Model | ❌ Not tested |
| `has_many` | ORM::Model/DSL | ❌ Not tested |
| `belongs_to` | ORM::Model/DSL | ❌ Not tested |
| `validates` | ORM::Model/DSL | ❌ Not tested |
| Validation errors | Various | ❌ Not tested |
| Bool coercion | ORM::Model | ❌ Not tested |

### Plan: Add Relationship Tests

#### Test Models
Create test models with relationships:
- `User` has_many `Post`
- `Post` belongs_to `User`

#### Test Cases
1. Test `has_many` defines relationship metadata
2. Test `belongs_to` defines relationship metadata
3. Test relationship query methods work correctly
4. Test foreign key is set automatically on related object creation

### Files to Modify
- `t/orm.t` - Add new test subtest for relationships

---

## Test Coverage: column_meta and schema_name ✓ COMPLETED

### Goal
Add test coverage for `column_meta` and `schema_name` methods.

### Method Overview

**1. `schema_name($class)`**
- Extracts schema name from package name
- Example: `MyApp::Model::app::user` → returns `app`
- Example: `MyApp::Model::admin::role` → returns `admin`

**2. `column_meta($class, $column)`**
- Returns metadata hash for a column
- Includes: `is`, `isa`, `primary_key`, `required`, `unique`, `length`, `default`

### Test Plan

#### Test 1: `schema_name` method
- Test extraction of schema from package name
- Test with nested schemas (e.g., app, admin)

#### Test 2: `column_meta` method
- Test reading metadata for columns (primary_key, isa, required)
- Test returns empty hash for non-existent column

### Files to Modify
- `t/orm.t` - Add test cases to existing test structure

---

## Test Coverage: Validation Functions ✓ COMPLETED

### Goal
Add test coverage for `validates` function and related validation behavior.

### Current Implementation
The `validates` function stores rules that are enforced in column setters:

| Validation | Implemented | Location |
|------------|-------------|----------|
| `required` | ✓ Yes | DSL.pm line 90-94 |
| `format` | ✓ Yes | DSL.pm line 95-99 |
| `length` | ✓ Yes | DSL.pm line 103-105 |
| Bool coercion | ✓ Yes | DSL.pm line 100-102 |

### Test Cases to Add

1. **Required validation**
   - Create model with `required => 1` on column
   - Try to set undefined value → should die

2. **Format validation**
   - Create model with `format => qr/@/` on email
   - Set invalid email → should die
   - Set valid email → should pass

3. **Length validation**
   - Create model with `length => 5` on column
   - Set value longer than 5 → should die

4. **Bool coercion**
   - Test truthy/falsy values coerce correctly (0/1)

### Files to Modify
- `t/orm.t` - Add new test subtest for validations

---

## Additional Test Coverage Gaps

Based on code review, there are remaining areas that could benefit from test coverage.

---

## Test Coverage: Error Handling ✓ COMPLETED

### Goal
Add tests for error conditions and edge cases.

### Discrete Steps

#### Step EH-1: Test find() returns undef when record not found
- Create model with data
- Call find() with non-existent ID
- Assert returns undef (not exception)

#### Step EH-2: Test update() without primary key throws
- Create object without id
- Call update() 
- Assert dies with appropriate error

#### Step EH-3: Test delete() without primary key throws
- Create object without id
- Call delete()
- Assert dies with appropriate error

#### Step EH-4: Test db() when DB class cannot be loaded
- Mock scenario where DB class is missing
- Assert appropriate error message

### Files to Modify
- `t/orm.t` - Add error handling tests

---

## Test Coverage: Auto-Timestamps ✓ COMPLETED

### Goal
Test that created_at and updated_at are automatically populated.

### Discrete Steps

#### Step AT-1: Test create() sets created_at
- Create model with created_at column
- Call create()
- Assert created_at is set and not empty

#### Step AT-2: Test create() sets updated_at
- Create model with updated_at column
- Call create()
- Assert updated_at is set

#### Step AT-3: Test update() sets updated_at
- Create record
- Wait briefly, call update() 
- Assert updated_at changed (newer than created_at)

#### Step AT-4: Test timestamps are NOT auto-set if columns don't exist
- Create model WITHOUT created_at/updated_at columns
- Call create() and update()
- Assert no errors (silently skipped)

### Files Modified
- `t/orm.t` - Added timestamp tests

---

## Test Coverage: Complex ResultSet Queries ✓ IN PROGRESS

### Goal
Test ResultSet with various query operators and conditions.

### Part A: Test Existing Features (6 steps)

#### Step RQ-1: Test where() with comparison operators
- Add records with numeric values
- Query with `{ age => { '>' => 21 } }`
- Assert only matching records returned

#### Step RQ-2: Test where() with LIKE operator
- Add records with string values
- Query with `{ name => { 'LIKE' => 'J%' } }`
- Assert pattern matching works

#### Step RQ-3: Test where() with multiple conditions
- Query with multiple AND conditions
- Assert all conditions applied

#### Step RQ-4: Test order() with multiple columns
- Add records
- Query with order('name', 'age')
- Assert correct multi-column sorting

#### Step RQ-5: Test order() with DESC
- Query with order('name DESC')
- Assert descending order

#### Step RQ-6: Test offset() without limit
- Add records
- Query with offset(2)
- Assert skips first 2 records

### Part B: Add JOIN Support (Future Feature)

---

## Feature: JOIN Support (ActiveRecord-style) ✓ PLANNED

### Goal
Add SQL JOIN support to the ORM so related data can be fetched in a single query.

### Current State
- `has_many` and `belongs_to` exist but run **separate queries** (N+1 problem)
- Foreign key convention: `${name}_id` (e.g., `belongs_to company` → `company_id`)
- ResultSet supports `where()`, `order()`, `limit()`, `offset()` but no JOINs

---

## Discrete Implementation Steps

### Step JOIN-1: Add relationship introspection methods

Add to `lib/ORM/Model.pm`:

```perl
sub has_many_relations ($class) {
    return $ORM::DSL::_has_many{$class} // {};
}

sub belongs_to_relations ($class) {
    return $ORM::DSL::_belongs_to{$class} // {};
}

sub related_to ($class, $name) {
    return $ORM::DSL::_has_many{$class}{$name} 
        // $ORM::DSL::_belongs_to{$class}{$name};
}
```

**Test**: Verify these methods return relationship metadata.

---

### Step JOIN-2: Add `joins()` to ResultSet

Add to `lib/ORM/ResultSet.pm`:

```perl
has 'joins' => (is => 'rw', default => sub { [] });

sub joins ($self, @relations) {
    push @{$self->joins}, @relations;
    return $self;
}
```

**Test**: Verify joins() can be chained.

---

### Step JOIN-3: Build JOIN SQL in all() method

Modify `all()` to generate JOIN clauses from relationship metadata. Key logic:

- **belongs_to**: `JOIN related ON related.id = local.foreign_key`
- **has_many**: `JOIN related ON related.foreign_key = local.id`

```perl
# Build JOIN clauses
my @join_parts;

for my $rel (@{$self->joins}) {
    my ($rel_name, $rel_opts);
    
    if (ref $rel eq 'HASH') {
        ($rel_name, $rel_opts) = %$rel;
    }
    else {
        $rel_name = $rel;
        $rel_opts = {};
    }
    
    # Look up relationship metadata
    my $meta = $class->related_to($rel_name);
    
    # Determine JOIN type (default LEFT)
    my $join_type = $rel_opts->{type} // 'LEFT';
    
    # Determine tables and keys
    my $related_class = $meta->{isa};
    my $related_table = $related_class->table;
    my $foreign_key = $meta->{foreign_key} // "${rel_name}_id";
    my $local_pk = $class->primary_key;
    
    # Build ON clause based on relationship type
    my $on_clause;
    if ($meta->{_relationship_type} eq 'belongs_to') {
        $on_clause = "$related_table.id = $table.$foreign_key";
    }
    else {
        $on_clause = "$related_table.$foreign_key = $table.$local_pk";
    }
    
    # Allow override
    $on_clause = $rel_opts->{on} // $on_clause;
    
    push @join_parts, "$join_type JOIN $related_table ON $on_clause";
}

# Append to SQL
$sql .= " " . join(' ', @join_parts) if @join_parts;
```

**Test**: Verify SQL includes JOIN clauses.

---

### Step JOIN-4: Tag relationships with type

In `lib/ORM/DSL.pm`, add `_relationship_type` to relationship metadata:

```perl
# In has_many function:
$_has_many{$pkg}{$name}{_relationship_type} = 'has_many';

# In belongs_to function:
$_belongs_to{$pkg}{$name}{_relationship_type} = 'belongs_to';
```

**Test**: Verify relationship metadata includes type.

---

### Step JOIN-5: Support explicit hash overrides

Allow users to override conventions:

```perl
User->joins({ accounts => { 
    on => 'accounts.user_id = users.id',
    type => 'INNER' 
}})
```

**Test**: Verify explicit overrides work.

---

### Step JOIN-6: Add comprehensive tests

Test cases to add in `t/orm.t`:

1. Basic belongs_to JOIN
2. Basic has_many JOIN
3. Multiple JOINs
4. JOIN with WHERE conditions
5. JOIN with ORDER BY
6. JOIN with LIMIT/OFFSET
7. Explicit hash JOIN
8. Mixed string and hash JOINs
9. Column name collision handling

---

## API Design

### String API (auto-detect - convention-based)

```perl
User->joins('accounts')->all           # has_many
User->joins('company')->all             # belongs_to
User->joins('company', 'accounts')->all # multiple JOINs
```

### Hash API (explicit override)

```perl
User->joins({ 
    accounts => { 
        on => 'accounts.user_id = users.id',
        type => 'INNER' 
    }
})->all
```

### Mixed

```perl
User->joins('company', { accounts => { type => 'INNER' } })->all
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/ORM/Model.pm` | Add `has_many_relations`, `belongs_to_relations`, `related_to` methods |
| `lib/ORM/ResultSet.pm` | Add `joins` attribute and `joins()` method, update `all()` for JOIN SQL |
| `lib/ORM/DSL.pm` | Tag relationships with `_relationship_type` in has_many/belongs_to |
| `t/orm.t` | Add JOIN test subtests |

---

## Future Features (Post-JOIN)

After basic JOINs work, these can be added later:

| Feature | Description |
|---------|-------------|
| `preload()` | Eager loading (2 queries, avoids N+1) |
| `has_one()` | One-to-one relationship |
| `many_to_many()` | Junction table relationships |
| `include()` | JOIN + record inflation for nested objects |

---

## Key Edge Cases to Handle

1. **Column name collisions**: If both tables have `id` column, need aliasing
2. **Missing relationships**: `joins('nonexistent')` should warn or die
3. **No primary key**: JOINs require primary keys - validate this
4. **Chaining**: `joins()` should return $self for chaining
5. **COUNT with JOIN**: Need special handling for COUNT queries with JOINs

---

## Implementation Notes

1. Start with simple case: single belongs_to JOIN
2. Test SQL output at each step before proceeding
3. Use file-based SQLite for testing (not :memory:)
4. Keep backward compatibility - existing has_many/belongs_to should still work
5. Auto-detect hash vs string input in joins() method

### Files Modified
- `t/orm.t` - Added complex query tests

#### Step RQ-3: Test where() with multiple conditions
- Query with multiple AND conditions
- Assert all conditions applied

#### Step RQ-4: Test order() with multiple columns
- Add records
- Query with order('name', 'age')
- Assert correct multi-column sorting

#### Step RQ-5: Test order() with DESC
- Query with order('name DESC')
- Assert descending order

#### Step RQ-6: Test offset() without limit
- Add records
- Query with offset(2)
- Assert skips first 2 records

### Files to Modify
- `t/orm.t` - Add ResultSet query tests

---

## Feature: Add isDSNValid() method to ORM::DB ✓ COMPLETED

### Goal
Add explicit method to validate DSN before attempting operations.

### Requirements
1. Explicit method `isDSNValid()` that users can call
2. Actually connects using `DBI->connect()` to test
3. Clean error reporting - shows `$DBI::errstr` cleanly
4. Always disconnects after testing (important for MySQL TCP)

### Implementation

#### Step 1: Add isDSNValid() to lib/ORM/DB.pm
```perl
sub isDSNValid ($self, $dsn = undef) {
    $dsn //= $self->dsn;
    
    my $username = $self->username // '';
    my $password = $self->password // '';
    my $options = $self->driver_options;
    
    my $dbh = eval {
        DBI->connect($dsn, $username, $password, $options);
    };
    
    my $error = $@;
    
    if ($dbh) {
        $dbh->disconnect;
        return wantarray ? (1, undef) : 1;
    }
    
    # Clean up error message
    $error =~ s/DBI connect failed: // if $error;
    
    return wantarray ? (0, $error) : 0;
}
```

#### Step 2: Add tests
- Test valid DSN returns true
- Test invalid DSN returns false with error
- Test error message is clean

### Files to Modify
- `lib/ORM/DB.pm` - Add isDSNValid() method
- `t/orm.t` - Add test cases

