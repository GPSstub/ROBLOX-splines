# PathForge / ROBLOX-splines v1.0

A Studio-only plugin that builds rails, roads, walls, fences, pipes, custom asset rows and swept meshes along splines. It also handles junctions, terrain and scatter. No runtime scripts are added to your game, and nothing is uploaded unless you turn on uploads for that Generate.

한국어: Studio 언어가 한국어면 플러그인 화면이 자동으로 한국어로 나와요. 아래 **빠른 시작**의 버튼 이름은 영어/한국어를 함께 적었어요.

[Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md) · [Studio checklist](TESTING.md) · [Release notes](RELEASE_NOTES.md)

## Install
1. Download `PathForge.rbxmx` from the latest GitHub release (or from this repository).
2. In Studio, insert it into an empty place, right-click the model in Explorer and choose **Save as Local Plugin**.
3. Open **Plugins > PathForge**.

Alternatively build it yourself: `python tools/build_rbxmx.py` (or Rojo 7: `rojo build -o PathForge.rbxmx`).

## Quick start / 빠른 시작
1. **Path / 경로**: **Add points in viewport / 뷰포트에서 점 추가**, then click on the ground. Use **Move nodes / 드래그로 노드 이동** or the XYZ fields to adjust points. **Undo draft edit / 초안 편집 취소** reverts point edits.
2. **Shape / 형태**: pick a generator (Rail, Road, Wall, Fence, Pipe, Custom, Deform, Extrude). **Add generator / 생성기 추가** stacks more generators on the same path, up to 8.
3. **Build / 빌드**: use **Preview now / 지금 미리보기** to check the result without uploading, then **Generate / 생성**. Generated models can be reloaded and updated later.

## Features
- **Generator stack**: up to 8 generators share one path. Each has its own settings, material slots, source asset and on/off switch.
- **Part generators** (Rail, Road, Wall, Fence, Pipe): straight stretches merge into single parts, and pipe joints appear only at bends.
- **Custom**: repeats any static Model or BasePart. **Repeat layers** (up to 12) add more independent rows, such as lamps or posts.
- **Extrude**: sweeps a rectangle, circle, open arch or convex custom profile, with adaptive sampling, UVs and smooth round normals. Long sweeps are split into up to 8 meshes with invisible seams.
- **Deform**: bends one static, dense MeshPart along the path.
- **Library tab**: 21 material presets, your own saved materials, an asset library and **recipes** (a whole generator stack plus layers, reusable on any path). Everything is stored in `ServerStorage > PathForgeLibrary`, so it travels with the place.
- **Branches and junctions**: snap path ends onto other paths. When two roads with junctions enabled cross or meet, they share a pad. Generate refreshes the connected road geometry in the same undo step. Bridges more than 2 studs above are ignored.
- **Terrain**: drape points onto the ground (optionally re-sampled to follow hills), then fill terrain under the path and carve terrain above it in one undo step.
- **Scatter and brush**: place assets in a band along the path with spacing, random scale and rotation, and a repeatable seed. Paint or erase them with a brush.
- **Editor**: axis move handles, grid snapping, draft undo/redo, plugin actions you can bind to keys (File > Advanced > Customize Shortcuts), red highlighting for invalid fields, Studio theme colors, and Korean/English UI.

## Mesh uploads
Extrude and Deform need a mesh asset to keep their shape after the place is saved. Turn on **Authorize mesh uploads for next Generate**, then Generate. Each enabled mesh generator uploads its mesh (or one mesh per chunk) to the place owner, or to your account in an unpublished place. Studio Undo cannot remove an upload. Previews never upload. Part-based generators are built and every mesh is planned before any upload starts, so input errors stop the build first.

## Limits
- 128 control points per path, 6,500 parts per generated model, and 60,000 vertices / 20,000 triangles per mesh chunk. Merged parts and mesh chunks fit within Roblox's 2,048-stud limit per axis.
- Custom Extrude profiles must be strictly convex. Very sharp curves can self-intersect.
- Junction pads are flat slabs. They do not blend curb shapes or road markings.
- MaterialVariants must exist in the destination place.

## Development
```
pip install lupa==2.8
python tests/run.py          # all tests (also run by GitHub Actions)
selene src                   # lint (selene 0.30)
python tools/build_rbxmx.py  # rebuild PathForge.rbxmx after editing src/
```
`tests/run.py` runs the in-Studio self-tests, the module tests in `tests/test_*.lua`, a smoke test that loads the real plugin script in a fake Studio (`tests/studio_mock.lua`) and clicks through its buttons in English and Korean, translation coverage, and a check that `PathForge.rbxmx` is up to date.

Releases: push a tag such as `v1.0.0`. The release workflow re-runs the tests and attaches `PathForge.rbxmx` to a GitHub release, using `RELEASE_NOTES.md` as the notes.

Source layout: `Plugin.server.lua` (UI wiring), `Geometry`, `Presets`, `Builder`, `Extrude`, `Deform`, `MeshOutput`, `Layers`, `Persist`, `Library`, `Network`, `Terrain`, `Scatter`, `Cache`, `DraftHistory`, `Materials`, `Assets`, `Ui`, `Json`, `Locale`, `Version`, `SelfTest`.
