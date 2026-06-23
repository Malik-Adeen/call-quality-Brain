---
tags:
  - lessons
  - process
  - verification
---

# Verify in the Working Environment First

**Context:** Verifying a 3-line env-var change (`DIARIZE_DEVICE`) in `whisper_service.py` spiraled into hours of Dockerfile rebuilding, base-image swapping, and dependency archaeology before landing on the actually-correct test target (`Dockerfile.gpu`, not `Dockerfile.cpu`).

## The Lesson

When a verification task needs an environment fix to proceed, stop and ask:

> Does a different, already-working environment satisfy the actual goal?

If yes, use that environment. Do not debug the broken one.

`Dockerfile.cpu`'s build failure was a real, separate, pre-existing bug worth fixing eventually — but fixing it was never required for this specific verification. `Dockerfile.gpu` built successfully on Ubuntu 22.04 / FFmpeg 4.4 and was the correct test target from the start.

## The Pattern to Avoid

1. Task requires environment X to verify
2. Environment X is broken
3. Debug environment X → new error → debug again → scope expands
4. Hours pass; original task is still unverified

## The Pattern to Use

1. Task requires environment X to verify
2. Environment X is broken
3. **Ask:** does environment Y (already working) cover the same test case?
4. If yes → use Y, note X as a separate bug to fix later
5. If no → surface the blocker explicitly before spending time on the fix

## Applied Here

- `Dockerfile.cpu` broken (FFmpeg av-header compile failure)
- `Dockerfile.gpu` already confirmed building on Ubuntu 22.04
- `DIARIZE_DEVICE` is a GPU-worker concern — `Dockerfile.gpu` was the correct target anyway
- The right call was to pivot immediately, not fix `Dockerfile.cpu` first
