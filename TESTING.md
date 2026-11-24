# Studio acceptance checklist (not executed)

- Install local plugin in empty baseplate and click Run geometry self-tests (8 cases).
- Generate each built-in preset and Custom, save/reopen, load and update.
- Capture two materials, including a MaterialVariant and tiled texture. Reset one slot.
- Move and rotate a generated model, reload its path, regenerate; check local coordinates. Try generating after external move/undo without reload; expect rejection.
- Verify guide instances are reused while dragging, and removed when closing the plugin or starting play.
- Deform a permitted dense static MeshPart. Generate without authorization: expect rejection and no upload. Authorize one upload, generate, check asset ID and source unchanged. Verify authorization resets.
- Save/reopen and test mesh asset access, texture/PBR, normals and collision. Test with a group-owned place and asset permissions.
- Trigger failure (invalid asset, unavailable mesh API, history unavailable); old output must remain. An already uploaded mesh may remain on Roblox even if subsequent steps fail.
- Test undo/redo and reload, v0.1/v0.2 metadata migration, missing source, sharp curves and vertical paths.
- Compare visual output against reference assets before production deployment.
