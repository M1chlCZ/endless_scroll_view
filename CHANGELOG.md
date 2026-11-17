# Changelog

## [0.2.0] - 2026-11-17

- Add `onRefresh`: the list and the empty state become pull-to-refresh
  capable when it is set.
- Add `placeholderItemBuilder` and `placeholderCount`: the first load can
  show placeholder rows instead of the empty state.
- Add `controller`: pass a `ScrollController` to add a scroll-to-top button.
  The widget attaches its near-end listener to the provided controller.

## 0.1.0

- Initial release. Extracted from a homework app and modernized:
  - `EndlessScrollView` with a configurable near-end threshold.
  - Loading, error (with retry) and end-of-list footers.
  - Empty state builder and separator support.
  - Automatic next-page load when the content does not fill the viewport.
  - A Riverpod example app.
