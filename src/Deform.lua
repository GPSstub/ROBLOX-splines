-- Single static MeshPart deformation. No asset upload, runtime script or HTTP.
local AssetService=game:GetService("AssetService")
local G=require(script.Parent.Geometry)
local D={}
function D.build(source,path,o)
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
        local finalCenter=mesh:GetCenter()
        local finalSize=mesh:GetSize()
        -- Freeze the mesh as place-local opaque content before releasing the editable object.
        local status,content=AssetService:CreateDataModelContentAsync(Content.fromObject(mesh))
        assert(status==Enum.CreateContentResult.Success and content,"Could not bake mesh into place-local content")
        output=AssetService:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity.Default})
        output.Name="DeformedMesh"
        output.Size=Vector3.new(math.max(finalSize.X,0.001),math.max(finalSize.Y,0.001),math.max(finalSize.Z,0.001))
        output.CFrame=CFrame.new(anchor+finalCenter)
        output.Material=source.Material; output.MaterialVariant=source.MaterialVariant
        output.Color=source.Color; output.Transparency=source.Transparency; output.Reflectance=source.Reflectance
        output.TextureContent=source.TextureContent
        output.DoubleSided=source.DoubleSided; output.CastShadow=source.CastShadow
        for _,child in ipairs(source:GetChildren()) do
            if child:IsA("SurfaceAppearance") and child.Archivable then child:Clone().Parent=output end
        end
        output.Anchored=true; output.CanCollide=o.collide; output.CanTouch=false
        return output
    end)
    if mesh then mesh:Destroy() end
    if not ok then if output then output:Destroy() end; error(result,0) end
    return result
end
return D
