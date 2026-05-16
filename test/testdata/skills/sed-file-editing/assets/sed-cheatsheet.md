# Sed Quick-Reference Cheat Sheet

```
┌─────────────────────────────────────────────────────────────────┐
│                      SED CHEAT SHEET                            │
├──────────────┬──────────────────────────────────────────────────┤
│ SYNTAX       │  sed [OPTIONS] 'SCRIPT' [FILE...]                │
├──────────────┼──────────────────────────────────────────────────┤
│ OPTIONS      │  -n   suppress auto-print                        │
│              │  -i   in-place edit (GNU); -i '' (macOS)         │
│              │  -E   extended regex (ERE)                       │
│              │  -e   add script expression                      │
│              │  -f   read script from file                      │
├──────────────┼──────────────────────────────────────────────────┤
│ ADDRESSES    │  N        line number                            │
│              │  $        last line                              │
│              │  /regex/  matching lines                         │
│              │  N,M      line range                             │
│              │  /a/,/b/  pattern range (inclusive)              │
│              │  addr!    negate address                         │
├──────────────┼──────────────────────────────────────────────────┤
│ COMMANDS     │  s/re/rep/[flags]  substitute                    │
│              │  d                 delete                        │
│              │  p                 print                         │
│              │  =                 print line number             │
│              │  q                 quit                          │
│              │  a\text            append after                  │
│              │  i\text            insert before                 │
│              │  c\text            replace line                  │
│              │  y/abc/xyz/        transliterate                 │
│              │  N                 append next line              │
│              │  D                 delete first line in space    │
│              │  P                 print first line in space     │
│              │  r file            read file                     │
│              │  w file            write to file                 │
├──────────────┼──────────────────────────────────────────────────┤
│ s/ FLAGS     │  g  all occurrences                              │
│              │  I  case-insensitive (GNU)                       │
│              │  N  Nth occurrence                               │
│              │  p  print if substitution made                   │
│              │  w  write to file if substitution made           │
├──────────────┼──────────────────────────────────────────────────┤
│ BACKREFS     │  \1 … \9   in BRE (default)                     │
│              │  \1 … \9   in ERE (-E flag)                     │
│              │  &         entire match                          │
└──────────────┴──────────────────────────────────────────────────┘
```

## Most-Used One-Liners

```bash
sed 's/foo/bar/g'                 # replace all "foo" with "bar"
sed '/pattern/d'                  # delete lines matching pattern
sed -n '/pattern/p'               # print only matching lines
sed '1d'                          # delete first line (header)
sed '$d'                          # delete last line
sed 's/^/    /'                   # indent every line by 4 spaces
sed 's/[[:space:]]*$//'           # strip trailing whitespace
sed '/^\s*$/d'                    # remove blank lines
sed -n '10,20p'                   # print lines 10–20
sed '10,20d'                      # delete lines 10–20
sed 's/.*/"&"/'                   # quote entire line
sed -E 's/^(\w+)\s+(\w+)/\2 \1/' # swap first two words
```
