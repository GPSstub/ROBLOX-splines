# PathForge / ROBLOX-splines v0.2

Studio-only procedural level design toolkit. No runtime scripts, HTTP requests, or automatic asset uploads.

## Development update — November 24, 2026

**v0.2 · Early development**

PathForge is evolving from a spline-based preset generator into a general-purpose environment toolkit. This update adds user-defined material slots and experimental mesh bending, so creators can build with their own assets rather than rely on preset materials.

Next up: Studio stability testing, continuous mesh extrusion, improved UV mapping, and a reusable asset library. The goal is to make building roads, tunnels, walls, pipes and other environments faster without sacrificing visual quality.

[Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md) · [Testing](TESTING.md)

## Install
Download `PathForge.rbxmx` from this repository, insert it into an empty Studio place, right-click the model in Explorer and Save as Local Plugin. Open Plugins > PathForge. Alternatively use Rojo 7: `rojo build -o PathForge.rbxmx`.

## Workflow
1. Add points in viewport; move, insert or edit XYZ. Set smooth/linear and placement grid.
2. Pick a built-in preset, Custom (repeat any static model), or Deform (bend one MeshPart).
3. For built-in geometry, choose a material slot, select a source BasePart in Explorer, and click Capture material. Each slot has independent base Material, MaterialVariant, color, transparency, reflectance and Decal/Texture properties including tile size. Reset restores the preset default.
4. For PBR and arbitrary imported textures, use a MeshPart with SurfaceAppearance or TextureContent. Custom repeats the original model; Deform stretches one mesh along the whole path with UVs retained and normals regenerated. No automatic subdivision or seamless UV tiling.
5. Generate/update; select the generated path and Load selected saved path to edit again. Existing v0.1 metadata is compatible. Undo/redo uses Studio history.

## Deform limitations (experimental)
- One static, sufficiently subdivided MeshPart, authored along local -Z; no skinning, no automatic topology subdivision, no multi-mesh deformation.
- Width/height are inherited from source Size; offset and roll are supported. Yaw and spacing do not apply to Deform.
- Uses EditableMesh and CreateDataModelContentAsync to bake place-local opaque content, not an uploaded mesh asset. API availability, asset permissions and Studio save/reopen must be checked on the actual target Studio build.
- Sharp bends, vertical tangent transitions and sparse meshes may distort; original UV topology is preserved, so long stretches also stretch textures.
- MaterialVariant names refer to variants in the current place's MaterialService. For another place, transfer the corresponding MaterialVariant assets.
- Custom mode preserves SurfaceAppearance; face Decal/Texture slots on built-in Parts are not PBR maps. Material variants may contain PBR maps.
- No automatic terrain, scatter or extrude yet.

## Verification
Source patches were checked for expected anchors, package/source parity and feature integration; Studio runtime, undo, mesh persistence and visual quality have not been verified. See TESTING.md before using on a production map.

API references: https://create.roblox.com/docs/reference/engine/classes/EditableMesh and https://create.roblox.com/docs/reference/engine/classes/AssetService.
