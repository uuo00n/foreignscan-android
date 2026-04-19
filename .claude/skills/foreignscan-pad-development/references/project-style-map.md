# Project Style Map (ForeignScan)

## Tech and Architecture

- Framework: Flutter + Dart (`sdk: ^3.9.2`)
- State management: Riverpod (`Provider`, `FutureProvider`, `StateNotifierProvider`)
- Layering:
  - `lib/screens/`: page orchestration and interaction flow
  - `lib/widgets/`: reusable business widgets
  - `lib/core/providers/`: state and dependency wiring
  - `lib/core/services/`: network/local side effects and domain mapping
  - `lib/core/theme/`, `lib/config/`: design tokens, constants, routes

## UI and Visual Language

- Use `AppTheme` colors:
  - Primary deep blue + cyan accents
  - Semantic colors for success/warning/error states
- Use `AppTheme.primaryGradient` for important page headers (commonly `AppBar.flexibleSpace`)
- Prefer rounded cards (`12`/`16` radius), subtle shadow, and clean industrial visual hierarchy
- Use `AppConstants` spacing/radius/elevation where available
- Keep icon+text composite headers for sections (seen in scene selector, records, drawer groups)

## UX Interaction Patterns

- Keep clear feedback loops:
  - Loading: `LoadingWidget`
  - Error: `ErrorWidgetCustom`
  - Result: `SnackBar` with semantic background color
- Use explicit confirmation dialogs for potentially heavy actions (batch transfer, overwrite/re-transfer)
- Prefer actionable empty states ("刷新", "重试", clear cause and next action)
- Keep image-centric flows with fullscreen preview support where helpful

## Code and Naming Style

- Keep Chinese UI text and Chinese comments for business logic that is not obvious.
- Use descriptive field names and extracted private methods (`_build...`, `_fetch...`, `_handle...`).
- Keep routing consistent with `AppConstants` + `AppRouter`.
- Keep side effects and API compatibility mapping inside services, not widget trees.
- Keep `copyWith` based immutable state updates in notifiers.

## Data and Reliability Conventions

- Prefer network-first + local-cache fallback for business data.
- Persist user/server config in `SharedPreferences` for restart continuity.
- Guard async UI updates with `mounted` checks in `StatefulWidget` flows.
- Log meaningful warnings/errors for fallback branches.

## Pad-Relevant Baseline Found in Current Code

- Home and detail areas already favor multi-panel composition (`Row` + `Expanded`).
- Records section uses horizontally dense card browsing (`PageView` with `viewportFraction`).
- Scene selection favors compact grid tiles with status indicators.
- Feature pages commonly combine action panels + image panels, fitting tablet density.
