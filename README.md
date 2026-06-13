# GTA-VI-caliber

**A community-driven, fully open-source open-world game.** Our quality bar is the
fidelity shown in modern AAA open-world trailers: a dense, living coastal city
with seamless streaming, vehicles, crowds, water, and weather. Built on
[Godot 4](https://godotengine.org) with custom C++ engine modules where the
engine needs to be pushed further.

> ⚠️ This is an original, unaffiliated community project. It is **not**
> associated with Rockstar Games or Take-Two Interactive, and contains no
> assets, code, or content from any Grand Theft Auto product. "GTA-VI-caliber"
> describes our *quality benchmark*, nothing more.

## Quickstart (60 seconds)

```bash
# 1. Install Godot 4.6+ and git-lfs
brew install --cask godot && brew install git-lfs && git lfs install
#    (Linux/Windows: download Godot 4.6 from https://godotengine.org/download)

# 2. Clone
git clone https://github.com/duolahypercho/gta-vi-caliber.git
cd gta-vi-caliber

# 3. Play — boots through the branded intro to the menu, no editor needed:
godot --path game
#    — or open it in the Godot editor and press F5:
godot --path game --editor
```

The game opens on a short, skippable **intro cinematic** (press any key to skip)
and a **main menu** — press **Play** to drop into the one streaming Vice City
world, ready to walk, drive, and trigger the wanted system.

### Controls

| Input | Action |
| --- | --- |
| `WASD` | Move |
| `Shift` | Sprint |
| `Space` | Jump / brake |
| `E` | Enter / exit nearest car |
| `C` | Look behind |
| Mouse | Look around |
| `Esc` | Release mouse cursor |

More detail in [docs/BUILDING.md](docs/BUILDING.md).

## Project status

🟢 **Playable.** The game opens on a branded intro + main menu, then drops you
into a single streaming Vice City map: a third-person character, drivable
vehicles, traffic and crowds, and the core GTA loop wired end to end (commit
crimes → wanted stars → police dispatch → evade or get busted), plus missions, a
property/economy layer, and a deep, unit-tested simulation layer (heists, gangs,
drug economy, social-media fame, weather, and more — see
[docs/SYSTEMS.md](docs/SYSTEMS.md)). See [docs/ROADMAP.md](docs/ROADMAP.md) for
what's next.

## Contributing

**Everyone is welcome — programmers, 3D artists, sound designers, writers,
playtesters.** Start here:

1. Read [CONTRIBUTING.md](CONTRIBUTING.md) (5 minutes).
2. Pick a [good first issue](../../issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
   or any unchecked task in [docs/ROADMAP.md](docs/ROADMAP.md).
3. Open a PR. CI validates everything headlessly — if `tools/check.sh` passes
   locally, you're good.

AI agents are welcome contributors too: the repo contract for agents lives in
[AGENTS.md](AGENTS.md).

## Repository layout

| Path | What it is |
| --- | --- |
| `game/` | The Godot 4.6 project — scenes, scripts, assets, tests |
| `engine/` | Custom C++ engine modules (GDExtension) for performance-critical systems |
| `docs/` | Roadmap, architecture, asset policy, vision, build guide |
| `tools/` | `check.sh` (the local CI gate) and helper scripts |
| `reference/` | Local-only art-direction study footage — never committed |

## License

- **Code:** [MIT](LICENSE)
- **Assets:** [CC BY 4.0](LICENSE-ASSETS)
