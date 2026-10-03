# Shanty

[![CI](https://github.com/amramos/shanty/actions/workflows/ci.yml/badge.svg)](https://github.com/amramos/shanty/actions/workflows/ci.yml)

Dialogue and short cutscenes for Godot 4, authored as typed data: every word in your translation
CSV under a stable key, the structure in `.tres` resources, a pure runner that hands back what your
game should do, a `CanvasLayer` player that presents it, and an editor tab where a writer authors
it, previews each line and plays a scene. This repository is a Godot 4.7 project built around the
addon:

- **See the demo.** Open the project and press F5: the bundled lighthouse example opens, and
  **Play the scene** plays it. The **Shanty** tab opens on the example's conversation, scene and
  trigger, and its **Play** runs the scene in a game window.
- **Install it.** Copy [`addons/shanty/`](addons/shanty/) into your project and enable the plugin. A
  release's source archive contains that folder and nothing else.
- **Learn it.** The addon's [README](addons/shanty/README.md) walks you through writing your first
  scene in the tab, then hosting it in your game; its [CHANGELOG](addons/shanty/CHANGELOG.md) says
  what each version changed.

MIT licensed — see [LICENSE](LICENSE). `addons/gut/` is [GUT](https://github.com/bitwes/Gut) 9.7.1
under its own licence, bundled for the tests only.
