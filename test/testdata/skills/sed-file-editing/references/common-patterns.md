# Sed Common Patterns Reference

## Substitution

| Goal | Command |
|------|---------|
| Replace first match per line | `s/old/new/` |
| Replace all matches per line | `s/old/new/g` |
| Case-insensitive replace (GNU) | `s/old/new/gI` |
| Replace on specific line | `5s/old/new/` |
| Replace in line range | `3,10s/old/new/g` |
| Replace after pattern match | `/marker/s/old/new/g` |

## Deletion

| Goal | Command |
|------|---------|
| Delete blank lines | `/^\s*$/d` |
| Delete lines matching pattern | `/pattern/d` |
| Delete lines NOT matching | `/pattern/!d` |
| Delete line range | `3,7d` |
| Delete from pattern to end | `/START/,$d` |
| Delete between two patterns | `/START/,/END/d` |
| Delete first line | `1d` |
| Delete last line | `$d` |

## Insertion & Appending

| Goal | Command |
|------|---------|
| Insert line before match | `/pattern/i\New line` |
| Append line after match | `/pattern/a\New line` |
| Replace entire matching line | `/pattern/c\Replacement line` |

## Whitespace

| Goal | Command |
|------|---------|
| Strip trailing whitespace | `s/[[:space:]]*$//` |
| Strip leading whitespace | `s/^[[:space:]]*//' ` |
| Strip both ends | `s/^[[:space:]]*//; s/[[:space:]]*$//` |

## Print / Extract

| Goal | Command |
|------|---------|
| Print only matching lines | `-n '/pattern/p'` |
| Print line numbers of matches | `-n '/pattern/='` |
| Print lines in range | `-n '3,7p'` |

## Alternate Delimiters

Use any character after `s` when the pattern contains `/`:

```bash
sed 's|/usr/local|/opt/local|g' file.txt
sed 's#http://example.com#https://example.org#g' file.txt
```

## Multi-line (GNU sed only)

```bash
# Join next line to current (N appends next line into pattern space)
sed 'N; s/foo\nbar/baz/' file.txt

# Process file as single string (-z, NUL-separated)
sed -z 's/old\nnew/replacement/g' file.txt
```

## Backreferences

```bash
# Wrap a word in quotes
sed 's/\(word\)/"\1"/g' file.txt

# Swap two fields separated by comma (GNU ERE with -E)
sed -E 's/^([^,]+),([^,]+)/\2,\1/' file.txt
```

## In-Place Edit Patterns

```bash
# GNU sed — edit in place, no backup
sed -i 's/foo/bar/g' file.txt

# GNU sed — edit in place with .bak backup
sed -i.bak 's/foo/bar/g' file.txt

# macOS (BSD) sed — requires explicit empty string for suffix
sed -i '' 's/foo/bar/g' file.txt

# Portable one-liner (works on both)
perl -pi -e 's/foo/bar/g' file.txt
```

## Multi-file with find

```bash
# Replace in all .txt files under current directory
find . -name '*.txt' -exec sed -i.bak 's/old/new/g' {} +

# Only files modified in the last 7 days
find . -name '*.txt' -mtime -7 -exec sed -i 's/old/new/g' {} +
```
