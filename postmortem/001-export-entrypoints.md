# Export Entry Points

## Background

`ox-slidev.el` and `org-slidev.el` both exposed public export commands.
That looked harmless until the two paths drifted:

- the backend-level `ox-slidev-export-*` commands registered the temporary
  `slidev:` link exporter
- the command-layer `org-slidev-export-*` commands did not

As a result, the documented user workflow in `README.md` and `docs/` failed for
buffers that used inline `slidev:` links, even though backend tests still
passed.

## Decision

Keep public user-facing export commands in `org-slidev.el` only.

- `org-slidev-export-to-file`
- `org-slidev-export-to-buffer`
- `org-slidev-preview`

Keep export mechanics in `ox-slidev.el`, including the temporary export context
that registers the `slidev:` link type for the Slidev backend.

The backend still exposes an Org export menu entry, but it autoloads the
command-layer export commands instead of defining a second public command set.

## Alternatives Rejected

1. Keep both command families and try to keep them behaviorally identical.

This was rejected because duplicate entry points already drifted once. The
problem was structural, not accidental.

2. Move all interactive export commands back into `ox-slidev.el`.

This was rejected because the repository design keeps `ox-slidev.el` focused on
export translation and formatting, while `org-slidev.el` owns user commands and
workflow behavior.

3. Leave the documented workflow alone and only patch broken-link handling.

This would have fixed the immediate bug but kept the duplicate public API that
caused the divergence.

## Trade-offs

- Users who were calling `ox-slidev-export-*` directly now rely on the
  command-layer entry points instead.
- The backend export menu now depends on command-layer autoloads being
  available, which is acceptable for package use and keeps the public surface
  single-sourced.

## Known Limits

- This change does not remove every large dispatcher function in the backend; it
  only fixes the export-entry-point split that caused user-visible behavior
  drift.
