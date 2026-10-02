# Shanty

Dialogue and short cutscenes for Godot 4, authored as typed data: text in your translation
catalogue under stable keys, structure in `.tres` resources, a pure runner that hands back what your
game should do, and a `CanvasLayer` player that presents it.

**The addon is [`addons/shanty/`](addons/shanty/) — read its [README](addons/shanty/README.md)** for
installation, how to run the bundled lighthouse example and then build it again yourself, and the
host contract. What changed in each version is in its [CHANGELOG](addons/shanty/CHANGELOG.md).

This repository is a Godot 4.7 project that opens straight into the example (run it with F5). To
install Shanty, copy `addons/shanty/` into your project; a release's source archive contains that
folder and nothing else.

## Developing

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gexit -gconfig=.gutconfig.json
python tools/manifest.py --check
python -m unittest discover -s tools -p "*_test.py"
```

`addons/gut/` is [GUT](https://github.com/bitwes/Gut) 9.7.1 under its own licence, bundled for the
tests only. CI (`.github/workflows/ci.yml`) runs the tests, `gdformat --check`, `gdlint`, the
tools' own tests and the manifest check on every push and pull request, and holds a `vX.Y.Z` tag
to `plugin.cfg`'s version and the changelog.

MIT licensed — see [LICENSE](LICENSE).
