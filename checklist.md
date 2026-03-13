# ORM Perl Framework - Project Checklist

## Project Overview
- **Language**: Perl
- **OO Framework**: Moo
- **Database**: SQLite3 / MariaDB
- **Testing**: Test2::Suite

---

## Completed Tasks

### Foundation & Architecture
- [x] Moo Migration - Convert all ORM modules from Mojo::Base to Moo
- [x] DSL Module Creation - Create ORM::DSL for model definitions
- [x] DSL Namespace - Rename from ORM::Model::DSL to ORM::DSL
- [x] Database Connection Refactor - Change from dbh method to db attribute
- [x] db() method caching - Add class-level caching to prevent new instances on each call

### Test Coverage
- [x] ORM::DB - attributes and methods (dbh, disconnect_all, isDSNValid)
- [x] ORM::Schema - constructor and attributes
- [x] ORM::Schema - DDL generation (ddl_for_class)
- [x] ORM::Schema - table introspection (table_exists, column_info, table_info)
- [x] ORM::Schema - table creation and migration (create_table, migrate, sync_table)
- [x] ORM::Model - CRUD operations (create, find, insert, update, delete)
- [x] ORM::Model - Error handling (EH-1 through EH-4)
- [x] ORM::Model - Auto-timestamps (AT-1 through AT-4)
- [x] ORM::Model - Relationship functions (has_many, belongs_to)
- [x] ORM::Model - Validation functions (format, length, Bool coercion)
- [x] ORM::Model - Basic attributes (column_meta, schema_name, validations)
- [x] ORM::ResultSet - Complex queries (RQ-1 through RQ-6)

### Bug Fixes
- [x] Schema.pm - Fix passing string instead of model to table_info()
- [x] DSL validates - Fix storage in wrong hash
- [x] Column setter - Fix validation lookup timing
- [x] Required validation - Fix conditional placement
- [x] BUILD hook - Add to ORM::Model for DSL column values in new()
- [x] Test assertions - Fix fragile hardcoded IDs and counts
- [x] isDSNValid() - Add explicit DSN validation method to ORM::DB

---

## In Progress

### JOIN Support
- [ ] JOIN-1: Add relationship introspection methods (has_many_relations, belongs_to_relations, related_to)
- [ ] JOIN-2: Add joins() to ResultSet
- [ ] JOIN-3: Build JOIN SQL in all() method
- [ ] JOIN-4: Tag relationships with type in DSL
- [ ] JOIN-5: Support explicit hash overrides
- [ ] JOIN-6: Add comprehensive tests

---

## Pending Tasks

### Additional Test Coverage
- [ ] Uncomment and fix remaining tests in t/orm.t (lines 52+)
- [ ] Add test models for all scenarios (Post, User, Account, Permission)
- [ ] Test model lifecycle from definition to database operations

### Future Features (Post-JOIN)
- [ ] preload() - Eager loading (2 queries, avoids N+1)
- [ ] has_one() - One-to-one relationship
- [ ] many_to_many() - Junction table relationships
- [ ] include() - JOIN + record inflation for nested objects

### Documentation
- [ ] Complete POD documentation for all modules
- [ ] Add usage examples to each module

---

## Test Status

**Current Tests: 12/12 Passing**

| Test Suite | Status |
|------------|--------|
| ORM::DB - attributes and methods | ✓ PASSING |
| ORM::Schema - constructor and attributes | ✓ PASSING |
| ORM::Schema - DDL generation | ✓ PASSING |
| ORM::Schema - table introspection | ✓ PASSING |
| ORM::Schema - table creation and migration | ✓ PASSING |
| ORM::Model - CRUD operations | ✓ PASSING |
| ORM::Model - Error handling | ✓ PASSING |
| ORM::Model - Relationship functions | ✓ PASSING |
| ORM::Model - Validation functions | ✓ PASSING |
| ORM::Model - Basic attributes | ✓ PASSING |
| ORM::Model - Complex ResultSet Queries | ✓ PASSING |
| ORM::DB - isDSNValid | ✓ PASSING |

---

## Module Status

| Module | Status | Notes |
|--------|--------|-------|
| lib/ORM/DSL.pm | ✓ WORKING | Namespace fixed, all functions export correctly |
| lib/ORM/Model.pm | ✓ WORKING | Converted to Moo, DSL functions in separate module |
| lib/ORM/DB.pm | ✓ WORKING | Converted to Moo, lazy initialization working |
| lib/ORM/ResultSet.pm | ✓ WORKING | Converted to Moo, chainable queries working |
| lib/ORM/Schema.pm | ✓ WORKING | Model discovery and migration working |

---

## Files Structure

```
lib/
├── ORM/
│   ├── DSL.pm         # Model definition DSL
│   ├── DB.pm          # Database connection
│   ├── Model.pm       # Main model class
│   ├── ResultSet.pm   # Query builder
│   └── Schema.pm      # Schema management
t/
├── orm.t              # Main test file
└── MyApp/
    ├── DB.pm          # Test database class
    └── Model/
        ├── app/
        │   └── user.pm
        └── admin/
            └── role.pm
```

---

## Next Priority

**JOIN Support Implementation**

The JOIN feature is planned but not yet implemented. See PROJECT_PLAN.md for detailed implementation steps (JOIN-1 through JOIN-6).
