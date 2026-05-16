---
name: d2-diagrams
description: 'Create architecture, flow, sequence, entity-relationship, and class diagrams using D2 language and the d2 CLI. Use when producing system diagrams, infrastructure maps, data flow charts, ERDs, or UML-style diagrams as code. Covers D2 syntax, layout engines, themes, and export to SVG/PNG/PDF.'
argument-hint: Describe the diagram you want to create (type, entities, relationships)
---

# D2 Diagrams

## When to Use
- Document system or service architecture
- Create data-flow or pipeline diagrams
- Produce ER diagrams for databases
- Draw sequence or class diagrams
- Generate any diagram reproducibly from code

## Prerequisites

```bash
# Install d2 (Linux/macOS via install script)
curl -fsSL https://d2lang.com/install.sh | sh

# Verify
d2 --version
```

See [installation reference](./references/installation.md) for package manager alternatives.

## Procedure

### 1. Create a `.d2` source file
```bash
touch diagram.d2
```

### 2. Write the diagram
Use D2 syntax — see [syntax reference](./references/d2-syntax.md) and [templates](./assets/templates/).

### 3. Preview (live watch mode)
```bash
d2 --watch diagram.d2 diagram.svg
```
Opens the SVG in the browser and reloads on save.

### 4. Render to file
```bash
# SVG (default, vector, best for web/docs)
d2 diagram.d2 diagram.svg

# PNG (raster, for slides/email)
d2 diagram.d2 diagram.png

# PDF
d2 diagram.d2 diagram.pdf
```

### 5. Choose a layout engine
```bash
d2 --layout elk diagram.d2 out.svg     # hierarchical, great for flowcharts
d2 --layout dagre diagram.d2 out.svg   # default, general directed graphs
d2 --layout tala diagram.d2 out.svg    # force-directed, organic layouts (paid)
```

### 6. Apply a theme
```bash
d2 --theme 200 diagram.d2 out.svg      # flagship theme
d2 --theme 101 diagram.d2 out.svg      # terminal theme
d2 --dark-theme 200 diagram.d2 out.svg # dark mode
```
List all themes: `d2 themes`

## Core Syntax Quick Reference

```d2
# Basic nodes and edges
A -> B
A -> B: label
A <-> B: bidirectional

# Shapes
server: {shape: cylinder}
decision: {shape: diamond}
user: {shape: person}

# Containers (groups)
Backend: {
  api
  db
}
Backend.api -> Backend.db

# Style
A: {
  style: {
    fill: "#E8F4F8"
    stroke: "#2176AE"
    font-size: 14
    bold: true
  }
}

# Sequence diagrams
shape: sequence_diagram
Alice -> Bob: Hello
Bob -> Alice: Hi
```

Full syntax in [d2-syntax reference](./references/d2-syntax.md).

## Templates

Ready-to-use starting points in [assets/templates/](./assets/templates/):

| Template | File |
|----------|------|
| System architecture | [architecture.d2](./assets/templates/architecture.d2) |
| Sequence diagram | [sequence.d2](./assets/templates/sequence.d2) |
| ER diagram | [erd.d2](./assets/templates/erd.d2) |

## Tips
- Use containers (`{}`) to group related nodes — D2 renders them as boxes.
- Prefer `--layout elk` for layered flowcharts and architecture diagrams.
- Keep node IDs lowercase with hyphens; use labels for display text: `my-node: Display Label`.
- Embed in Markdown: reference the rendered SVG, or use `d2` in a CI pipeline.

## References
- [Installation guide](./references/installation.md)
- [D2 language syntax](./references/d2-syntax.md)
- [Official docs](https://d2lang.com/tour/intro)
