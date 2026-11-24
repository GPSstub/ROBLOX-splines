-- Explicit asset-backed deformation. Called only after a one-shot user authorization.
local AssetService=game:GetService("AssetService")
local G=require(script.Parent.Geometry)
local O=require(script.Parent.MeshOutput)
local D={}
function D.build(source,path,o,canContinue,preview)
    assert(source and source:IsA("MeshPart"),"Deform requires one static MeshPart")
    assert(not source:FindFirstChildWhichIsA("Bone",true),"Skinned meshes are not supported")
    assert(path.length<=2000,"Deform path limit: 2000 studs")
    local mesh,output
    local ok,result=pcall(function()
        mesh=AssetService:CreateEditableMeshAsync(source.MeshContent)
        assert(mesh,"EditableMesh unavailable (permissions or memory budget)")
        local ids=mesh:GetVertices()
        assert(#ids>=3 and #ids<=60000,"Unsupported vertex count")
        local size=mesh:GetSize()
        local center=mesh:GetCenter()
        assert(size.X>1e-5 and size.Y>=0 and size.Z>1e-5,"Source needs X width and -Z length")
        local scale=Vector3.new(source.Size.X/math.max(size.X,1e-5),source.Size.Y/math.max(size.Y,1e-5),source.Size.Z/math.max(size.Z,1e-5))
        local anchor=G.at(path,0)
        local roll=math.rad(o.roll)
        local co,si=math.cos(roll),math.sin(roll)
        for _,id in ipairs(ids) do
            local v=mesh:GetPosition(id)-center
            local d=math.clamp(0.5-v.Z/size.Z,0,1)*path.length
            local pos,_,right,up=G.frame(path,d)
            local x,y=v.X*scale.X,v.Y*scale.Y
            local world=pos-anchor+right*(x*co-y*si)+up*(x*si+y*co)+Vector3.new(0,o.offset,0)
            mesh:SetPosition(id,world)
        end
        for _,id in ipairs(mesh:GetNormals()) do mesh:ResetNormal(id) end
        output=O.create(mesh,anchor,o,"DeformedMesh",source,preview,canContinue)
        return output
    end)
    if not ok then if output then output:Destroy() end; if mesh then mesh:Destroy() end; error(result,0) end
    if preview then return result,mesh end
    mesh:Destroy()
    return result
end
return D
