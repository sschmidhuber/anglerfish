# Chart Type Decision Guide

## Decision Tree

```
What is the primary relationship in your data?
│
├── Distribution / shape of one variable
│   ├── Continuous  →  Histogram or KDE density plot
│   ├── Comparing distributions across groups
│   │   ├── ≤5 groups  →  Violin + box overlay
│   │   └── >5 groups  →  Ridgeline (joy) plot
│   └── Counts / discrete  →  Bar chart
│
├── Comparison across categories
│   ├── Few categories (≤8)
│   │   ├── One series  →  Vertical bar chart
│   │   └── Multiple series  →  Grouped bar chart
│   ├── Many categories (>8)  →  Horizontal bar (lollipop)
│   └── Ranked items  →  Slope chart or dot plot
│
├── Part-to-whole
│   ├── ≤5 parts, simple message  →  Pie or donut
│   ├── Comparing composition across groups  →  Stacked bar (100%)
│   └── Hierarchical  →  Treemap or sunburst
│
├── Trend over continuous axis (time / sequence)
│   ├── One or few series  →  Line chart
│   ├── Showing volume + trend  →  Area chart
│   └── Discrete time steps  →  Step chart
│
├── Correlation / relationship
│   ├── Two continuous variables  →  Scatter plot
│   ├── Three variables (encode size)  →  Bubble chart
│   ├── High-dimensional pairwise  →  Scatter matrix
│   └── Variable × variable grid  →  Heatmap (correlation matrix)
│
└── Spatial / geographic
    ├── Aggregated regions  →  Choropleth map
    └── Point data  →  Dot map / bubble map
```

## Chart Comparison Table

| Chart | Best for | Avoid when |
|-------|----------|------------|
| Bar | Comparing discrete categories | Too many categories (>12) |
| Grouped bar | Comparing multiple series across categories | >4 series (use small multiples) |
| Stacked bar | Showing totals AND composition | Comparing middle segments |
| Line | Trends over ordered/continuous axis | Unordered categories |
| Area | Cumulative totals, volume emphasis | Overlapping series obscure each other |
| Scatter | Correlation, outlier detection | <10 data points |
| Bubble | 3-variable correlation | Size differences hard to judge precisely |
| Histogram | Distribution shape | Already have summarized statistics |
| Box plot | Distribution summary + outliers | Audience unfamiliar with quartiles |
| Violin | Distribution shape + summary stats | Very small samples |
| Heatmap | Matrix of values, correlation grids | Sparse matrices |
| Pie | Simple part-to-whole (≤5 segments) | Comparing similar-sized segments |
| Treemap | Hierarchical part-to-whole | Deep hierarchies (>2 levels) |

## Small Multiples (Faceting)

Prefer small multiples over:
- Grouped charts with >4 series
- Dual-axis charts (misleading scale differences)
- 3-D charts (always avoid)

```python
# Matplotlib facets
fig, axes = plt.subplots(1, 3, figsize=(12, 4), sharey=True)
for ax, group in zip(axes, groups):
    ax.plot(...)
```

## Dual-Axis Warning

Dual Y-axes are almost always misleading because the visual relationship between the two series depends entirely on the chosen scale ranges. Prefer:
- Two stacked subplots with a shared X axis
- Normalizing both series to the same scale
- A scatter plot when showing their relationship directly
