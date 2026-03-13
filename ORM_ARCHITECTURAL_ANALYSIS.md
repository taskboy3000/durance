# ORM Framework Architectural Analysis

## Executive Summary
Analysis of 5 core ORM modules for Single Responsibility Principle (SRP) compliance and framework requirements fulfillment.

---

## Module Analysis

### 1. ORM::DB - Database Connection Manager

**Primary Responsibility:**
- Manage database connections and pooling across the application

**Public Methods:**
- `dbh()` - Get/create database handle with pooling
- `disconnect_all()` - Disconnect all pooled handles
- `isDSNValid()` - Validate DSN without connecting

**Attributes:**
- `dsn` (lazy) - Data source name
- `username` (ro) - Database username
- `password` (ro) - Database password
- `driver_options` (lazy) - DBI connect options

**Responsibilities Count:** 2
1. Connection pooling and management
2. Connection validation

**SRP Compliance:** ✓ GOOD
- Minimal, focused responsibility
- Single purpose: manage database connections
- No business logic, no query building

**Framework Requirements Met:**
- ✓ Lightweight (minimal dependencies - just DBI)
- ✓ Convention over configuration (derived from model package names)
- ✓ Database abstraction (abstracted via DSN pattern)
- ✗ Relationship management (N/A)
- ✗ Schema introspection/migration (N/A)
- ✗ Query building (N/A)
- ✓ ORM operations support (provides dbh to models)

**Issues/Observations:**
- Global state via `%HANDLES` package variable
- Per-class pooling via hash key lookup
- No explicit driver-specific handling

---

### 2. ORM::DSL - Domain Specific Language for Model Definition

**Primary Responsibility:**
- Export functions for defining model structure (columns, relationships, validations)

**Public Functions (exported):**
- `column()` - Define a model column
- `tablename()` - Define table name
- `has_many()` - Define has-many relationship
- `belongs_to()` - Define belongs-to relationship  
- `validates()` - Define validation rules

**Responsibilities Count:** 5
1. Column metadata registration
2. Column accessor generation (setters with validation)
3. Relationship definition
4. Relationship accessor generation (has_many, belongs_to methods)
5. Validation rule registration

**SRP Compliance:** ✗ VIOLATION (5 responsibilities)
- Multiple concerns mixed in single module
- Column definition AND accessor generation
- Relationship definition AND method generation
- Validation rule storage
- These should be separated

**Framework Requirements Met:**
- ✓ Lightweight (no external dependencies)
- ✓ Convention over configuration (default foreign keys, naming)
- ✓ Relationship management (has_many, belongs_to with auto foreign keys)
- ✗ Database abstraction (N/A)
- ✗ Schema introspection/migration (N/A)
- ✗ Query building (N/A)
- ✓ ORM operations (enables model definition)

**Issues/Observations:**
- Uses global registries in ORM::Model (`%COLUMN_META`, `%_validations`, etc.)
- Tight coupling to ORM::Model package variables
- Accessor generation via symbolic references (`*{"${pkg}::${name}"}`)
- Inline validation in generated setters (length, format, required, bool coercion)
- Foreign key defaults are hardcoded (e.g., `"${parent_name}_id"`)
- Mixing concerns: DSL parsing + code generation + validation

---

### 3. ORM::Model - Base Class for ORM Models

**Primary Responsibility:**
- Provide CRUD operations and query interface for model instances

**Public Methods:**
- **Metadata Access:** `columns()`, `column_meta()`, `primary_key()`, `validations()`, `attributes()`, `table()`
- **Relationships:** `has_many_relations()`, `belongs_to_relations()`, `related_to()`, `all_relations()`
- **Lookup:** `find()`, `all()`, `where()`, `count()`, `first()`
- **Mutation:** `create()`, `insert()`, `update()`, `delete()`, `save()`
- **Utility:** `to_hash()`, `db()`, `schema_name()`, `_db_class_for()`

**Responsibilities Count:** 8
1. CRUD operations (create, read, update, delete)
2. Query interface (where, find, all, count, first)
3. Attribute/metadata access
4. Relationship access
5. Validation access
6. DB instance management
7. DB class derivation
8. Schema name extraction

**SRP Compliance:** ✗ MAJOR VIOLATION (8 responsibilities)
- Handles CRUD, queries, metadata, relationships, validation
- Mixed concerns: data access layer + metadata access + relationship management
- Should split: CRUD layer, Query layer, Metadata layer, Relationship layer

**Framework Requirements Met:**
- ✓ Convention over configuration (auto db class derivation)
- ✓ Database abstraction (queries through dbh)
- ✓ Relationship management (relationship queries)
- ✗ Schema introspection/migration (N/A - that's Schema module)
- ✓ Query building (where, limit, order chaining)
- ✓ ORM operations (full CRUD)
- ✗ Lightweight (depends on metadata system)

**Issues/Observations:**
- Massive class with many responsibilities
- Queries directly constructed in methods (no query builder)
- Hard-coded timestamps (created_at, updated_at)
- Metadata stored globally in package variables
- DB class derivation logic duplicated in Schema module
- Lazy-loading of ResultSet class
- BUILD method modifies args object
- Mix of class and instance methods

---

### 4. ORM::ResultSet - Chainable Query Interface

**Primary Responsibility:**
- Build and execute queries with chainable methods

**Public Methods:**
- **Query Building:** `where()`, `order()`, `limit()`, `offset()`, `add_joins()`
- **Execution:** `all()`, `first()`, `count()`

**Attributes:**
- `class` (ro, required) - Model class
- `conditions` (rw) - WHERE conditions
- `order_by` (rw) - ORDER BY clauses
- `limit_val` (rw) - LIMIT value
- `offset_val` (rw) - OFFSET value
- `join_specs` (rw) - JOIN specifications

**Responsibilities Count:** 3
1. Query state management (conditions, order, limit, offset, joins)
2. SQL generation
3. Query execution

**SRP Compliance:** ✗ VIOLATION (3 responsibilities)
- SQL generation and query execution mixed
- Should separate: state management from SQL builder from executor
- Current: single class doing all three

**Framework Requirements Met:**
- ✓ Lightweight (no external dependencies)
- ✓ Convention over configuration (auto joins from relationships)
- ✓ Relationship management (JOIN support via add_joins)
- ✗ Database abstraction (uses low-level SQL)
- ✗ Schema introspection/migration (N/A)
- ✓ Query building (chainable interface)
- ✓ ORM operations (executes queries)

**Issues/Observations:**
- SQL concatenation directly in code (not safe - uses placeholder bindings but still manual)
- JOIN logic complex with metadata lookup
- Duplicate WHERE clause building in `all()` and `count()`
- No query logging/verbose mode
- Large `all()` method (75+ lines)
- Error messages helpful (lists available relationships)
- Relationship metadata validated for string names only
- Execution time not tracked

---

### 5. ORM::Schema - Schema Management and Migration

**Primary Responsibility:**
- Manage database schema creation and migration based on model definitions

**Public Methods:**
- **DDL Generation:** `ddl_for_class()`
- **Table Operations:** `create_table()`, `table_exists()`, `column_info()`, `table_info()`
- **Migration:** `migrate()`, `migrate_all()`, `sync_table()`, `pending_changes()`
- **Validation:** `schema_valid()`, `ensure_schema_valid()`
- **Model Discovery:** `get_all_models_for_app()`

**Private Methods:**
- `_detect_driver()`, `_type_for()`, `_column_sql()`, `_pk_sql()`, `_build_columns_def()`, `_build_create_table_sql()`, `_get_dbh_for()`, `_db_class_for()`, `_get_app_library_basedir()`, `_wantedForModels()`

**Responsibilities Count:** 7
1. DDL generation (SQL generation for creates/alters)
2. Type mapping (ORM type → SQL type)
3. Table introspection
4. Column introspection
5. Migration logic (create vs alter)
6. Model discovery via filesystem walk
7. Schema validation

**SRP Compliance:** ✗ VIOLATION (7 responsibilities)
- Multiple concerns: DDL generation, type mapping, introspection, discovery, validation
- Should split: DDL builder, introspection layer, discovery, migration logic

**Framework Requirements Met:**
- ✓ Lightweight (uses File::Find, no external deps beyond core)
- ✓ Convention over configuration (derives DB class from model name)
- ✗ Database abstraction (works at SQL level)
- ✗ Relationship management (N/A)
- ✓ Schema introspection/migration (core feature)
- ✗ Query building (N/A)
- ✗ ORM operations (N/A)

**Issues/Observations:**
- Type mapping hardcoded for sqlite/mysql only
- Model discovery uses global `@gModelClasses` variable
- String escaping for DEFAULT values is fragile (checks for `\D`)
- VARCHAR length hardcoded to 255 for MySQL
- Auto-increment syntax varies per driver (handled well)
- No dry-run mode (framework requirement not met!)
- Logging via optional callback (good pattern)
- `chdir` + cwd restoration pattern (works but fragile)
- Duplicate db_class_for logic with Model module
- Verbose logging optional but not complete (no query timing)

---

## Architectural Summary

### Dependency Graph
```
ORM::DSL
  → ORM::Model (global registries)

ORM::Model
  → ORM::DB (for dbh)
  → ORM::ResultSet (lazy load for where())

ORM::ResultSet
  → ORM::Model (for table, primary_key, relationships)
  → ORM::DB (via Model)

ORM::Schema
  → ORM::Model (metadata queries)
  → ORM::DB (connection)
```

### SRP Violations Summary

| Module | Violations | Issues |
|--------|-----------|--------|
| ORM::DB | 0 (GOOD) | Clean separation |
| ORM::DSL | 5 | Column def, accessor gen, relationship def, accessor gen, validation |
| ORM::Model | 8 | CRUD, queries, metadata, relationships, validation, DB mgmt, class derivation, schema name |
| ORM::ResultSet | 3 | State mgmt, SQL gen, execution |
| ORM::Schema | 7 | DDL gen, type mapping, introspection, discovery, migration, validation, app discovery |

**Total SRP Violations: 23 distinct responsibilities that should be split across more focused classes**

### Framework Requirements Coverage

| Requirement | DB | DSL | Model | ResultSet | Schema |
|-------------|----|----|-------|-----------|--------|
| Lightweight | ✓ | ✓ | ✓ | ✓ | ✓ |
| Convention over Configuration | ✓ | ✓ | ✓ | ✓ | ✓ |
| Database Abstraction | ✓ | - | ✓ | - | - |
| Relationship Management | - | ✓ | ✓ | ✓ | - |
| Schema Introspection/Migration | - | - | - | - | ✓ |
| Query Building | - | - | ✓ | ✓ | - |
| ORM Operations (CRUD) | ✓ | ✓ | ✓ | ✓ | - |
| Verbose SQL Logging | ✗ | - | ✗ | ✗ | ◐ |
| Dry-run Mode | ✗ | - | ✗ | ✗ | ✗ |

**Critical Gaps:**
- ✗ No verbose SQL logging with query timing (AGENTS.md requirement)
- ✗ No dry-run mode for schema changes (AGENTS.md requirement)

### Key Architectural Issues

1. **Global Registry Pattern** - All metadata stored in package variables (%COLUMN_META, %_validations, %_has_many, %_belongs_to). Fragile and hard to test isolation.

2. **Mixed Concerns in DSL** - ORM::DSL does column definition AND accessor generation AND relationship setup. Should be at least 2-3 separate concerns.

3. **Massive Model Class** - ORM::Model is a God Object with 8+ responsibilities. Should be split into:
   - Metadata accessors
   - CRUD layer
   - Query interface (possibly delegate to ResultSet)
   - Relationship queries

4. **Query Building in Multiple Places** - SQL construction happens in Model, ResultSet, and Schema. No unified query builder.

5. **No Logging Integration** - Framework says "optional verbose logging" but it's incomplete:
   - No way to enable globally
   - Queries executed directly without timing
   - No timing capture in Model.find, Model.all, ResultSet.all

6. **Duplicated Code** - `_db_class_for()` exists in both Model and Schema. String constants for relationships repeated.

7. **Type Mapping Hardcoded** - Only supports sqlite and mysql. Adding new database requires modifying Schema.

---

## Recommendations for Refactoring

### Priority 1 (High Impact)
1. **Extract SQL Builder** - Create ORM::Query::Builder to centralize SQL generation
2. **Split ORM::Model** - Create ORM::Model::Metadata for metadata access, separate CRUD
3. **Add Logging Layer** - Integrate consistent logging with timing
4. **Implement Dry-run Mode** - Add to Schema for migration preview

### Priority 2 (Medium Impact)
1. **Separate DSL Concerns** - Column definition vs accessor generation
2. **Registry Improvement** - Consider hashref-based registry instead of package variables
3. **Type System** - Extract type mapping into ORM::Type for extensibility

### Priority 3 (Nice to Have)
1. **Query Caching** - Cache frequently used queries
2. **Lazy Relationship Loading** - Don't fetch relationships until accessed
3. **Transaction Support** - Add transaction handling

