---
name: foreignscan-pad-development
description: Tablet-first Flutter implementation guide for the ForeignScan project. Use when adding or refactoring screens/widgets for Pad layout, split-pane interactions, responsive behavior, large-screen usability, or tablet visual polish while preserving this codebase's Riverpod + Service architecture, AppTheme/AppConstants design tokens, and Chinese UX copy/comment style.
---

# ForeignScan Pad Development

## Purpose

Build or refactor Flutter pages for tablet-size devices in this repository without drifting from existing project conventions.
Favor practical, shippable patterns already used in `lib/screens/` and `lib/widgets/`.

## Use This Skill With

- New/updated pages that need tablet-friendly layout (`Row`/split-pane, multi-panel information density)
- Existing pages that currently work on phone but feel sparse or crowded on Pad
- Feature work that touches both UI and state/data flow (Riverpod providers + services)
- Requests that mention "Pad", "平板", "大屏", "横屏", "responsive", or "适配"

## Workflow

1. Identify scope:
   Decide whether the change belongs to `screens/` (page orchestration) or `widgets/` (reusable building blocks).
2. Load style references:
   Read [references/project-style-map.md](references/project-style-map.md) first.
3. Pick layout recipe:
   Read [references/pad-layout-recipes.md](references/pad-layout-recipes.md) and choose one recipe before coding.
4. Implement by layers:
   Keep UI in `screens/`/`widgets/`, state in `core/providers/`, side effects in `core/services/`.
5. Validate:
   Run `flutter analyze` at minimum; run impacted tests when present.

## Non-Negotiable Conventions

- Use `AppTheme` and `AppConstants` for colors, spacing, radius, and elevations. Avoid introducing new hard-coded visual tokens unless absolutely necessary.
- Keep Chinese UI copy and Chinese comments for non-obvious business/interaction logic, matching existing files.
- Preserve loading/error handling patterns using `LoadingWidget` and `ErrorWidgetCustom`.
- Keep route consistency through `AppConstants` and `AppRouter` when adding navigable pages.
- Use Riverpod providers/notifiers for state changes. Do not hide network or persistence side effects inside UI widgets.

## Tablet UI Rules

- Prefer split-pane layouts on wide screens with explicit panel roles (selector panel, detail panel, action panel).
- Maintain clear visual hierarchy using card containers, subtle shadow, rounded corners (`12`/`16`), and app-level gradient headers where appropriate.
- Keep actions explicit and close to the content they operate on (example: scene-level transfer buttons inside scene detail card).
- Avoid over-animating; keep transitions simple and meaningful (dialog progress, page transitions, hero for image preview).

## State/Data Rules

- Build async flows as "network first + local fallback" where relevant, consistent with existing detection/record services.
- Show operation result via `SnackBar` with semantic color (`success`, `warning`, `error`) from `AppTheme`.
- Keep domain mapping and API compatibility logic in services, not in widget trees.
- If Pad adaptation changes data density, prefer pagination/carousel patterns already used in `RecordsSection`.

## Delivery Checklist

Before finishing, confirm all items:

- Layout works for both phone and Pad widths (no overflow, no clipped controls)
- New UI uses project tokens and existing visual language
- State updates flow through provider/notifier instead of direct mutation in UI
- Loading/error/empty states are present
- `flutter analyze` passes

## References

- [references/project-style-map.md](references/project-style-map.md): Concrete conventions extracted from this repository.
- [references/pad-layout-recipes.md](references/pad-layout-recipes.md): Reusable tablet layout and interaction patterns.
