# Galactic Fishing Co. — Sunlit Shallows (vertical slice)

Top-down 2D diving/fishing prototype in Godot 4.3 (GL Compatibility, web-export first).
Dave-the-Diver-style harpoon fishing on a single alien ocean, wrapped in a
cheerfully dystopian corporate-debt story.

## Run

1. Open `project.godot` in Godot 4.3+ (or run headless: `godot --headless --path .`).
2. Play `scenes/main.tscn` (the main scene).
3. Web export: standard Godot web preset; no C# or native plugins.

## Controls

| Input | Action |
|---|---|
| WASD / arrow keys | Swim |
| Mouse | Aim harpoon |
| Left click | Fire harpoon |
| E | Talk to S.H.I.P. at the ship (surface) |
| TAB | Fish catalog (collection checklist) |

## The loop

- Fish swim as **dark silhouettes** — you see shapes and sizes, not details.
- Harpoon a fish to catch it. Cargo is limited; surface to refill oxygen.
- Swim to the ship and press **E** to sell your catch to S.H.I.P. (Sales & Happiness Interface, Pal), the ship's holographic axolotl-cat AI.
- Selling converts cargo to credits and pays down your corporate debt.
- After selling, buy one-tier upgrades: bigger O2 tank, bigger cargo hold, Harpoon MK-II.
- First catch of each species triggers a **capture screen** revealing its true pixel-art form, and logs it in the catalog (TAB).
- Dive too deep and the suit warns you: `SUIT DEPTH RATING EXCEEDED` — the water darkens and pushes you back up.

## Project layout

- `scenes/main.tscn` — root scene (attaches `scripts/game.gd`)
- `scripts/` — game.gd (orchestrator), player.gd, fish.gd, harpoon.gd, hud.gd, ship.gd, catalog.gd, environment.gd, fish_data.gd
- `assets/sprites/` — generated pixel-art sprites + silhouette variants
- `assets/refs/` — approved art-mock references (diver v4, ship AI v4, fish sheet)

All sprites were generated procedurally for this prototype; the art mocks in
`assets/refs/` are the approved direction for final art.
