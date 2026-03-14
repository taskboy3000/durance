# ORM Framework Scripts

Utility scripts for developing and documenting the ORM framework.

## preview_pod.pl

Preview POD (Plain Old Documentation) from Perl modules in plain text format.

### Usage

```bash
# View a single module
./scripts/preview_pod.pl lib/ORM/Model.pm

# View multiple modules with separators
./scripts/preview_pod.pl lib/ORM/*.pm

# Pipe to less for interactive viewing
./scripts/preview_pod.pl lib/ORM/ResultSet.pm | less

# Save to file
./scripts/preview_pod.pl lib/ORM/Model.pm > /tmp/model_docs.txt
```

### Features

- Converts POD to plain text for easy reading
- Supports single or multiple files
- Includes file separators when viewing multiple files
- Properly formatted output with indentation and line wrapping
- Can be piped to other commands (less, grep, etc.)

### Examples

Preview ORM::ResultSet documentation including JOIN examples:

```bash
./scripts/preview_pod.pl lib/ORM/ResultSet.pm | less
```

Search for "has_many" in all ORM module documentation:

```bash
./scripts/preview_pod.pl lib/ORM/*.pm | grep -A 5 "has_many"
```

View just the SYNOPSIS section of ORM::Model:

```bash
./scripts/preview_pod.pl lib/ORM/Model.pm | grep -A 20 "^SYNOPSIS"
```

Compare documentation between Model and ResultSet:

```bash
./scripts/preview_pod.pl lib/ORM/Model.pm lib/ORM/ResultSet.pm | less
```

### Implementation

The script uses Perl's built-in `Pod::Text` module to convert POD to formatted
text. No external dependencies are required beyond standard Perl modules.

### Output Format

When viewing multiple files, output includes a separator header:

```
================================================================================
File: lib/ORM/Model.pm
================================================================================

NAME
  ORM::Model - Base class for ORM models

...
```

This makes it easy to find where one module's documentation ends and another
begins.
