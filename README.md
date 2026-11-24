# PathForge / ROBLOX-splines v0.3

Studio-only procedural level design toolkit. No runtime scripts or automatic uploads. Deform requires one-shot authorization to create a Roblox mesh asset.

## Development update — November 24, 2026

**v0.3 · Stability preview**

This update replaces transient mesh generation with an explicitly authorized asset-backed Deform workflow, adds transported spline frames, reuses draft guide objects, and stores control points relative to the generated model. A failed build should leave the previous map intact. Studio acceptance testing is still pending.

Next: Studio verification, continuous profile extrusion, distance-based UVs, and better viewport controls.

[Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md) · [Testing](TESTING.md)

## Install
Download `PathForge.rbxmx` from this repository, insert it into an empty Studio place, right-click the model in Explorer and Save as Local Plugin. Open Plugins > PathForge. Alternatively use Rojo 7: `rojo build -o PathForge.rbxmx`.

## Workflow
1. Add points in viewport; move, insert or edit XYZ. Set smooth/linear and placement grid.
2. Pick a built-in preset, Custom (repeat any static model), or Deform (bend one MeshPart).
3. For built-in geometry, choose a material slot, select a source BasePart in Explorer, and click Capture material. Each slot has independent base Material, MaterialVariant, color, transparency, reflectance and Decal/Texture properties including tile size. Reset restores the preset default.
4. For PBR and arbitrary imported textures, use a MeshPart with SurfaceAppearance or TextureContent. Custom repeats the original model; Deform stretches one mesh along the whole path with UVs retained and normals regenerated. No automatic subdivision or seamless UV tiling.
5. For Deform only, toggle Authorize ONE mesh upload to ON before Generate. This uploads a new mesh under your Studio account; the asset may remain after Undo or a later error. Use only assets you have permission to modify.
6. Generate/update; select the generated path and Load selected saved path to edit again. Existing v0.1/v0.2 world-space metadata can be loaded and converted on regeneration. New paths store model-local coordinates; reload after moving or externally changing a path. Undo/redo uses Studio history.

## Deform limitations (experimental)
- One static, sufficiently subdivided MeshPart, authored along local -Z; no skinning, no automatic topology subdivision, no multi-mesh deformation.
- Width/height are inherited from source Size; offset and roll are supported. Yaw and spacing do not apply to Deform.
- Uses EditableMesh and CreateAssetAsync to upload a new mesh only after explicit one-shot authorization. Local plugin installation and asset permissions are required. Save/reopen, asset moderation and ownership/access still need real Studio verification. No automatic deletion of uploaded assets.
- Sharp bends, vertical tangent transitions and sparse meshes may distort; original UV topology is preserved, so long stretches also stretch textures.
- MaterialVariant names refer to variants in the current place's MaterialService. For another place, transfer the corresponding MaterialVariant assets.
- Custom mode preserves SurfaceAppearance; face Decal/Texture slots on built-in Parts are not PBR maps. Material variants may contain PBR maps.
- No automatic terrain, scatter or extrude yet.

## Verification
Source/package parity and patch anchors were checked. Run geometry self-tests in the plugin to exercise eight tests in Studio. The tests and Studio runtime, undo, mesh persistence and visual quality have not yet been executed. See TESTING.md before using on a production map.

API references: https://create.roblox.com/docs/reference/engine/classes/EditableMesh and https://create.roblox.com/docs/reference/engine/classes/AssetService.
