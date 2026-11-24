# Studio acceptance checklist (not executed)

- Install local plugin in empty baseplate and click Run geometry self-tests (15 cases).
- Generate each built-in preset and Custom, save/reopen, load and update.
- Capture two materials, including a MaterialVariant and tiled texture. Reset one slot.
- Move and rotate a generated model, reload its path, regenerate; check local coordinates. Try generating after external move/undo without reload; expect rejection.
- Verify guide instances are reused while dragging, and removed when closing the plugin or starting play.
- Deform a permitted dense static MeshPart. Generate without authorization: expect rejection and no upload. Authorize one upload, generate, check asset ID and source unchanged. Verify authorization resets.
- Save/reopen and test mesh asset access, texture/PBR, normals and collision. Test with a group-owned place and asset permissions.
- Trigger failure (invalid asset, unavailable mesh API, history unavailable); old output must remain. An already uploaded mesh may remain on Roblox even if subsequent steps fail.
- Test undo/redo and reload, v0.1/v0.2 metadata migration, missing source, sharp curves and vertical paths.
- Compare visual output against reference assets before production deployment.

## v0.4 mesh acceptance (not executed)
- Preview a straight rectangle, curved circle, open arch and custom convex polygon. Check counts, normals, caps, material and distance-based texture scale.
- Invalid polygon, excessive budgets and invalid dimensions must fail without changing saved output.
- Preview both mesh modes: no upload, no collision, removed on edit, close or play. Generate without authorization must fail.
- Upload one mesh after explicit authorization. Verify owner, asset ID, save/reopen, collision fidelity and previous output after failure.
- Confirm open arch is double-sided and non-collidable, including after upload. Test tight curves for self-intersection.

## v0.5 editor acceptance (not executed)
- Switch between four tabs, select each generator directly, verify fields and status. Move nodes with axis handles and fallback surface drag; verify grid snapping and cleanup.
- Add two repeat layers with different assets, side/height and spacing. Toggle one off, apply settings, preview, generate, save/reopen, load and regenerate.
- Confirm base + layer part budget is enforced, source snapshots preserved, missing sources reported, and disabled missing sources tolerated.
- Enable auto preview, drag a node, change a field, switch preset, close/reopen while mesh generation yields. Verify stale previews never appear and no upload occurs.
- Arm one upload with auto preview enabled: auto must stop, authorization must not be consumed by background preview; Generate must require a fresh authorization for every mesh upload.
- Inspect circle and arch normals and seams; compare cap winding, smooth sides and rectangular corners.
