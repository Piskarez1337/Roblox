# Black Clover RPG — Magic 0.2

Extension of the existing Roblox prototype: seven classes, 28 base spells, 16 awakened spells, grimoires, server mana/combat/clashes, passives, a fighting golem, and four transformations. Original arena, R15 movement, M1, dash, guard, HUD and NPCs are preserved.

- [Русская инструкция и ограничения](README_RU.md)
- [Ready-to-open Roblox place](dist/BlackClover_Magic.rbxlx) — download the raw file, then **File → Open from File → Play** in Studio.
- [Full package](dist/BlackClover_Magic.zip)
- [44 abilities](docs/MAGIC_ABILITIES_RU.md) · [Studio checks](docs/STUDIO_TESTS_RU.md)
- [Original OBJ/MTL import sources](meshes/README_RU.md) · [Validation report](TEST_REPORT_RU.md)

Controls: **M** class selection, **Z/X/C/V** spells, **G** awakening, **R** short flight in awakened Wind/Anti; original **M1 / Q / F / Shift / Space** remain. Exact awakening drain is Water 1, Bone 5, Wind 7, Anti 7 mana/s, with no fixed transformation lifetime.

Offline validation: 44 Luau sources compile, 596 rule assertions pass, Rojo builds 42 embedded scripts, four R15 rigs and 43 script-free art models. **Roblox Studio and multiplayer Play Mode have not been run in this environment.** Uploaded detailed MeshPart assets and reference-level visuals remain outstanding; current compound models and real OBJ/MTL sources provide the working art foundation.

Build: `python tools/check.py` then `python tools/package.py` with Luau 0.745 / Rojo 7.7.1 in PATH. Historical Stage 1 place/ZIP are retained.
