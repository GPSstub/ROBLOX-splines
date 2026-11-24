# PathForge / ROBLOX-splines v0.4

Studio-only procedural environment toolkit. No runtime scripts or automatic asset uploads.

## Development update — November 24, 2026
**v0.4 · Geometry preview**

PathForge now includes an experimental continuous profile sweep with adaptive sampling, distance-based UVs, selectable collision fidelity and a separate temporary mesh preview. Built-in presets remain available as upload-free Part generators. This release prioritizes the mesh foundation before a full editor redesign.

Next: Studio validation, live viewport preview, multi-layer splines, smoother round-profile normals and asset reuse.

[Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md) · [Testing](TESTING.md)

## Install
Download `PathForge.rbxmx`, insert into an empty Studio place, right-click the model in Explorer and Save as Local Plugin. Open Plugins > PathForge. Alternatively use Rojo 7: `rojo build -o PathForge.rbxmx`.

## Workflow
1. Add points in viewport; move, insert or edit XYZ. Set smooth/linear and grid.
2. Choose Rail/Road/Wall/Fence/Pipe (Part presets), Custom (repeat static source models), Deform (bend one static MeshPart), or Extrude (sweep a profile).
3. Capture materials from selected parts into independent slots. For Extrude choose ExtrudedMesh slot, or select a MeshPart and click Use selected MeshPart appearance / Extrude to preserve its PBR maps and texture. This copies appearance, not source geometry.
4. Extrude profiles: `rectangle`, `circle` (ellipse using width/height), `arch` (open double-sided shell, non-collidable), or ordered strictly convex custom coordinates such as `-2,-1;2,-1;2,1;-2,1` in studs. Set maximum segment length, turn angle, chord tolerance, UV length and perimeter per tile, and roll. Custom coordinates ignore width/height except validation. Rectangular and polygon corners are hard; round profiles currently have faceted cross-section normals.
5. For mesh modes click Preview mesh (no upload). Preview is a temporary non-collidable object and is dismissed on parameter/path edits. Rebuild manually to inspect changes.
6. To commit a mesh, toggle Authorize ONE mesh upload to ON, then Generate/update. The mesh is uploaded to the current place owner (or Studio user in an unpublished place); permissions and moderation may prevent it. Asset uploads cannot be undone by Studio Undo. Other modes do not upload.
7. Load selected saved path to edit again. Reload after moving or externally changing a generated path. Existing v0.1/v0.2 world-space metadata remains readable.

## Limits
- Studio runtime and upload/persistence behavior have not been tested. Use an empty test place.
- Extrude uses one mesh, limited to 60,000 vertices, 20,000 triangles and 2,000 path segments; no chunking yet. Extremely sharp curves may self-intersect; no automatic intersection repair.
- Extrude UVs use path distance and profile perimeter; rendering of texture repetition and PBR depends on the source asset. Cap UVs use planar mapping. Deform retains source UVs and still requires dense source topology; subdivision is not implemented for imported meshes.
- Open arches are visual shells, not thick tunnels. Collision for open shells is disabled. Closed meshes support selectable collision fidelity.
- MaterialVariant references must exist in the destination place. Built-in Part presets still have segmented curves.
- No automatic terrain, scatter or layered generator graph yet.

## Verification
Source and installation package parity checked. The plugin includes 13 geometry self-tests; they have not been executed in Studio. See TESTING.md for manual acceptance steps.

API references: https://create.roblox.com/docs/reference/engine/classes/EditableMesh and https://create.roblox.com/docs/reference/engine/classes/AssetService.
