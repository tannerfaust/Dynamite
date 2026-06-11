# Dynamite Performance Baseline

> Track this over time. Re-run after significant architectural changes. All timings are wall-clock,
> debug build (`Dynamite.app` from `.derivedData/Build/Products/Debug/`), Apple Silicon, unless noted.

## Baseline — 2026-06-10 (debug build)

| Metric | Median | Range | Build | Method |
|---|---|---|---|---|
| Cold launch (process → welcome window idle) | 2.4 s | 2.35 – 2.48 s | Debug | `open -n Dynamite.app`; wall-clock until process CPU idles. 3 runs. |
| Workspace open (folder selected → file tree visible) | TBD | — | Debug | See method below |
| File open (click in tree → first render in editor) | TBD | — | Debug | See method below |
| Search (⌘⇧F → first results rendered) | TBD | — | Debug | See method below |

## Measurement methods

### Cold launch
```bash
APP=".derivedData/Build/Products/Debug/Dynamite.app"
pkill -x Dynamite; sleep 1.2
START=$(python3 -c "import time; print(time.time())")
open -n "$APP"
sleep 2.5   # adjust until app is idle; watch Activity Monitor CPU
END=$(python3 -c "import time; print(time.time())")
python3 -c "print(round($END - $START, 2))"
```
Run 3+ times; discard first (OS disk cache cold). Record median.

### Workspace open
1. Launch Dynamite (warm — welcome window showing).
2. Start a stopwatch.
3. Drop a medium-sized repo (~1 000 files, e.g. this repo) onto the welcome window.
4. Stop when the project navigator shows the full top-level file list.

Record median of 3 runs. Re-run with a large repo (~10 000 files) to check scaling.

### File open
1. Open the Dynamite repo workspace (warm workspace, tree already loaded).
2. Start stopwatch.
3. Click `CodeEdit/CodeEditApp.swift` in the navigator (a ~70-line Swift file).
4. Stop when the editor content is fully visible and cursor is ready.

Record median of 3 clicks (alternate between two files to avoid caching effects).

### Search (find in files)
1. Open the Dynamite repo workspace.
2. Press ⌘⇧F to open the Find Navigator.
3. Start stopwatch when first keystroke lands in the search field.
4. Type `WorkspaceDocument` (19 chars, ~40 expected hits in this repo).
5. Stop when the result list stops updating.

Record median of 3 searches (clear field between runs).

## Regression thresholds (suggested)

| Metric | Warning | Block |
|---|---|---|
| Cold launch | > 3 s (debug) | > 2 s (release) |
| Workspace open | > 1.5 s | > 3 s |
| File open | > 300 ms | > 800 ms |
| Search | > 500 ms | > 1.5 s |

> Release build targets are not yet measured. Fill in after a release build is available.
