# Bag Trap — Flow Sorter

## Project ownership
Claude builds everything. The user guides direction and corrects logic. Every line of code, every asset prompt, every design decision is Claude's responsibility unless the user overrides it.

## User role
Observer, designer, corrector. Does not write code. Approves or redirects.

## Communication rules
- Always be upfront and honest — if something isn't working or isn't known, say it directly
- Attempt solutions before asking — find tools, libraries, workarounds first; report findings, not just blockers
- If visual output can't be verified (no runtime), say so explicitly and compensate with static analysis, logic review, or by sourcing a tool that can help
- Never claim something works without evidence

## Asset pipeline
- Claude writes asset prompts (detailed, structured)
- User generates images via Grok or similar
- Claude integrates assets into the project
- Until real assets exist, all visuals are procedurally drawn in GDScript

## Tech stack
- Engine: Godot 4 (Standard build)
- Language: GDScript
- Target: Android (portrait, touch-based)
- Visual style: Premium, minimal, dark — "Apple quality"

## Game: Flow Sorter
Endless mode. Multiple vertical lanes with colored items falling. Gates at lane bottoms route items to color-matched bins. Speed and lane count scale over time. ADHD/OCD-optimized: always busy, satisfying completions, no idle states.

## Installation & tooling
- Godot lives at `C:\Users\jedin\AppData\Local\Programs\Godot\` — **never hardcode the version filename**
- Always resolve the exe dynamically: `Get-ChildItem "$env:LOCALAPPDATA\Programs\Godot" -Filter "Godot_v*.exe" | Where-Object { $_.Name -notlike "*console*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName`
- If any tool, SDK, or dependency is needed, install it automatically — do not ask for permission first
- Assume the user will approve any UAC prompt that appears
- After triggering an install, tell the user what prompt to expect so they know to approve it
- Always prefer user-level installs (AppData\Local) over system-level to minimize UAC surface

## Build approach
- Code-first: scenes created programmatically in GDScript, not in the Godot editor
- All visuals drawn via CanvasItem _draw() and shaders
- No binary assets in initial build — procedural only until Grok assets arrive

## Visual testing (self-testing protocol)
Claude cannot see the screen directly. Standard testing loop:
1. Run `& "C:\Users\jedin\Desktop\Bag Trap\tools\capture.ps1"` — this patches DebugCapture into headless mode, runs the game, takes a screenshot at 1.5s, restores the file, then exits
2. Screenshot lands at: `C:\Users\jedin\AppData\Roaming\Godot\app_userdata\Flow Sorter\debug_screenshot.png`
3. Read it with the Read tool (supports images) and inspect
4. Iterate, repeat
- DebugCapture.ENABLED is always false in the committed code — never leave it true or the user's game will auto-quit
- Always run this loop after any visual change before reporting it done
- If screenshot is blank/black, run headless with --headless flag and check error output
