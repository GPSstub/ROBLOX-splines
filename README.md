# PathForge / ROBLOX-splines v0.7

Studio-only procedural environment toolkit. No runtime scripts or automatic asset uploads.

## Development update — November 25, 2026
**v0.6 · Refactor and generator stack**

One path can now carry up to 8 generators (for example Road + Wall + Fence, or two Extrude sweeps), each with its own settings, material slots and source. The plugin script was split into modules, and Part-based generators now preview real geometry. A fake-Studio smoke test clicks through the plugin UI on every CI run. Studio acceptance testing is still pending.

[Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md) · [Testing](TESTING.md)

## Install
Download `PathForge.rbxmx`, insert into an empty Studio place, right-click the model in Explorer and Save as Local Plugin. Open Plugins > PathForge. Alternatively use Rojo 7: `rojo build -o PathForge.rbxmx`.

The editor UI follows Studio's language: Korean (한국어) when Studio is set to Korean, English otherwise. Translations live in `src/Locale.lua`.

## Workflow
1. Path tab: add points in viewport; move, insert or edit XYZ. In Move mode, use axis handles if supported or surface dragging. Set smooth/linear and grid. Shape tab: select the base generator and material.
2. Choose Rail/Road/Wall/Fence/Pipe (Part presets), Custom (repeat static source models), Deform (bend one static MeshPart), or Extrude (sweep a profile). Use Add generator to stack more generators on the same path (max 8); Previous/Next generator switches which one the fields edit. Each generator can be disabled without deleting it.
3. Capture materials from selected parts into independent slots. For Extrude choose ExtrudedMesh slot, or select a MeshPart and click Use selected MeshPart appearance / Extrude to preserve its PBR maps and texture. This copies appearance, not source geometry.
4. Extrude profiles: `rectangle`, `circle` (ellipse using width/height), `arch` (open double-sided shell, non-collidable), or ordered strictly convex custom coordinates such as `-2,-1;2,-1;2,1;-2,1` in studs. Set maximum segment length, turn angle, chord tolerance, UV length and perimeter per tile, and roll. Custom coordinates ignore width/height except validation. Rectangular and polygon corners are hard; round profiles use smooth cross-section normals.
5. Layers tab: select any static source model in Explorer, Add selected model as repeat layer, set spacing, local side/height, yaw, roll, collision, and Apply layer settings. Add multiple independent overlays (up to 12). Disabled layers do not generate.
6. Build tab: Preview now or enable Auto preview (debounced by 0.35 seconds, after dragging stops). Every generator and repeat layer previews without upload (3,000 parts for generators, 1,000 for layers).
7. To commit meshes, toggle Authorize mesh uploads for next Generate to ON, then Generate/update. Each enabled Extrude/Deform generator uploads one mesh; Part-based generators are built first so a budget error stops before any upload. The mesh is uploaded to the current place owner (or Studio user in an unpublished place); permissions and moderation may prevent it. Asset uploads cannot be undone by Studio Undo. Other modes do not upload.
8. Load selected saved path to edit again. Reload after moving or externally changing a generated path. Existing v0.1/v0.2 world-space metadata remains readable.

## Limits
- Studio runtime and upload/persistence behavior have not been tested. Use an empty test place.
- Extrude splits long sweeps into up to 8 meshes of at most 60,000 vertices and 20,000 triangles each; every chunk is a separate upload. Extremely sharp curves may self-intersect; no automatic intersection repair.
- Extrude UVs use path distance and profile perimeter; rendering of texture repetition and PBR depends on the source asset. Cap UVs use planar mapping. Deform retains source UVs and still requires dense source topology; subdivision is not implemented for imported meshes.
- Open arches are visual shells, not thick tunnels. Collision for open shells is disabled. Closed meshes support selectable collision fidelity.
- MaterialVariant references must exist in the destination place. Built-in Part presets still have segmented curves.
- Terrain, scatter, branching and caching are not implemented yet (see ROADMAP.md).

## Verification
Run `pip install lupa==2.8` then `python tests/run.py` to execute the Studio self-tests, module tests (`tests/test_*.lua`), a plugin UI smoke test in a fake Studio (`tests/studio_mock.lua`), translation and package checks outside Studio (also run by GitHub Actions). Static analysis of every script, including `Plugin.server.lua`, uses selene 0.30 (`selene src`, config in `selene.toml` / `roblox_globals.yml`). After editing `src/`, rebuild the package with `python tools/build_rbxmx.py`. Studio UI behaviour is still untested; see TESTING.md for manual acceptance steps.

API references: https://create.roblox.com/docs/reference/engine/classes/EditableMesh and https://create.roblox.com/docs/reference/engine/classes/AssetService.
