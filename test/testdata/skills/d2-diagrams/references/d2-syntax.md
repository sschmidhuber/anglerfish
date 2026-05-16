# D2 Language Syntax Reference

## Basic Elements

### Nodes
```d2
# Simple node (label = ID)
database

# Node with custom label
database: Users DB

# Node with shape
database: Users DB {
  shape: cylinder
}
```

### Edges
```d2
A -> B            # directed (A to B)
A <- B            # directed (B to A)
A <-> B           # bidirectional
A -- B            # undirected (no arrowhead)
A -> B: label     # edge with label
```

### Edge style
```d2
A -> B: {
  style: {
    stroke-dash: 3      # dashed line
    stroke: "#888888"
    font-size: 12
  }
}
```

## Shapes

| Value | Renders as |
|-------|-----------|
| `rectangle` | Default box |
| `square` | Square |
| `circle` | Circle |
| `oval` | Oval/ellipse |
| `diamond` | Diamond (decision) |
| `cylinder` | Database cylinder |
| `parallelogram` | Parallelogram |
| `hexagon` | Hexagon |
| `person` | Stick figure |
| `cloud` | Cloud |
| `callout` | Speech bubble |
| `queue` | Queue (open cylinder) |
| `package` | UML package |
| `step` | Rounded rectangle |
| `page` | Page with folded corner |
| `stored_data` | Stored data |
| `class` | UML class box |

```d2
api: API Gateway {shape: hexagon}
db: Postgres {shape: cylinder}
user: End User {shape: person}
```

## Containers (Groups)

Containers create nested scopes and render as bordered boxes.

```d2
# Simple container
VPC: {
  ec2
  rds: {shape: cylinder}
  ec2 -> rds: SQL
}

# Nested containers
AWS: {
  VPC: {
    ec2
    rds
  }
}

# Cross-container connections (use full path)
Client -> AWS.VPC.ec2: HTTPS
```

## Sequence Diagrams

Declared at the top level with `shape: sequence_diagram`.

```d2
shape: sequence_diagram

alice: Alice
bob: Bob
server: API Server

alice -> bob: Request token
bob -> server: Validate credentials
server -> bob: JWT token
bob -> alice: Return token

# Grouped block
alice."Step 2" -> server: POST /data {
  style.fill: "#EEF"
}
```

## Class Diagrams

```d2
shape: class_diagram

Animal: {
  +name: string
  +age: int
  +speak(): void
}

Dog: {
  +breed: string
  +fetch(): void
}

Animal -> Dog: inherits
```

## Entity-Relationship Diagrams

```d2
users: {
  shape: sql_table
  id: int {constraint: primary_key}
  email: varchar(255) {constraint: unique}
  created_at: timestamp
}

orders: {
  shape: sql_table
  id: int {constraint: primary_key}
  user_id: int {constraint: foreign_key}
  total: decimal
}

users.id -> orders.user_id
```

## Styling

### Node style properties
```d2
node: Label {
  style: {
    fill: "#E8F4F8"        # background color
    stroke: "#2176AE"       # border color
    stroke-width: 2
    stroke-dash: 0          # 0 = solid, >0 = dashed
    opacity: 0.9
    font-size: 14
    font-color: "#333333"
    bold: true
    italic: false
    underline: false
    border-radius: 6        # rounded corners
    shadow: true
    3d: false
    multiple: false         # draw stacked copies
  }
}
```

### Edge style properties
```d2
A -> B: {
  style: {
    stroke: "#E63946"
    stroke-width: 2
    stroke-dash: 4
    font-size: 12
    font-color: "#555"
    animated: true          # animated flow arrow
    filled: true            # filled arrowhead
  }
}
```

## Variables (D2 vars)

```d2
vars: {
  d2-config: {
    theme-id: 200
    layout-engine: elk
  }
}
```

## Comments

```d2
# This is a comment
```

## Special Characters in IDs

Wrap IDs containing spaces or special characters in quotes:

```d2
"My Service" -> "Other Service": HTTP
```

## Multiple Files (imports)

```d2
...@./shared-nodes.d2
```

## Layout Engine Notes

| Engine | Best for |
|--------|---------|
| `dagre` | General directed graphs (default) |
| `elk` | Hierarchical flowcharts, architecture |
| `tala` | Complex organic layouts (requires license) |

Use `--layout` flag on the CLI or `vars.d2-config.layout-engine` in the file.
