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

## v0.6 생성기 스택 확인 (Studio, 약 10분)
- [ ] 플러그인을 새 Baseplate에 설치하고 **Run geometry self-tests** → "17 geometry tests passed" 확인
- [ ] 점 3개 찍고 **Preview now** → 레일이 실제 모양으로 보이는지(가이드 선만 보이면 실패)
- [ ] **Add generator** → **Wall** 선택 → 높이 6 → **Generate** → 모델 하나 안에 `G01_Rail`, `G02_Wall` 폴더가 생기는지
- [ ] 생성기 2를 **Generator enabled: OFF** 로 끄고 다시 Generate → 벽이 사라지는지
- [ ] 모델 선택 → **Load selected saved path** → 생성기 1/2, 설정값이 그대로 돌아오는지
- [ ] v0.5로 만든 모델이 있으면 불러와서 생성기 1개로 열리는지
- [ ] Extrude 생성기를 추가하고 업로드 허용 없이 Generate → 오류만 나고 기존 결과가 그대로인지
- [ ] Ctrl+Z 한 번에 Generate 전체가 되돌아가는지

## v0.7 최적화 확인 (Studio, 약 10분)
- [ ] 직선 경로(점 2개, 곡선: 직선 구간)에 Wall 생성 → `G01_Wall` 안의 파트가 1개인지
- [ ] ㄱ자 경로에 Road 생성 → 꺾이는 곳에 틈이나 겹침이 눈에 띄지 않는지
- [ ] Pipe를 직선에 생성 → 중간에 공(Joint)이 없고, 꺾이는 곳에만 있는지
- [ ] Extrude: 단면 circle, 분할 64, 구간 0.5, 경로 400스터드 이상 → 미리보기에 `ExtrudedMesh_01`, `_02` 여러 조각이 생기고 이음매가 안 보이는지
- [ ] 같은 조건으로 업로드 허용 후 Generate → 조각 수만큼 업로드되고 저장/다시 열기 후에도 보이는지
- [ ] 생성기 2개 있는 경로에서 2번 설정만 바꾸고 미리보기 → 1번 미리보기가 눈에 띄게 빨라졌는지 (체감)

## v0.8 라이브러리 확인 (Studio, 약 10분)
- [ ] **Library** 탭 → 재질 목록이 "1 / 21 | 아스팔트 (어두움)" 처럼 보이고 이전/다음으로 넘어가는지
- [ ] Shape 탭에서 Rail 슬롯 RailFoot 선택 → Library에서 "녹슨 금속" **현재 슬롯에 재질 적용** → Generate → 레일이 녹슨 금속인지
- [ ] 이름 칸에 "내 재질" → **현재 슬롯을 라이브러리에 저장** → 목록 끝에 ★로 나오는지, Ctrl+Z로 저장이 취소되는지
- [ ] Workspace의 가로등 모델 선택 → **선택한 모델을 라이브러리에 추가** → ServerStorage > PathForgeLibrary > Assets에 스크립트 없이 복사됐는지
- [ ] **커스텀 에셋으로 사용** / **반복 레이어로 추가** 둘 다 동작하는지
- [ ] 도로 + 벽 생성기 스택을 **레시피로 저장** → 새 경로 만들고 점 찍기 → **레시피 불러오기** → Generate → 같은 구성으로 나오는지
- [ ] 플레이스 저장 후 다시 열어도 라이브러리가 남아 있는지

## v0.9a 분기·교차로 확인 (Studio, 약 10분)
- [ ] 도로 A와 B를 직각으로 교차시켜 생성 → 두 도로가 공유하는 패드가 1개인지, A를 다시 생성해도 1개인지, 교차로를 끄면 두 도로의 절단 구간이 복원되는지 확인. Studio에서 한 번 실행 취소해 두 도로가 함께 되돌아오는지 확인
- [ ] 비스듬히(약 20°) 교차시키면 패드가 길어지는지
- [ ] A 옆 3스터드 지점에서 시작하는 길을 그리고 **경로 끝을 근처 경로에 붙이기** → 첫 점이 A 위로 이동하고 생성 시 T자 패드가 생기는지
- [ ] A 위 10스터드 높이로 지나가는 다리 경로는 교차로가 생기지 않는지
- [ ] **도로 교차로: 끔** 으로 생성 → 패드 없이 원래처럼 겹치는지, 다시 불러오면 끔 상태가 유지되는지
- [ ] v0.8 이하로 만든 도로를 불러와 다시 생성해도 모양이 바뀌지 않는지

## v0.9b 지형 확인 (Studio, 약 10분)
- [ ] Terrain 에디터로 언덕을 만든 뒤 언덕을 넘는 점 2개 → 간격 10으로 **점을 지면에 붙이기** → 점이 언덕을 따라 여러 개로 늘어나는지
- [ ] Road 생성 → **경로를 따라 지형 채우기 / 깎기** → 도로 아래는 흙이 채워지고, 도로 위로 튀어나온 지형은 깎였는지, 도로 표면 위로 지형이 비치지 않는지
- [ ] Ctrl+Z 한 번에 지형 변경이 전부 되돌아가는지
- [ ] 채울 재질을 Rock으로 바꿔서 다시 실행 → 바위로 채워지는지
- [ ] 경사진 도로에서 지형 블록이 경사를 따라가는지 (계단처럼 크게 어긋나지 않는지)

## v0.10 흩뿌리기·브러시 확인 (Studio, 약 10분)
- [ ] 나무 모델과 바위 파트를 함께 선택 → **선택한 모델들을 흩뿌릴 에셋으로 사용** → "흩뿌릴 에셋: 나무, 바위" 표시
- [ ] 도로 경로에서 **경로를 따라 흩뿌리기** → 도로 위(가운데 8스터드)에는 없고 양옆에만, 지면 높이에 맞게 놓이는지
- [ ] 같은 시드로 실행 취소 후 다시 흩뿌리면 같은 배치가 나오는지
- [ ] **브러시: 칠하기** 로 언덕 위를 끌기 → 원 안에 에셋이 생기고, 한 번 끈 것이 Ctrl+Z 한 번에 지워지는지
- [ ] **브러시: 지우기** 로 원 안 에셋만 지워지는지
- [ ] 흩뿌린 나무가 크기·방향이 조금씩 다른지, 스크립트는 복사되지 않았는지

## v0.11 UI/UX 확인 (Studio, 약 10분)
- [ ] 점 3개 찍고 **초안 편집 취소** 두 번 → 점이 1개로, **다시 실행** 으로 다시 3개가 되는지
- [ ] 노드를 끌어서 옮긴 뒤 취소 → 원래 위치로 돌아오는지
- [ ] File > Advanced > Customize Shortcuts 에서 "PathForge: 생성 / 업데이트"에 키 지정 → 키로 생성되는지
- [ ] 폭 칸에 0이나 글자를 넣으면 빨간 테두리가 생기고, 고치면 사라지는지
- [ ] Studio 테마를 Light로 바꾸고 플러그인 다시 열기 → 패널 색이 밝은 테마를 따르는지
- [ ] Studio 언어가 한국어일 때 모든 탭 글자가 한국어로 나오는지 (영어 그대로인 문구가 있으면 알려 주세요)

## v1.0 배포 전 최종 확인 (Studio, 약 20분)
배포 전에 v0.6~v0.11 목록을 한 번씩 돌린 뒤 아래를 확인해 주세요. 하나라도 실패하면 태그를 만들지 말고 알려 주세요.
- [ ] 빈 Baseplate에서 설치 → **기하 자체 테스트 실행** → "17 geometry tests passed"
- [ ] 실제 맵 한 곳에서: 도로 2개 교차 + 분기 1개 + 지형 채우기 + 양옆 나무 흩뿌리기 → 저장 → Studio 재시작 → 다시 열어 모든 모델을 **불러오기 → 생성** 했을 때 모양이 그대로인지
- [ ] 플레이 테스트 시작 시 미리보기·가이드가 모두 사라지고 게임 안에 PathForge 스크립트가 없는지
- [ ] 그룹 소유 플레이스에서 Extrude 업로드 1회 → 에셋 소유자가 그룹인지
- [ ] v0.5로 만든 예전 모델을 불러와서 다시 생성해도 모양이 같은지
- [ ] 모두 통과하면 GitHub에서 `v1.0.0` 태그를 만들면 릴리스가 자동으로 올라가요
