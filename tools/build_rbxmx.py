"""Build PathForge.rbxmx from default.project.json and src/.

Usage: python tools/build_rbxmx.py          (writes PathForge.rbxmx)
       python tools/build_rbxmx.py --check  (fails if PathForge.rbxmx is stale)
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "PathForge.rbxmx"

def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def build():
    project = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
    tree = project["tree"]
    parts = ['<?xml version="1.0" encoding="utf-8"?>\n<roblox version="4"><External>null</External><External>nil</External>',
             f'<Item class="{tree["$className"]}" referent="RBX0"><Properties><string name="Name">{esc(project["name"])}</string></Properties>']
    ref = 1
    children = []
    for name, node in tree.items():
        if name.startswith("$"):
            continue
        path = node["$path"]
        cls = "Script" if path.endswith(".server.lua") else "ModuleScript"
        src = (ROOT / path).read_text(encoding="utf-8")
        children.append(f'<Item class="{cls}" referent="RBX{ref}"><Properties><string name="Name">{esc(name)}</string>'
                     f'<ProtectedString name="Source">{esc(src)}</ProtectedString></Properties></Item>')
        ref += 1
    parts.append("\n".join(children))
    parts.append("</Item></roblox>")
    return "".join(parts)

if __name__ == "__main__":
    data = build()
    if "--check" in sys.argv:
        if OUT.read_text(encoding="utf-8") != data:
            sys.exit("PathForge.rbxmx is out of date: run python tools/build_rbxmx.py")
        print("PathForge.rbxmx is up to date")
    else:
        OUT.write_text(data, encoding="utf-8")
        print("wrote", OUT.name)
