---
name: sed-file-editing
description: Edit files in-place using sed (stream editor). Use when replacing text, deleting lines, inserting content, or applying regex substitutions to files. Covers single-file and multi-file edits, in-place modification with backup, and safe patterns for macOS vs GNU sed.
argument-hint: Describe the text transformation you want to apply
---

# Sed File Editing

## When to Use
- Search-and-replace text across one or many files
- Delete or insert lines matching a pattern
- Strip whitespace, comments, or empty lines
- Apply regex-based transformations non-interactively

## Key Concepts

| Concept | Notes |
|---------|-------|
| `-i` flag | In-place edit. GNU sed: `-i`. macOS sed: `-i ''` |
| `s/old/new/` | Substitute first match per line |
| `s/old/new/g` | Substitute all matches per line |
| `d` command | Delete matching lines |
| `p` command | Print (use with `-n` to suppress default output) |
| address range | `3,7d` — lines 3–7; `/start/,/end/d` — between patterns |

## Procedure

### 1. Preview Before Changing
Always dry-run first (omit `-i`):
```bash
sed 's/foo/bar/g' file.txt
```

### 2. In-Place Edit (with backup)
```bash
# GNU sed
sed -i.bak 's/foo/bar/g' file.txt

# macOS sed
sed -i '' -e 's/foo/bar/g' file.txt
```
The `.bak` suffix creates `file.txt.bak` as a safety copy.

### 3. Multi-file Edit
```bash
# All .txt files recursively
find . -name '*.txt' -exec sed -i.bak 's/foo/bar/g' {} +
```

### 4. Validate the Result
```bash
diff file.txt.bak file.txt
```
Remove backups after confirming: `find . -name '*.bak' -delete`

## Common Patterns

See [common-patterns reference](./references/common-patterns.md) for a full cheat sheet.

Quick examples:

```bash
# Delete blank lines
sed -i '/^\s*$/d' file.txt

# Delete lines containing a pattern
sed -i '/TODO/d' file.txt

# Insert a line after a match
sed -i '/^HEADER$/a\New line here' file.txt

# Replace only between two markers
sed -i '/START/,/END/s/old/new/g' file.txt

# Strip trailing whitespace
sed -i 's/[[:space:]]*$//' file.txt
```

## Gotchas
- **Delimiter conflicts**: if the pattern contains `/`, use a different delimiter: `s|/usr/local|/opt|g`
- **Greedy matching**: sed regex is greedy; use `[^/]*` style to limit scope
- **Newlines**: sed operates line-by-line; multi-line patterns require GNU sed's `-z` or `N` command
- **macOS vs GNU**: always test portability; prefer GNU sed on CI

## Assets
- [Common patterns cheat sheet](./assets/sed-cheatsheet.md)
