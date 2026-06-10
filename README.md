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

# 2. Clone and open
git clone https://github.com/duolahypercho/gta-vi-caliber.git
cd gta-vi-caliber

# 3. Open game/ in Godot and press F5 — you're walking around the sandbox.
```

More detail in [docs/BUILDING.md](docs/BUILDING.md).

## Project status

🟢 **M0 — Bootstrap.** A playable sandbox (ground, sky, third-person character)
exists so every clone runs immediately. See [docs/ROADMAP.md](docs/ROADMAP.md)
for the milestone plan: walkable sandbox → driving + traffic → streaming city
district → missions/NPCs → trailer-grade polish.

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
