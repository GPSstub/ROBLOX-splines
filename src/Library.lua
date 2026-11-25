-- Material presets, a per-place material/asset library and reusable recipes.
-- Everything is stored in ServerStorage.PathForgeLibrary so it saves with the place.
local P=require(script.Parent.Presets)
local Layers=require(script.Parent.Layers)
local Assets=require(script.Parent.Assets)
local Json=require(script.Parent.Json)
local L={RECIPE_FORMAT=1,MAX_ITEMS=200}

local function style(material,rgb,extra)
    local s={material=material,variant="",color={rgb[1]/255,rgb[2]/255,rgb[3]/255},transparency=0,reflectance=0,textures={}}
    for k,v in pairs(extra or {}) do s[k]=v end
    return s
end
-- Built-in material presets (names are English keys, translated in the UI).
L.BUILTIN={
    {"Asphalt (dark)",style("Asphalt",{54,58,63})},
    {"Asphalt (worn)",style("Asphalt",{96,98,100})},
    {"Concrete (light)",style("Concrete",{170,170,165})},
    {"Concrete (dark)",style("Concrete",{99,99,95})},
    {"Pavement",style("Pavement",{140,138,132})},
    {"Brick (red)",style("Brick",{141,72,55})},
    {"Cobblestone",style("Cobblestone",{120,115,108})},
    {"Wood (oak)",style("Wood",{150,110,70})},
    {"Wood (dark)",style("Wood",{91,67,46})},
    {"Wood planks",style("WoodPlanks",{160,120,80})},
    {"Steel",style("Metal",{103,110,119})},
    {"Rusty metal",style("CorrodedMetal",{125,80,55})},
    {"Diamond plate",style("DiamondPlate",{150,155,160})},
    {"Marble (white)",style("Marble",{230,230,225})},
    {"Granite",style("Granite",{110,105,100})},
    {"Glass (clear)",style("Glass",{200,225,235},{transparency=0.5,reflectance=0.2})},
    {"Grass",style("Grass",{90,140,60})},
    {"Sand",style("Sand",{210,190,140})},
    {"Neon (blue)",style("Neon",{60,160,255})},
    {"Painted line (white)",style("SmoothPlastic",{220,220,210})},
    {"Painted line (yellow)",style("SmoothPlastic",{233,184,62})},
}

function L.validName(name)
    assert(type(name)=="string","Enter a library name")
    name=name:match("^%s*(.-)%s*$")
    assert(#name>=1 and #name<=50,"Library names must be 1–50 characters")
    assert(not name:find("[%c/\\]"),"Library names cannot contain slashes")
    return name
end

-- Validates a material style table (shape written by Materials.capture).
function L.validStyle(s)
    assert(type(s)=="table" and type(s.material)=="string" and Enum.Material[s.material],"Invalid material style")
    assert(type(s.color)=="table" and #s.color==3,"Invalid material style")
    for _,c in ipairs(s.color) do assert(type(c)=="number" and c>=0 and c<=1,"Invalid material style") end
    s.variant=type(s.variant)=="string" and s.variant or ""
    s.transparency=math.clamp(tonumber(s.transparency) or 0,0,1)
    s.reflectance=math.clamp(tonumber(s.reflectance) or 0,0,1)
    s.textures=type(s.textures)=="table" and s.textures or {}
    return s
end

-- Library folders ------------------------------------------------------------
-- folder(storage, create): returns ServerStorage.PathForgeLibrary/<kind>, optionally creating it.
function L.folder(storage,kind,create)
    local root=storage:FindFirstChild("PathForgeLibrary")
    if not root then
        if not create then return nil end
        root=Instance.new("Folder"); root.Name="PathForgeLibrary"; root.Parent=storage
    end
    assert(root:IsA("Folder"),"PathForgeLibrary must be a Folder")
    local f=root:FindFirstChild(kind)
    if not f then
        if not create then return nil end
        f=Instance.new("Folder"); f.Name=kind; f.Parent=root
    end
    assert(f:IsA("Folder"),"PathForgeLibrary must be a Folder")
    return f
end
local function sortedChildren(folder)
    if not folder then return {} end
    local list=folder:GetChildren()
    table.sort(list,function(a,b) return a.Name:lower()<b.Name:lower() end)
    return list
end

-- Materials: built-ins first, then the place's saved materials ("My: name").
function L.materials(storage)
    local out={}
    for _,b in ipairs(L.BUILTIN) do out[#out+1]={name=b[1],style=b[2],builtin=true} end
    for _,v in ipairs(sortedChildren(L.folder(storage,"Materials",false))) do
        if v:IsA("StringValue") then
            local ok,s=pcall(function() return L.validStyle(Json.decode(v.Value)) end)
            if ok then out[#out+1]={name=v.Name,style=s,builtin=false} end
        end
    end
    return out
end
function L.saveMaterial(storage,name,s)
    name=L.validName(name)
    local folder=L.folder(storage,"Materials",true)
    assert(#folder:GetChildren()<L.MAX_ITEMS,"Library is full (200 items)")
    local v=folder:FindFirstChild(name) or Instance.new("StringValue")
    v.Name=name; v.Value=Json.encode(L.validStyle(table.clone(s))); v.Parent=folder
    return v
end

-- Assets: valid Models/BaseParts stored in the library (and older generation snapshots).
function L.assets(storage)
    local out={}
    local seen={}
    local function scan(folder)
        for _,a in ipairs(sortedChildren(folder)) do
            if not seen[a] and pcall(Assets.count,a) then seen[a]=true; out[#out+1]=a end
        end
    end
    scan(L.folder(storage,"Assets",false))
    scan(storage:FindFirstChild("PathForgeAssets"))
    return out
end
function L.addAsset(storage,source,name)
    Assets.count(source)
    local folder=L.folder(storage,"Assets",true)
    assert(#folder:GetChildren()<L.MAX_ITEMS,"Library is full (200 items)")
    local c=Assets.clone(source)
    c.Name=L.validName(name or source.Name)
    c.Parent=folder
    return c
end

-- Recipes: generator stack + layer settings (+ source references) without points.
function L.encodeRecipe(entries,layers,smooth)
    assert(#entries>=1,"A path needs at least one generator")
    local data={format=L.RECIPE_FORMAT,smooth=smooth,generators={},layers={}}
    local refs={}
    for i,e in ipairs(entries) do
        local o=P.validate(table.clone(e.o))
        data.generators[i]={o=o,styles=e.styles or {},enabled=e.enabled~=false}
        if e.source then refs[string.format("G%02d",i)]=e.source end
    end
    for i,l in ipairs(layers or {}) do
        Layers.validate(l)
        data.layers[i]={spacing=l.spacing,side=l.side,height=l.height,yaw=l.yaw,roll=l.roll,enabled=l.enabled,collide=l.collide}
        if l.source then refs[string.format("L%02d",i)]=l.source end
    end
    return Json.encode(data),refs
end
function L.decodeRecipe(text,refs)
    local data=Json.decode(text)
    assert(type(data)=="table" and data.format==L.RECIPE_FORMAT,"Unsupported recipe format")
    assert(type(data.generators)=="table" and #data.generators>=1 and #data.generators<=8,"A path needs 1–8 generators")
    local entries,layers={},{}
    for i,g in ipairs(data.generators) do
        local o=P.options(g.o and g.o.preset)
        for k,v in pairs(g.o) do o[k]=v end
        local styles={}
        for slot,s in pairs(type(g.styles)=="table" and g.styles or {}) do styles[slot]=L.validStyle(s) end
        entries[i]={o=P.validate(o),styles=styles,enabled=g.enabled~=false,source=refs[string.format("G%02d",i)]}
    end
    assert(#(data.layers or {})<=Layers.MAX_LAYERS,"Maximum 12 repeat layers")
    for i,l in ipairs(data.layers or {}) do
        local layer=table.clone(l)
        layer.source=refs[string.format("L%02d",i)]
        Layers.validate(layer)
        if not layer.source then layer.enabled=false end
        layers[i]=layer
    end
    return entries,layers,data.smooth~=false
end
function L.saveRecipe(storage,name,entries,layers,smooth)
    name=L.validName(name)
    local text,refs=L.encodeRecipe(entries,layers,smooth)
    local folder=L.folder(storage,"Recipes",true)
    assert(#folder:GetChildren()<L.MAX_ITEMS,"Library is full (200 items)")
    local old=folder:FindFirstChild(name)
    if old then old:Destroy() end
    local recipe=Instance.new("Configuration"); recipe.Name=name
    local v=Instance.new("StringValue"); v.Name="Data"; v.Value=text; v.Parent=recipe
    for key,inst in pairs(refs) do
        local ref=Instance.new("ObjectValue"); ref.Name=key; ref.Value=inst; ref.Parent=recipe
    end
    recipe.Parent=folder
    return recipe
end
function L.recipes(storage)
    local out={}
    for _,r in ipairs(sortedChildren(L.folder(storage,"Recipes",false))) do
        if r:FindFirstChild("Data") then out[#out+1]=r end
    end
    return out
end
function L.loadRecipe(recipe)
    local data=recipe:FindFirstChild("Data")
    assert(data and data:IsA("StringValue"),"Recipe data is missing")
    local refs={}
    for _,c in ipairs(recipe:GetChildren()) do
        if c:IsA("ObjectValue") and c.Value then refs[c.Name]=c.Value end
    end
    return L.decodeRecipe(data.Value,refs)
end
return L
