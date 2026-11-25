# Changelog

## v0.9b — 2026-11-25
### Added
- Terrain section in the Path tab:
  - **Drape points onto ground** puts control points on the surface below them (plus a height offset). With a resample spacing, the path is re-sampled every N studs first so it follows hills between the original points.
  - **Fill and carve terrain along path** fills terrain under the path (to a depth, with shoulders on each side, top kept 0.5 studs below the path so voxels don't poke through roads) and clears terrain above it (to a clear height). Blocks follow the path's slope. One undo step. Fill material is selectable.
- `Terrain` module and `tests/test_v09b.lua`; the smoke test drapes a path over a hill and checks fill/carve calls.

## v0.9a — 2026-11-25
### Added
- Branches: **Snap path ends onto nearby paths** moves the first/last point of the draft onto the nearest saved PathForge path within a radius, so a side road starts exactly on the main road.
- Road junctions: when a path with a Road generator crosses (or ends on) another saved road, the road surface is cut back and one asphalt junction pad fills the crossing. The pad grows for shallow crossing angles (capped at 3× width). Paths more than 2 studs apart vertically (bridges) are ignored. Toggle in the Build tab; saved per path. Older saves keep junctions off so their output does not change.
- `Network` module (projection, snapping, crossings, pads) and `tests/test_v09a.lua`; smoke test builds two crossing roads and a snapped branch.

## v0.8 — 2026-11-25
### Added
- Library tab, stored in `ServerStorage > PathForgeLibrary` so it saves and travels with the place:
  - 21 built-in material presets (asphalt, concrete, brick, wood, rusty metal, glass, painted lines…) applied to any material slot, plus your own saved materials.
  - Asset library: add a selected model (scripts and joints stripped) and use it as a Custom asset or repeat layer. Older generation snapshots in `PathForgeAssets` are listed too.
  - Recipes: save the whole generator stack, material slots and layer settings (without points) under a name and load it onto any new path.
- Every library change is one Studio undo step.

## v0.7 — 2026-11-25
### Added
- Extrude chunking: long sweeps are split into up to 8 meshes (each within 60,000 vertices / 20,000 triangles). Chunk seams share exact positions and UVs; caps only at the two ends.
- `Cache` module: drafts reuse computed paths, and Part-based generators reuse their part list when the path and settings did not change (faster preview while editing other generators).

### Changed
- Straight stretches of beams (rail feet/heads, road surface and lines, walls, fence rails) are merged into one long part. A straight 30-stud wall is now 1 part instead of 15.
- Pipe joint balls are only placed where the pipe bends.
- Every mesh generator is planned before anything is built, so profile and budget errors appear before any upload.

## v0.6 — 2026-11-25
### Added
- Generator stack: up to 8 generators share one path, each with its own type, options, material slots, source and on/off switch. Several mesh generators (e.g. two Extrude profiles) can be built together.
- Part-based generators (Rail, Road, Wall, Fence, Pipe) now preview real geometry instead of guides only.
- Saved data format 2 (`PathData/Generators`); v0.1–v0.5 saves still load as a one-generator stack.
- Module tests (`tests/test_v06.lua`) and a fake-Studio smoke test that loads `Plugin.server.lua` and clicks through add points, preview, generate, load, update and play-test cleanup.

### Changed
- `Plugin.server.lua` split into `Presets`, `Builder`, `Persist`, `Assets`, `Ui`, `Json` and `Version` modules (generator, build and save logic moved out; the script is now UI wiring only).
- Mesh upload authorization covers every enabled mesh generator of the next Generate. Part-based generators are built before any upload.
- Material slot picker only lists slots the current generator uses.

## v0.5.1 — 2026-11-25
### Added
- Korean UI translation (`src/Locale.lua`), chosen automatically from Studio's language; English remains the default.
- `tests/run.py`: runs the geometry self-tests, regression checks, translation coverage and package parity outside Studio; GitHub Actions workflow.
- `tools/build_rbxmx.py`: rebuilds `PathForge.rbxmx` from `src/`.

### Fixed
- `G.adaptive` was defined inside `G.frame`, so Extrude could fail with a nil call on a fresh plugin load.

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
