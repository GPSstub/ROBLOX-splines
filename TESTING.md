# Studio acceptance checklist (not executed)
- Install local plugin in empty baseplate. Create three non-collinear points, generate each preset, load and update.
- Capture two different BaseParts into RailHead and Sleeper. Verify MaterialVariant and texture tiling, save/reopen and regenerate; reset one slot.
- Repeat a MeshPart with SurfaceAppearance, and a multi-part model; verify visual properties and no copied scripts.
- Deform a subdivided straight static mesh with PBR, then generate an S-curve. Verify UVs, normals, collision, offset and roll, and source unchanged.
- Save place, close/reopen, verify opaque mesh and material maps persist. If unavailable or permissions fail, verify previous generated path is untouched.
- Undo/redo after build and regeneration; test old v0.1 path data, missing source, invalid parameters, vertical paths, and close plugin during preview.
- Compare output to straight source and reference environment before production deployment.
