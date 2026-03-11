# AGENTS.md - Agentic Coding Guidelines

This document provides guidelines for agents working on this codebase.

## Project Overview

- **Language**: Perl
- **Framework**: Mojolicious, Mojo::Base
- **Database**: SQLite via DBI/DBD::SQLite
- **Testing**: Test2::Suite

## Directory Structure

```
lib/
├── ORM/
│   ├── Base.pm      # ORM base class with CRUD operations
│   ├── Model.pm     # Model metaprogramming
│   └── Schema.pm    # Schema management
└── MyApp/Model/
    └── User.pm      # Example models
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
perl -c lib/ORM/Base.pm
perl -Ilib -c lib/ORM/Model.pm
```

## Code Style Guidelines

### General Principles
- Always use `use strict;` and `use warnings;` at the top of every file
- Use Mojo::Base for OO modules: `use Mojo::Base 'BaseClass';`
- Use `-signatures` feature: `use Mojo::Base '-base', '-signatures';`

### Naming Conventions
- **Packages/Modules**: UpperCamelCase (e.g., `ORM::Base`, `MyApp::Model::User`)
- **Methods/Subroutines**: snake_case (e.g., `create_table`, `table_exists`)
- **Attributes**: snake_case (e.g., `dbname`, `primary_key`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `COLUMN_META`)

### File Structure
```perl
package MyApp::Module;
use strict;
use warnings;
use Mojo::Base 'BaseClass';
use Carp qw(croak);

has 'attribute_name';

sub method_name ($self, @args) {
    # implementation
}

1;
```

### Import Style
- Use explicit import lists: `use Carp qw(croak);` not `use Carp;`
- Group imports: core, third-party, local modules

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
- Use `croak` from Carp for user-facing errors
- Use `carp` for warnings
- Use DBI's `RaiseError => 1` for database errors
- Use `//` (defined-or) not `||` for defaults

```perl
my $dbh = $self->dbh // croak 'No database handle';
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

subtest 'ORM::Base - CRUD' => sub {
    my $user = MyApp::Model::User->create({ name => 'Test' });
    ok($user->id, 'id generated');
    is($user->name, 'Test', 'name set');
};
```

### Model Definition Pattern
```perl
package MyApp::Model::Entity;
use Mojo::Base 'ORM::Model';

column id      => (is => 'rw', isa => 'Int', primary_key => 1);
column name    => (is => 'rw', isa => 'Str', required => 1);
column status  => (is => 'rw', isa => 'Str', default => 'active');

sub table { 'entities' }

1;
```

### Key Patterns
- **Global state**: Package variables with `our` (e.g., `$gDBH`)
- **Class data**: Package hashes (e.g., `%COLUMN_META`)
- **Method chaining**: Return `$self` from setters: `$self->name('value');`
- **Attribute accessors**: Use Mojo's `has`

### Testing Guidelines
- Create temporary databases with File::Temp
- Test success and failure cases
- Clean up resources (disconnect dbh)

## Documentation Guidelines

### Markdown Files
- Wrap all lines at 100 characters maximum
- This applies to intention, plan, and README files
