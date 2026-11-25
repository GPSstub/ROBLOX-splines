-- Saved path data (PathData folder) for generated models.
-- Format 2 stores a generator stack; format 1 (v0.1–v0.5) stored one generator
-- as attributes on PathData and is still read.
local P=require(script.Parent.Presets)
local Layers=require(script.Parent.Layers)
local Json=require(script.Parent.Json)
local S={FORMAT=2,MAX_GENERATORS=8,MAX_POINTS=128}
local OPTION_KEYS={"preset","profile","fidelity","collide"}
for k in pairs(P.NUMBERS) do OPTION_KEYS[#OPTION_KEYS+1]=k end
table.sort(OPTION_KEYS)
S.OPTION_KEYS=OPTION_KEYS

local function decodeStyles(text)
    if type(text)~="string" or text=="" then return {} end
    local ok,v=pcall(Json.decode,text)
    return ok and type(v)=="table" and v or {}
end

-- Reads one generator's options from attributes; missing values use defaults.
local function readOptions(get)
    local preset=get("preset")
    assert(P.isPreset(preset),"Unknown preset")
    local o=P.options(preset)
    for k,spec in pairs(P.NUMBERS) do
        local v=get(k)
        if type(v)=="number" and v==v and v>=spec[1] and v<=spec[2] then o[k]=v end
    end
    local profile=get("profile"); if type(profile)=="string" and profile~="" then o.profile=profile end
    local fidelity=get("fidelity"); if table.find(P.FIDELITY,fidelity) then o.fidelity=fidelity end
    local collide=get("collide"); if type(collide)=="boolean" then o.collide=collide end
    return P.validate(o)
end
S.readOptions=readOptions

function S.write(meta,state,pivot)
    meta:SetAttribute("Format",S.FORMAT)
    meta:SetAttribute("smooth",state.smooth)
    meta:SetAttribute("junctions",state.junctions==true)
    meta:SetAttribute("PointCount",#state.points)
    meta:SetAttribute("CoordinateSpace","Local")
    for i,pos in ipairs(state.points) do
        local v=Instance.new("Vector3Value"); v.Name=string.format("P%03d",i); v.Value=pivot:PointToObjectSpace(pos); v.Parent=meta
    end
    assert(#state.entries>=1 and #state.entries<=S.MAX_GENERATORS,"A path needs 1–8 generators")
    local folder=Instance.new("Folder"); folder.Name="Generators"; folder.Parent=meta
    for i,entry in ipairs(state.entries) do
        local ref=Instance.new("ObjectValue"); ref.Name=string.format("G%02d",i); ref.Value=entry.source
        for _,k in ipairs(OPTION_KEYS) do ref:SetAttribute(k,entry.o[k]) end
        ref:SetAttribute("enabled",entry.enabled~=false)
        ref:SetAttribute("materialStyles",Json.encode(entry.styles or {}))
        ref.Parent=folder
    end
    Layers.write(meta,state.layers or {})
end

function S.read(meta,pivot)
    local n=meta:GetAttribute("PointCount")
    assert(type(n)=="number" and n>=2 and n<=S.MAX_POINTS,"Invalid saved point count")
    local localSpace=meta:GetAttribute("CoordinateSpace")=="Local"
    local points={}
    for i=1,n do
        local v=meta:FindFirstChild(string.format("P%03d",i))
        assert(v and v:IsA("Vector3Value"),"Missing control point")
        points[i]=localSpace and pivot:PointToWorldSpace(v.Value) or v.Value
    end
    local entries={}
    local folder=meta:FindFirstChild("Generators")
    if folder then
        local children=folder:GetChildren()
        table.sort(children,function(a,b) return a.Name<b.Name end)
        assert(#children>=1 and #children<=S.MAX_GENERATORS,"A path needs 1–8 generators")
        for _,ref in ipairs(children) do
            assert(ref:IsA("ObjectValue"),"Invalid saved generator")
            local o=readOptions(function(k) return ref:GetAttribute(k) end)
            entries[#entries+1]={o=o,source=ref.Value,enabled=ref:GetAttribute("enabled")~=false,styles=decodeStyles(ref:GetAttribute("materialStyles"))}
        end
    else
        -- Format 1: one generator stored directly on PathData.
        local o=readOptions(function(k) return meta:GetAttribute(k) end)
        local ref=meta:FindFirstChild("Asset")
        local source=ref and ref:IsA("ObjectValue") and ref.Value or nil
        entries[1]={o=o,source=source,enabled=true,styles=decodeStyles(meta:GetAttribute("materialStyles"))}
    end
    return {points=points,smooth=meta:GetAttribute("smooth")==true,entries=entries,layers=Layers.read(meta),
        junctions=meta:GetAttribute("junctions")==true}
end
return S
