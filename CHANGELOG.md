# Changelog

## v0.5 — 2026-11-24
### Added
- Up to 12 repeat layers on one path, with independent asset, spacing, lateral/vertical offset, rotation, enabled and collision settings.
- Layer metadata and source snapshots stored with existing path data; deduplicated within each generation.
- Four editor tabs and direct generator selection.
- Optional axis movement handles, with existing surface-drag fallback.
- Debounced automatic, non-uploading mesh and layer previews after dragging stops; stale results discarded.
- Smooth circular and arch cross-section normals.
- Two additional self-test cases (15 total; Studio execution pending).

### Limitations
- One base generator plus repeat overlays, not a full multi-mesh graph.
- Preview of Part-based and Custom base generators is still guide-only.
- Studio UI, handles, collision, preview and asset persistence require acceptance testing.

## v0.4 — 2026-11-24
### Added
- Continuous Extrude generator with rectangle, circle, open arch and convex custom profile.
- Adaptive path sampling with turn angle and chord error settings.
- Distance-based side UVs, cap UVs, shared ring vertices and explicit normal seams.
- Temporary, upload-free mesh preview for Extrude and Deform.
- Mesh collision fidelity selector and explicit asset owner parameters.
- Five additional geometry self-tests (13 total, not executed in Studio).

### Known limitations
- Manual preview refresh; no live mesh dragging yet.
- Imported mesh subdivision, round-profile normal smoothing, chunking, and caching remain pending.
- Studio runtime, UV appearance, collision and asset persistence remain unverified.

## v0.3 — 2026-11-24

### Changed
- Deform requires one-shot explicit authorization and creates an asset-backed mesh rather than ephemeral content.
- Parallel-transport spline frames reduce orientation flips near vertical tangents.
- Draft guide and node instances are reused during edits.
- New path metadata stores model-local control points; old world-space metadata remains readable.
- Build staging, stale-target checks and cleanup protect previous output during errors.
- Added an eight-case in-Studio geometry self-test command (not yet executed).

### Known issues
- Asset uploads require a local plugin and appropriate permissions; moderation/access and save/reopen are unverified. Undo cannot undo the upload itself.
- Continuous extrusion, adaptive subdivision and UV tiling remain pending.

## v0.2 — 2026-11-24

### Added
- Per-component material slots with custom MaterialVariant, colors and tiled textures.
- Experimental EditableMesh deformation for a single static MeshPart, retaining UVs and source PBR appearance.
- Material settings persisted with path metadata.
- Rojo project and local-plugin installation package.

### Known issues
- Deformation requires sufficient mesh subdivision and appropriate asset permissions.
- UV stretching and sharp-curve distortion are not fully addressed.
- Studio execution, collision and save/reopen persistence still need validation.

## v0.1 — Initial prototype
- Spline control points, placement grid and saved paths.
- Rail, road, wall, fence and pipe presets.
- Custom model repetition and Studio undo integration.
