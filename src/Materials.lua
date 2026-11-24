-- User-defined, serializable material slots. No network calls.
local M={}
local function rgb(c) return {c.R,c.G,c.B} end
local function color(v) return Color3.new(v[1],v[2],v[3]) end
function M.capture(part)
    assert(part and part:IsA("BasePart"),"Select a BasePart with the desired material")
    local result={material=part.Material.Name,variant=part.MaterialVariant,color=rgb(part.Color),
        transparency=part.Transparency,reflectance=part.Reflectance,textures={}}
    for _,t in ipairs(part:GetChildren()) do
        if t:IsA("Texture") or t:IsA("Decal") then
            local x={class=t.ClassName,face=t.Face.Name,texture=t.Texture,color=rgb(t.Color3),transparency=t.Transparency}
            if t:IsA("Texture") then
                x.u=t.StudsPerTileU; x.v=t.StudsPerTileV
                x.ou=t.OffsetStudsU; x.ov=t.OffsetStudsV
            end
            table.insert(result.textures,x)
        end
    end
    return result
end
function M.apply(part,style)
    if not style then return end
    local material=Enum.Material[style.material]
    assert(material,"Invalid material: "..tostring(style.material))
    part.Material=material
    part.MaterialVariant=style.variant or ""
    part.Color=color(style.color)
    part.Transparency=style.transparency or 0
    part.Reflectance=style.reflectance or 0
    for _,t in ipairs(part:GetChildren()) do
        if t:IsA("Decal") then t:Destroy() end
    end
    for _,x in ipairs(style.textures or {}) do
        assert(x.class=="Texture" or x.class=="Decal","Invalid texture class")
        local t=Instance.new(x.class)
        t.Face=Enum.NormalId[x.face]; t.Texture=x.texture
        t.Color3=color(x.color); t.Transparency=x.transparency
        if t:IsA("Texture") then
            t.StudsPerTileU=x.u; t.StudsPerTileV=x.v
            t.OffsetStudsU=x.ou; t.OffsetStudsV=x.ov
        end
        t.Parent=part
    end
end
return M
