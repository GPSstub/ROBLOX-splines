"""Run PathForge's SelfTest.lua outside Roblox Studio.

Uses Lua 5.4 (via the `lupa` package) plus small Roblox shims. Luau-only syntax
(`x+=y`) is rewritten to plain Lua before loading. Usage: python tests/run.py
"""
import pathlib, re, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import lupa.lua54 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

def luau_to_lua(code: str) -> str:
    # x+=expr  ->  x=x+(expr); expr ends at ';', a newline, or a trailing ' end'
    return re.sub(r"([A-Za-z_][\w\.]*)\s*\+=\s*(.+?)(?=;|\n|\s+end\b)",
                  lambda m: f"{m[1]}={m[1]}+({m[2]})", code)

def main(extra=()):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests" / "roblox_shim.lua").read_text())
    loader = lua.eval("""function(name, code)
        local fn, err = load(code, '@src/'..name..'.lua'); if not fn then error(err) end
        return fn end""")
    lua.execute("""
        MODULES = {}; SOURCES = {}
        local Parent = setmetatable({}, {__index=function(_, k) return k end})
        script = {Parent = Parent}
        game = {GetService=function() return {} end}
        local raw_require = require
        function require(name)
            if type(name) ~= 'string' or not SOURCES[name] then return raw_require(name) end
            if MODULES[name] == nil then MODULES[name] = SOURCES[name]() end
            return MODULES[name]
        end""")
    sources = lua.globals().SOURCES
    for f in SRC.glob("*.lua"):
        name = f.stem
        if name.endswith(".server"):
            continue
        sources[name] = loader(name, luau_to_lua(f.read_text(encoding="utf-8")))
    failures = 0
    for label, chunk in [("SelfTest.run (15 Studio self-tests)", "return require('SelfTest').run()"), *extra]:
        lua.execute("MODULES = {}")  # fresh module state per suite
        try:
            result = lua.execute(chunk)
            print(f"PASS  {label}: {result}")
        except lupa.LuaError as e:
            failures += 1
            print(f"FAIL  {label}: {e}")
    import locale_check
    english_ok, missing = locale_check.check(lua)
    if english_ok and not missing:
        print("PASS  Korean translation covers all UI strings; English unchanged")
    else:
        failures += 1
        print("FAIL  translation:", "English text changed" if not english_ok else "", *[f"\n    missing: {s}" for s in missing])
    sys.path.insert(0, str(ROOT / "tools"))
    import build_rbxmx
    if (ROOT / "PathForge.rbxmx").read_text(encoding="utf-8") == build_rbxmx.build():
        print("PASS  PathForge.rbxmx matches src/")
    else:
        failures += 1
        print("FAIL  PathForge.rbxmx is out of date: run python tools/build_rbxmx.py")
    return failures

if __name__ == "__main__":
    extra = []
    extra_file = ROOT / "tests" / "regression.lua"
    if extra_file.exists():
        extra.append(("tests/regression.lua", extra_file.read_text(encoding="utf-8")))
    sys.exit(1 if main(extra) else 0)
