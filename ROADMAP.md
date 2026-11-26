# Roadmap

Each version ships with automated tests (`python tests/run.py`) and a short Studio
checklist in TESTING.md. Studio checks happen every version, not only at v1.0.

| Version | Goal | Status |
|---|---|---|
| v0.5 | Editor preview, repeat layers | done |
| v0.6 | Refactor into modules, generator stack | done |
| v0.7 | Mesh quality, caching, optimization | done |
| v0.8 | Asset and material library, recipes | done |
| v0.9a | Branching paths and intersections | done |
| v0.9b | Terrain draping, fill and carve | done |
| v0.10 | Scatter and brush placement | done |
| v0.11 | UI/UX polish | done |
| v1.0 | Stabilization, real-use validation, release | code done; Studio validation and tag pending |

No release dates are committed. Studio testing is a release blocker.

## Post-v1.0 stabilization
- [x] Terrain preview/confirmation and work limits
- [x] Recipe source snapshots and scatter part budget
- [ ] Real Studio acceptance and destructive-edit rollback checks
- [ ] Junction repair after external deletion, network spatial indexing, upload preflight and reuse
