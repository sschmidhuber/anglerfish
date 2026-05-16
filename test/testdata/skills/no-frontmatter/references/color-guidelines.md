# Color Guidelines for Scientific & Business Plots

## Core Principles

1. **Color encodes meaning** — use it only to distinguish data, not decorate.
2. **Limit palette** — ≤8 distinct hues for categorical data; fewer is better.
3. **Accessibility first** — ~8% of men have color vision deficiency (CVD); always verify.
4. **Consistent encoding** — same color = same category across all panels.

## Palette Types and When to Use

### Sequential (ordered, one direction)
Use for: continuous quantitative data with a natural low–high progression.

| Palette | Notes |
|---------|-------|
| `viridis` | Perceptually uniform, CVD-safe, dark-to-light |
| `cividis` | Optimized for deuteranopia, uniform brightness |
| `Blues` | Familiar, clean; poor at extremes |
| `YlOrRd` | Intuitive for intensity/heat |
| `Greys` | Print-friendly, no color encoding |

### Diverging (two directions from a center)
Use for: data with a meaningful midpoint (e.g., deviation from mean, correlation ±1, temperature anomaly).

| Palette | Notes |
|---------|-------|
| `RdBu` | Classic red–blue; CVD-risky (red–green confusion) |
| `PiYG` | Pink–green; better CVD safety |
| `BrBG` | Brown–teal; good for soil/climate data |
| `RdYlGn` | Avoid — problematic for red-green CVD |

### Qualitative (unordered categories)
Use for: nominal categorical data with no inherent order.

| Palette | Notes |
|---------|-------|
| `tab10` | Matplotlib default; 10 colors, well-spaced |
| `Set2` | Softer, 8 colors; works well in print |
| `Okabe-Ito` | Designed for CVD accessibility; 8 colors |
| `Paired` | 12 colors in light/dark pairs; for subcategories |

**Okabe-Ito hex values** (recommended default for scientific use):
```
#E69F00  Orange
#56B4E9  Sky blue
#009E73  Bluish green
#F0E442  Yellow
#0072B2  Blue
#D55E00  Vermillion
#CC79A7  Reddish purple
#000000  Black
```

## Contrast & Accessibility

- **Text on background**: minimum 4.5:1 contrast ratio (WCAG AA).
- **Adjacent data marks**: minimum 3:1 contrast ratio between neighboring colors.
- **Test tool**: [Coblis color blindness simulator](https://www.color-blindness.com/coblis-color-blindness-simulator/)
- **Quick check in Python**:
  ```python
  import matplotlib.pyplot as plt
  fig, ax = plt.subplots()
  # ... plot your chart ...
  # View in grayscale to test luminance separation:
  fig.savefig("gray_test.png", cmap="gray")
  ```

## Background & Grid Colors

| Element | Recommendation |
|---------|---------------|
| Figure background | White `#FFFFFF` or very light gray `#F5F5F5` |
| Grid lines | Light gray `#DDDDDD`, 0.5 pt, behind data |
| Axis lines | Medium gray `#888888` |
| Annotation text | Near-black `#222222` (not pure `#000000`) |

## Highlighting Technique

To draw attention to a specific data element, desaturate everything else:

```python
colors = ["#CCCCCC"] * len(series)
colors[highlight_index] = "#E63946"  # red for emphasis
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Rainbow / jet colormap | Use viridis or cividis |
| Red–green categorical encoding | Use blue–orange or Okabe-Ito |
| Too many colors (>8) | Group minor categories into "Other" |
| Color as only differentiator | Add shape or texture as secondary channel |
| Saturated colors on white background | Reduce saturation by 20–30% |
| Inconsistent color across panels | Define a shared palette dictionary |
