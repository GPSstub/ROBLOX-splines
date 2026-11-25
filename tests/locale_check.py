"""Checks that every user-facing English string in src/ has a Korean translation.

Collects string literals passed to label/button/input/say/assert/error and
UI `.Text=T(...)` assignments, then runs Locale.t with Korean forced on.
"""
import pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTEXT = re.compile(r'\b(label|button|input|say|assert|error|T|row)\(|^\s*\{"[^"]+",')
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
# Names that are only ever used internally (class names, attribute keys...).
NOT_UI = {"PathForge"}

def ui_strings():
    found = set()
    for f in sorted((ROOT / "src").glob("*.lua")):
        if f.name in ("Locale.lua", "SelfTest.lua"):
            continue
        for line in f.read_text(encoding="utf-8").splitlines():
            if not CONTEXT.search(line):
                continue
            for s in LITERAL.findall(line):
                if s in NOT_UI or "%" in s or s != s.strip() or not s or s.endswith("("):
                    continue  # fragments / format strings are covered by SAMPLES
                if " " in s or s in TAB_AND_PRESET_NAMES:
                    found.add(s)
    return sorted(found)

TAB_AND_PRESET_NAMES = {"Path", "Shape", "Layers", "Library", "Build", "Pavement", "Steel",
                        "Granite", "Grass", "Sand", "Cobblestone", "Rail", "Road", "Wall",
                        "Fence", "Pipe", "Custom", "Deform", "Extrude"}
# Formatted strings built at runtime.
SAMPLES = [
    "3 points   |   Node 2   |   New path",
    "Generator: Rail",
    "Mesh collision: Hull",
    "Material slot: RailFoot",
    "Asset: Lamp",
    "Concrete / default / 2 textures",
    "1 / 3  |  Missing source",
    "Generated 120 parts | 45.5 studs. Saved path can be reloaded.",
    "15 geometry tests passed",
    "width must be between 0.05 and 100",
    "Preview: Path is too short",
    "Invalid material: Foo",
    "Mesh upload failed: 403",
    "Editor closed or play test started; uploaded asset ID: 123",
    "Mesh creation failed (asset 123): timeout",
    "PathForge.Geometry:44: Path is too short",
    "Preview: PathForge.Extrude:31: Profile area is zero",
    "Part budget exceeded (3000)",
    "Fill material: Rock",
    "Draped 3 of 5 points onto the ground.",
    "Terrain: 10 fill and 10 carve blocks. Undo reverts it in one step.",
    "Snapped 2 path end(s). Generate to build the branch.",
    "Generator 2 / 3  |  Wall",
    "Preview ready: 120 parts, 30 layer parts. Nothing was uploaded.",
]
# Strings whose leading word is a Roblox/internal name and need no translation.
ALLOWED_SAME = {"PATHFORGE   /   0.5"}

def check(lua):
    lua.execute("MODULES = {}")
    locale = lua.execute("local L=require('Locale'); return L")
    english_ok = all(locale.t(s) == s for s in ui_strings() + SAMPLES)
    locale.language = "ko"
    missing = [s for s in ui_strings() + SAMPLES if locale.t(s) == s and s not in ALLOWED_SAME]
    return english_ok, missing
