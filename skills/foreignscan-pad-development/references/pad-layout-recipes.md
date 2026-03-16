# Pad Layout Recipes (Flutter)

## Breakpoint Strategy

Use width-based breakpoints with `LayoutBuilder` or `MediaQuery`:

- `compact` (`< 900`): phone-like vertical stacking
- `medium` (`900-1279`): tablet portrait split layout
- `expanded` (`>= 1280`): tablet landscape with stronger multi-panel density

Avoid one-size-fits-all hardcoded dimensions for all devices.

## Recipe 1: Selector + Detail Split

Use for pages similar to Home scene operations.

- Left panel: fixed or clamped width for selector/navigation (`260-320`)
- Right panel: `Expanded` detail/action workspace
- Keep panel spacing stable (`12-20`)

Implementation direction:

1. Keep selector as reusable widget in `lib/widgets/`
2. Keep page-level selection state in provider/notifier
3. Use same section title treatment (icon + title + subtle meta text)

## Recipe 2: Dual Image Comparison Panel

Use for inspection/verification details.

- `compact`: stack images vertically
- `medium`/`expanded`: show side-by-side `Expanded` panels
- Keep identical visual frame style for both images for quick visual comparison

Implementation direction:

1. Extract shared image panel builder
2. Keep image source resolution logic (network/local fallback) outside main build body when possible
3. Keep fullscreen preview entry points consistent

## Recipe 3: Dense Record Browsing

Use for review history on Pad.

- Prefer horizontal browsing (`PageView`, controlled `viewportFraction`)
- Keep concise metadata chip rows (status + time + scene)
- Use card size that preserves readability while keeping multiple cards visible

Implementation direction:

1. Keep status mapping centralized (label/color/icon)
2. Keep tap target large enough for touch (`>= 44dp`)
3. Avoid text overflow by limiting lines and using ellipsis

## Recipe 4: Adaptive Action Bar

Use for pages with multiple primary/secondary actions.

- `compact`: vertical button stack or wrapped row
- `medium`/`expanded`: right-aligned horizontal action row
- Keep primary action visually dominant, secondary actions differentiated by color semantics

Implementation direction:

1. Define a shared button style for same-height controls
2. Keep destructive/risky actions behind confirmation dialogs
3. Keep action labels explicit in Chinese business wording

## Minimal Skeleton

```dart
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final isCompact = w < 900;
      final isExpanded = w >= 1280;

      if (isCompact) {
        return _buildCompactLayout(context);
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isExpanded ? 300 : 260,
            child: _buildSelectorPanel(context),
          ),
          const SizedBox(width: 16),
          Expanded(child: _buildDetailPanel(context)),
        ],
      );
    },
  );
}
```

## Validation Checklist

- No `RenderFlex overflow` in portrait/landscape Pad and phone
- No clipped dialogs/buttons on small widths
- Interactive elements remain reachable with one hand in landscape
- `flutter analyze` passes after refactor
