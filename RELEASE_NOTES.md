# PathForge v1.0

PathForge is a Studio plugin that builds roads, rails, walls, fences, pipes, asset rows and swept meshes along splines.

## Highlights since v0.5
- **Generator stack** (v0.6): up to 8 generators on one path, each with its own settings and materials.
- **Faster and lighter** (v0.7): straight runs merge into single parts, long Extrude sweeps are split into chunks, and unchanged work is cached.
- **Library** (v0.8): 21 material presets, saved materials, an asset library and reusable recipes, all stored with the place.
- **Branches and junctions** (v0.9a): snap side roads onto main roads; crossings get a junction pad.
- **Terrain** (v0.9b): drape paths onto hills, then fill and carve terrain along them.
- **Scatter and brush** (v0.10): place trees, rocks and other assets along paths, or paint and erase them.
- **Editor polish** (v0.11): draft undo/redo, bindable shortcuts, field validation, Studio theme colors and a full Korean UI.

## Install
Download `PathForge.rbxmx` from this release, insert it into Studio, right-click it and choose **Save as Local Plugin**.

## Compatibility
Paths saved by v0.1–v0.5 open as a single-generator stack. Their junction setting stays off, so regenerating them does not change their output.

## Known limits
See the README's Limits section. Mesh uploads cannot be undone by Studio Undo.
