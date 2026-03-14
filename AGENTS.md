# AGENTS.md - Agentic Coding Guidelines

This document provides guidelines for agents working on this codebase.

## Project Overview

- **Language**: Perl
- **OO Framework**: Moo
- **Database Access Framework**: DBI
- **Supported Database**: SQLite3 and MariaDB
- **Testing**: Test2::Suite
- **Pending and Completed Project Tasks**: PROJECT_PLAN.md

## Project Purpose
This project implements an Object Relational Mapper in Perl that has a similar workflow as Ruby on Rail's ActiveRecord ORM (https://guides.rubyonrails.org/active_record_basics.html).

* The framework should be as light-weight as possible
* It should require as few external non-core Perl modules as possible
* The framework should favor Convention of Configuration (https://en.wikipedia.org/wiki/Convention_over_configuration)
* The framework should provide optional verbose logging when making SQL queries.  The raw SQL query before the execution should be logged.  The time it takes to execute a statement needs to be logged as well
* The creation and updating of SQL tables is done through introspect of an Application's models.  That is to say the framework needs a way that given a base perl package name, it can find all of an app's models.  (This will take some designing to get right, but Durance::Schema has a good start on this)
* The documentation should be embedded in the Perl Modules as POD

## Planning Workflow

### Before Starting Any New Work
1. **Always read PROJECT_PLAN.md first** - This is the source of truth for what needs to be done
2. Check the "Pending Tasks" section to identify the next task to work on
3. Look for incomplete steps marked with `[ ]` or "IN PROGRESS" status

### Creating New Plans
- **Add new plans directly to PROJECT_PLAN.md** - Do NOT create separate files in plans/ directory
- Use the format: `## Feature: <Feature Name> ✓ PLANNED`
- Include discrete implementation steps with checkboxes `[ ]`
- Mark completed sections with `✓ COMPLETED`

### Updating Plans During Work
- As you complete steps, mark them with `✓ COMPLETED`
- Add implementation notes and code snippets
- Update the status at the top of each plan section

## Directory Structure

```
lib/
├── ORM/
│   ├── DB.pm        # Where DB credentials/data source name, other connection details are stored 
│   ├── Model.pm     # The parent class users will subclass in their models 
│   └── Schema.pm    # Schema management
t/
└── orm.t            # Test file
```

## Build/Lint/Test Commands

### Install Dependencies
```bash
cpanm --installdeps .
```

### Run All Tests
```bash
prove -l t/
perl -Ilib t/orm.t
```

### Run Single Test File
```bash
perl -Ilib t/orm.t
```

### Run Tests Verbose
```bash
perl -Ilib -MTest2::Bundle::Verbose t/orm.t
```

### Code Formatting (Perl::Tidy)
```bash
perltidy -b lib/Some/Module.pm   # Formats in place, creates .bak
perltidy -st -se lib/Some/Module.pm  # stdout output
```

### Syntax Check
```bash
perl -wc lib/ORM/Base.pm
perl -Ilib -wc lib/ORM/Model.pm
```

## Code Style Guidelines

### General Principles
- When writing perl scripts (not .pm perl modules), use this shebang line `#!/usr/bin/env perl`
- Always use `use strict;` and `use warnings;` at the top of every file
- Always use `use experimental ('signatures');` at the top of every Perl module and Perl test file
- Use Moo for OO perl  modules: `use Moo;`
- Subclasses of this framework should only need `use Moo; extends 'Durance::Model';` or `use Moo; extends 'Durance::DB';`
- If a module needs a helper function or method that does not need to be exposed to the user, those functions will start with an underscore like `_parse_dsn`.
- Take advantage of lazy initialized attributes when designing classs.  This is a core Moo feature that saves memory.
- Use attribute builders in Moo classes so that subclass can override values using `sub _build_attribute ($self) { return 'attr_value' }`
- Do not `use Carp`.  Prefer the standard perl built-ins like `warn` and `die`
- Use the Single Responsibility principle (https://en.wikipedia.org/wiki/Single-responsibility_principle)
- Make the Perl modules easily testible
- The framework should allow for a "dryrun mode" where the framework will report what SQL it would have executued or what DB changes would happen if a migration were run
- The framework should provide a single method to migrate all of an applications models
- The framework should write SQL that matches the ANSI standard as much as possible.  Exceptions to this rule include AUTO_INCREMENT for `id` columns
- Classes in the Durance:: namespace should prefer `has-a` relationships to `is-a`.  Subclasses of Durance::Model have reference to the subclasses `Durance::DB` module for that user's application.

### Naming Conventions
- **Packages/Modules**: UpperCamelCase (e.g., `Durance::Base`, `MyApp::Model::User`)
- **Methods/Subroutines**: lowerCamelCase (e.g., `createTable`, `tableExists`)
- **Attributes**: snake_case (e.g., `dbname`, `primary_key`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `COLUMN_META`)

### File Structure
```perl
package MyApp::Module;
use strict;
use warnings;
use Moo;
extends 'BaseClass';

has 'attribute_name';

sub methodName ($self, @args) {
    # implementation
}

1;
=pod

=head1 Durance::Class

...

=cut
```

### Import Style
- Use explicit import lists for modules: `use File::Temp qw(tempfile);` not `use File::Temp;`
- Group imports: core, third-party, local modules.  
- Sort each group alphabetically

### Formatting
- Use 4-space indentation (no tabs)
- Maximum line length: 100 characters
- Use perltidy for automatic formatting
- Use whitespace around operators: `$a + $b` not `$a+$b`

### Function Signatures
```perl
sub my_function ($self, $arg1, $arg2 = 'default') {
    # body
}
```

### Error Handling
- Use `die` for user-facing errors
- Use `warn` for warnings
- Use DBI's `RaiseError => 1` for database errors
- Use `//` (defined-or) not `||` for defaults

```perl
my $dbh = $self->dbh // die 'No database handle';
```

### Database Operations
- Use prepared statements with placeholders
- Always `$sth->finish;` after fetching
- Set `RaiseError => 1` in DBI connect

### Testing
- Use Test2::Suite (Test2::V0)
- Structure tests with `subtest`
- Use `dies_ok` for expected exceptions
- Use descriptive test names

```perl
use Test2::V0;

subtest 'Durance::Base - CRUD' => sub {
    my $user = MyApp::Model::User->create({ name => 'Test' });
    ok($user->id, 'id generated');
    is($user->name, 'Test', 'name set');
};
```

### Model Definition Pattern
```perl
package MyApp::Model::Entity;
use Moo;
extend 'Durance::Model';

column id         => (is => 'rw', isa => 'Int', primary_key => 1); # managed by the ORM
column name       => (is => 'rw', isa => 'Str', required => 1);
column status     => (is => 'rw', isa => 'Str', default => 'active');
column created_at => (is => 'ro', isa => 'Str'); 
column update_at  => (is => 'ro', isa => 'Str'); 

sub table { 'entities' }

1;
```

### Key Patterns
- **Global state**: Package variables with `our` (e.g., `$gDBH`)
- **Class data**: Package hashes (e.g., `%gCOLUMN_META`)
- **Method chaining**: Return `$self` from setters: `$self->name('value');`
- **Attribute accessors**: Use Moo `has`

### Testing Guidelines
- Create temporary SQLite3 databases with File::Temp
- Test success and failure cases
- Clean up resources (disconnect dbh)

### Feature Testing Preference
- **Prefer robust test coverage before adding new features**
- Complete all test coverage for a feature before starting the next feature
- This ensures changes don't break existing functionality
- Run full test suite after each change: `perl -Ilib t/orm.t`

## Documentation Guidelines

### Markdown Files
- Wrap all lines at 100 characters maximum
- This applies to intention, plan, and README files
