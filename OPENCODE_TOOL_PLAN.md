# Plan: Convert preview_pod.pl to OpenCode Tool

## Overview

Convert the standalone `scripts/preview_pod.pl` utility into a reusable OpenCode tool
that can be called from any project to preview POD documentation in plain text format.

## Current State

- **File**: `/home/jjohn/src/testProject/scripts/preview_pod.pl`
- **Type**: Standalone Perl script
- **Purpose**: Convert POD to plain text for documentation preview
- **Usable**: Only within current project

## Desired State

- **Location**: `~/.config/opencode/tools/preview-pod.ts`
- **Type**: OpenCode plugin tool (TypeScript)
- **Purpose**: Universal POD preview tool usable across all projects
- **Usable**: From anywhere via OpenCode CLI

---

## Step-by-Step Implementation Plan

### Step 1: Research OpenCode Tool Format
**Goal**: Understand how OpenCode tools work and their API

**Tasks**:
- [x] Examine existing tool: `~/.config/opencode/tools/opencode-version.ts`
- [x] Review tool structure:
  - Tool decorator and metadata
  - Arguments/parameters format
  - Return value format
  - Error handling patterns
- [x] Check OpenCode plugin documentation structure
- [ ] Document findings in comments for new tool

**Deliverable**: Understanding of tool API and patterns

**Time**: 15 minutes

---

### Step 2: Design Tool Arguments
**Goal**: Define what arguments the tool should accept

**Arguments to Design**:
- `files` (required, array of strings)
  - Glob patterns or file paths
  - Examples: `["lib/ORM/Model.pm"]`, `["lib/ORM/*.pm"]`
  - Description: "Perl module files or glob patterns to preview"

- `format` (optional, string)
  - Options: "text" (default), "json"
  - Description: "Output format"
  - Use case: JSON for programmatic processing

- `section` (optional, string)
  - Examples: "SYNOPSIS", "EXAMPLES", "METHODS"
  - Description: "Extract specific POD section"
  - Default: null (show all)

- `limit` (optional, number)
  - Default: 0 (no limit)
  - Description: "Maximum lines of output"
  - Use case: Quick preview of first N lines

**Decisions to Make**:
- Should files be required or optional?
- Should we support stdin input?
- How should errors be reported?

**Deliverable**: Documented arguments specification

**Time**: 30 minutes

---

### Step 3: Design Tool API/Interface
**Goal**: Define what the tool returns to users

**Output Format** (TypeScript interface):
```typescript
interface PreviewPodResult {
  success: boolean;
  files: {
    path: string;
    content: string;
    error?: string;
  }[];
  totalFiles: number;
  failedFiles: number;
}
```

**Error Handling**:
- File not found → Include in result with error message
- No POD found → Return empty content, not an error
- Invalid glob pattern → Return error with suggestion

**Deliverable**: Defined return interface and error handling strategy

**Time**: 20 minutes

---

### Step 4: Implement Tool - Core Logic
**Goal**: Create the TypeScript tool wrapper

**Tasks**:
- Create `~/.config/opencode/tools/preview-pod.ts`
- Import required modules:
  - `@opencode-ai/plugin` - tool decorator
  - `bun` - shell execution
  - `fs` - file system operations
  - `path` - path utilities
  - `glob` - pattern matching (if needed)
- Implement tool() decorator with:
  - description
  - args specification
  - execute() function

**Key Implementation Details**:
1. Parse `files` argument (handle glob patterns)
2. Check if files exist (report errors gracefully)
3. Call `pod2text` for each file using `bun.$`
4. Aggregate results
5. Format output according to options
6. Return structured result

**Code Structure**:
```typescript
import { tool } from "@opencode-ai/plugin"
import { $ } from "bun"
import { existsSync } from "fs"
import { resolve } from "path"

export default tool({
  description: "Preview POD documentation as plain text",
  args: {
    files: { /* ... */ },
    format: { /* ... */ },
    section: { /* ... */ },
    limit: { /* ... */ },
  },
  async execute(args, context) {
    // Implementation
  },
})
```

**Deliverable**: Working TypeScript tool file

**Time**: 60 minutes

---

### Step 5: Handle Edge Cases & Error Conditions
**Goal**: Make tool robust and user-friendly

**Edge Cases to Handle**:
1. Empty file list → Return helpful error
2. No .pm files in glob → Return empty result with message
3. pod2text command not found → Suggest installation
4. File with no POD → Return message "No POD found"
5. Permission denied → Report as error per file
6. Glob pattern that doesn't match anything → Report clearly
7. File path with spaces → Properly quote for shell

**Error Messages** (examples):
- "File not found: lib/ORM/NonExistent.pm"
- "pod2text not found - install Perl: sudo apt-get install perl-doc"
- "No files matched pattern: src/**/*.pm"

**Deliverable**: Tool with comprehensive error handling

**Time**: 45 minutes

---

### Step 6: Test Tool Locally
**Goal**: Verify tool works correctly before deploying

**Testing Scenarios**:
1. Single file: `preview-pod lib/ORM/Model.pm`
2. Multiple files: `preview-pod lib/ORM/Model.pm lib/ORM/ResultSet.pm`
3. Glob pattern: `preview-pod 'lib/ORM/*.pm'`
4. Non-existent file: `preview-pod nonexistent.pm`
5. Extract section: `preview-pod lib/ORM/ResultSet.pm --section EXAMPLES`
6. Output limit: `preview-pod lib/ORM/Model.pm --limit 50`
7. JSON format: `preview-pod lib/ORM/Model.pm --format json`

**Test Location**: `~/.config/opencode/tools/preview-pod.ts`

**Verification**:
- [ ] All test scenarios pass
- [ ] Error messages are clear
- [ ] Output is properly formatted
- [ ] Performance is acceptable (< 1 sec per file)

**Deliverable**: Test results and verified tool

**Time**: 45 minutes

---

### Step 7: Documentation
**Goal**: Document tool for users

**Documentation Locations**:
1. **Tool comment header** in `preview-pod.ts`
   - Purpose
   - Usage examples
   - Common use cases

2. **OpenCode docs** (if applicable)
   - How to use the tool
   - Argument descriptions
   - Example commands

**Documentation Content**:
```typescript
/**
 * Preview POD (Plain Old Documentation) from Perl modules as plain text.
 * 
 * This tool converts POD embedded in Perl modules to formatted text,
 * making it easy to review documentation from the command line.
 * 
 * Usage:
 *   preview-pod lib/ORM/Model.pm
 *   preview-pod 'lib/ORM/*.pm' --section EXAMPLES
 *   preview-pod lib/ORM/ResultSet.pm --limit 100
 * 
 * Requirements:
 *   - Perl installed (pod2text command available)
 *   - Pod::Text module (usually included with Perl)
 * 
 * See also:
 *   - perldoc pod2text
 *   - https://perldoc.perl.org/Pod::Text
 */
```

**Deliverable**: Well-documented tool code

**Time**: 30 minutes

---

### Step 8: Integration Testing
**Goal**: Test tool works across different projects

**Test Projects**:
1. Current project: `/home/jjohn/src/testProject`
2. Different project (if available)
3. Home directory

**Test Commands**:
```bash
# From current project
opencode preview-pod lib/ORM/*.pm

# From home directory
opencode preview-pod ~/src/testProject/lib/ORM/Model.pm

# From different project
cd /tmp && opencode preview-pod ~/src/testProject/lib/ORM/ResultSet.pm
```

**Verification**:
- [ ] Works from different directories
- [ ] File paths work both relative and absolute
- [ ] Tool accessible via opencode CLI

**Deliverable**: Verified cross-project functionality

**Time**: 30 minutes

---

### Step 9: Remove from Current Project
**Goal**: Clean up original files since tool is now global

**Tasks**:
- Remove `/home/jjohn/src/testProject/scripts/preview_pod.pl`
- Remove `/home/jjohn/src/testProject/scripts/README.md`
- Update `/home/jjohn/src/testProject/scripts/` directory (if empty, can remove)
- Git commit: "Remove preview_pod.pl - migrated to OpenCode tool"

**Rationale**:
- Single source of truth (OpenCode tools directory)
- Available to all projects
- Easier to maintain and update

**Deliverable**: Project cleaned up

**Time**: 15 minutes

---

### Step 10: Final Testing & Documentation
**Goal**: Ensure everything works as expected

**Final Tests**:
- [ ] Tool accessible via `opencode preview-pod`
- [ ] Help text available
- [ ] Works from this project
- [ ] Works from other projects
- [ ] All arguments work correctly
- [ ] Error handling is robust

**Documentation Updates**:
- [ ] Add tool usage example to project README (if exists)
- [ ] Document in OpenCode config if needed
- [ ] Create quick-reference for common use cases

**Deliverable**: Fully functional, tested, documented tool

**Time**: 30 minutes

---

## Summary Timeline

| Step | Task | Time |
|------|------|------|
| 1 | Research OpenCode Tool Format | 15 min |
| 2 | Design Tool Arguments | 30 min |
| 3 | Design Tool API/Interface | 20 min |
| 4 | Implement Tool - Core Logic | 60 min |
| 5 | Handle Edge Cases & Error Conditions | 45 min |
| 6 | Test Tool Locally | 45 min |
| 7 | Documentation | 30 min |
| 8 | Integration Testing | 30 min |
| 9 | Remove from Current Project | 15 min |
| 10 | Final Testing & Documentation | 30 min |
| **TOTAL** | | **~320 minutes (5.3 hours)** |

---

## Success Criteria

- ✅ Tool accessible from OpenCode CLI: `opencode preview-pod`
- ✅ Works with single files and glob patterns
- ✅ Supports multiple output formats (text, json)
- ✅ Can extract specific POD sections
- ✅ Robust error handling with clear messages
- ✅ Works from any directory/project
- ✅ No external dependencies beyond Perl
- ✅ Well-documented and tested
- ✅ Original project files cleaned up

---

## Questions to Answer Before Starting

1. Should `files` argument be required or optional?
2. Should we support stdin input for piping?
3. Should we add more format options (html, markdown)?
4. Should section filtering support regex patterns?
5. Should we cache results for performance?
6. Should we add a watch mode for live updates?

