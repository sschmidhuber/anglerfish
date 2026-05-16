---
label: scientific-plots
description: 'Create high-quality business and scientific plots/charts. Use when producing publication-ready figures, data visualizations, dashboards, or presentation charts. Covers chart type selection, color palettes, typography, axis labeling, layout, and accessibility. Applies to Python (Matplotlib/Seaborn/Plotly), Julia (Makie/Plots.jl), R (ggplot2), and general principles.'
argument-hint: Describe the data and the story you want the chart to tell
---

# Scientific & Business Plots

## When to Use
- Create publication-ready figures for papers, theses, or reports
- Design presentation charts that communicate clearly under time pressure
- Build dashboard panels or data-story infographics
- Ensure plots are accessible, reproducible, and style-consistent

## Chart Type Selection

Choose the chart type that best matches the data relationship:

| Relationship | Recommended Chart |
|---|---|
| Distribution (single variable) | Histogram, KDE, violin, box |
| Comparison across categories | Bar (vertical), grouped bar, lollipop |
| Part-to-whole | Stacked bar, pie (≤5 segments only), treemap |
| Trend over time | Line, area |
| Correlation (two variables) | Scatter, bubble |
| Correlation (matrix) | Heatmap |
| Rankings | Horizontal bar, slope chart |
| Uncertainty | Error bars, ribbon, confidence band |

See [chart-type guide](./references/chart-types.md) for detailed trade-offs.

## Procedure

### 1. Define the Message First
Write one sentence describing what the plot should communicate before writing code. This prevents chart-junk and over-encoding.

### 2. Choose Chart Type
Use the table above or [chart-types reference](./references/chart-types.md).

### 3. Apply Color Correctly
- Use a **perceptually uniform** sequential palette for continuous data (e.g., `viridis`, `cividis`, `Blues`).
- Use a **qualitative** palette for categorical data (≤10 colors; e.g., `tab10`, `Set2`).
- Use a **diverging** palette when data has a meaningful center (e.g., `RdBu`, `PiYG`).
- Never use rainbow/jet for scientific data.
- Ensure ≥4.5:1 contrast ratio for accessibility.
- See [color guide](./references/color-guidelines.md).

### 4. Typography & Labels
- Title: concise, sentence case, no period. Avoid restating axis labels.
- Axis labels: include **units** in parentheses, e.g., `Temperature (°C)`.
- Tick labels: no more than 6–8 ticks per axis; rotate if crowded.
- Legend: outside the plot area when possible; remove if redundant.
- Font size: title ≥14 pt, axis labels ≥12 pt, tick labels ≥10 pt.

### 5. Layout & Sizing
- **Aspect ratio**: 4:3 or 16:9 for presentations; 1:1 or golden ratio for papers.
- **Figure size**: 6×4 in at 150 dpi minimum for screen; 3.5×2.5 in at 300 dpi for print columns.
- Generous margins; avoid clipping.
- Align multiple subplots on a shared baseline.

### 6. Reduce Clutter
- Remove top and right spines (keep only bottom and left).
- Use light gray gridlines, or none.
- Avoid 3-D effects, drop shadows, gradients.
- Only include a legend if ≥2 series are plotted.

### 7. Export
- Vector formats (`SVG`, `PDF`) for print/paper.
- `PNG` at ≥150 dpi for web/slides.
- Embed fonts when using PDF.

## Quick-Reference Checklist

Use [plot-checklist asset](./assets/plot-checklist.md) before finalizing any figure.

## Code Snippets by Platform

### Python – Matplotlib
```python
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(6, 4))
ax.plot(x, y, color="#2176AE", linewidth=1.8, label="Series A")
ax.set_xlabel("Time (s)")
ax.set_ylabel("Amplitude (V)")
ax.set_title("Signal over Time")
ax.spines[["top", "right"]].set_visible(False)
ax.legend(frameon=False)
fig.tight_layout()
fig.savefig("output.pdf", dpi=300)
```

### Julia – CairoMakie
```julia
using CairoMakie

fig = Figure(size = (600, 400))
ax = Axis(fig[1,1],
    xlabel = "Time (s)", ylabel = "Amplitude (V)",
    title  = "Signal over Time",
    topspinevisible = false, rightspinevisible = false)
lines!(ax, x, y, color = "#2176AE", linewidth = 1.8, label = "Series A")
axislegend(ax, framevisible = false)
save("output.pdf", fig)
```

### R – ggplot2
```r
library(ggplot2)

ggplot(df, aes(x = time, y = amplitude, color = series)) +
  geom_line(linewidth = 0.8) +
  labs(x = "Time (s)", y = "Amplitude (V)", title = "Signal over Time") +
  theme_classic() +
  theme(legend.position = "bottom", legend.title = element_blank())
ggsave("output.pdf", width = 6, height = 4, dpi = 300)
```

## References
- [Chart type decision guide](./references/chart-types.md)
- [Color guidelines](./references/color-guidelines.md)
- [Pre-submission checklist](./assets/plot-checklist.md)
