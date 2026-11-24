# Changelog

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
