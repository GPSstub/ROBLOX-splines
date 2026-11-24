# Changelog

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
