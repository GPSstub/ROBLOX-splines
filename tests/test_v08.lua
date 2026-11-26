-- v0.8: material presets, place library (materials, assets) and recipes.
local t=require('harness').new()
local Lib=require('Library')
local P=require('Presets')
local B=require('Builder')
local G=require('Geometry')
local V=Vector3.new
local function storage() local s=Instance.new("Folder"); s.Name="ServerStorage"; return s end
local function entry(preset) return {o=P.options(preset),styles={},enabled=true} end

t.check("builtin materials are all valid styles with real materials",function()
    assert(#Lib.BUILTIN>=20)
    local names={}
    for _,b in ipairs(Lib.BUILTIN) do
        assert(not names[b[1]],"duplicate "..b[1]); names[b[1]]=true
        Lib.validStyle(table.clone(b[2]))
    end
end)
t.check("builtin style applies to built parts",function()
    local e=entry("Wall")
    for _,b in ipairs(Lib.BUILTIN) do if b[1]=="Rusty metal" then e.styles.Wall=b[2] end end
    local out=B.stack(G.path({V(0,0,0),V(0,0,-10)},false),{e},{preview=true})
    assert(out:FindFirstChild("G01_Wall"):GetChildren()[1].Material.Name=="CorrodedMetal")
end)
t.check("names are validated",function()
    t.fails(function() Lib.validName("   ") end,"1–50 characters")
    t.fails(function() Lib.validName(("x"):rep(51)) end,"1–50 characters")
    t.fails(function() Lib.validName("a/b") end,"cannot contain slashes")
    assert(Lib.validName("  Old road  ")=="Old road")
end)
t.check("materials: save, overwrite and list after built-ins",function()
    local s=storage()
    local style={material="Slate",variant="",color={0.1,0.2,0.3},transparency=0,reflectance=0,textures={}}
    Lib.saveMaterial(s,"My slate",style)
    style.color={1,1,1}; Lib.saveMaterial(s,"My slate",style)
    local list=Lib.materials(s)
    assert(#list==#Lib.BUILTIN+1)
    local mine=list[#list]
    assert(mine.name=="My slate" and not mine.builtin and mine.style.color[1]==1)
    assert(#s:FindFirstChild("PathForgeLibrary"):FindFirstChild("Materials"):GetChildren()==1,"overwrite must not duplicate")
end)
t.check("materials: corrupt entries are skipped, invalid styles refused",function()
    local s=storage()
    local f=Lib.folder(s,"Materials",true)
    local v=Instance.new("StringValue"); v.Name="bad"; v.Value="{not json"; v.Parent=f
    assert(#Lib.materials(s)==#Lib.BUILTIN)
    t.fails(function() Lib.saveMaterial(s,"x",{material="NotAMaterial",color={0,0,0}}) end,"Invalid material style")
end)
t.check("assets: add selected model, list library and old snapshots",function()
    local s=storage()
    local m=Instance.new("Model"); m.Name="Lamp"; Instance.new("Part",m); Instance.new("Script",m)
    local snap=Instance.new("Folder"); snap.Name="PathForgeAssets"; snap.Parent=s
    local old=Instance.new("Part"); old.Name="Bench_1234"; old.Parent=snap
    local added=Lib.addAsset(s,m,"Street lamp")
    assert(added.Name=="Street lamp" and added:FindFirstChildWhichIsA("Script")==nil)
    local list=Lib.assets(s)
    assert(#list==2 and list[1]==added and list[2]==old)
    t.fails(function() Lib.addAsset(s,Instance.new("Model")) end,"Asset contains no BaseParts")
end)
t.check("recipes: round trip keeps generators, styles, layers and sources",function()
    local s=storage()
    local src=Instance.new("Part"); src.Name="Post"
    local e1=entry("Road"); e1.o.width=10; e1.styles.RoadSurface=Lib.BUILTIN[1][2]
    local e2=entry("Custom"); e2.source=src; e2.enabled=false
    local layers={{source=src,spacing=4,side=6,height=0,yaw=90,roll=0,enabled=true,collide=false}}
    Lib.saveRecipe(s,"Country road",{e1,e2},layers,false)
    local recipes=Lib.recipes(s)
    assert(#recipes==1 and recipes[1].Name=="Country road")
    local entries,ls,smooth=Lib.loadRecipe(recipes[1])
    assert(#entries==2 and entries[1].o.preset=="Road" and entries[1].o.width==10)
    assert(entries[1].styles.RoadSurface.material=="Asphalt")
    assert(entries[2].source~=src and entries[2].source:IsDescendantOf(recipes[1]) and entries[2].enabled==false)
    assert(#ls==1 and ls[1].source==entries[2].source and ls[1].side==6 and ls[1].yaw==90 and ls[1].collide==false)
    src:Destroy()
    local loaded=Lib.loadRecipe(recipes[1]); assert(loaded[2].source.Parent~=nil)
    assert(smooth==false)
end)
t.check("recipes: layer with a missing source loads disabled",function()
    local text=Lib.encodeRecipe({entry("Wall")},{{spacing=4,side=0,height=0,yaw=0,roll=0,enabled=true,collide=true,source=Instance.new("Part")}},true)
    local _,ls=Lib.decodeRecipe(text,{})
    assert(ls[1].enabled==false and ls[1].source==nil)
end)
t.check("recipes: bad data is rejected",function()
    t.fails(function() Lib.decodeRecipe('{"format":99,"generators":[]}',{}) end,"Unsupported recipe format")
    t.fails(function() Lib.decodeRecipe('{"format":1,"generators":[]}',{}) end,"1–8 generators")
    t.fails(function() Lib.decodeRecipe('{"format":1,"generators":[{"o":{"preset":"Wall","width":-5}}]}',{}) end,"width must be between")
end)
t.check("library folder must be a Folder",function()
    local s=storage()
    local bad=Instance.new("Model"); bad.Name="PathForgeLibrary"; bad.Parent=s
    t.fails(function() Lib.saveMaterial(s,"x",Lib.BUILTIN[1][2]) end,"PathForgeLibrary must be a Folder")
end)
return t.finish()
