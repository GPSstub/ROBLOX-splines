-- Turns a generator stack into Instances. Part-based and Custom generators are
-- built first so budget failures happen before any mesh upload starts.
local G=require(script.Parent.Geometry)
local P=require(script.Parent.Presets)
local Assets=require(script.Parent.Assets)
local Materials=require(script.Parent.Materials)
local Extrude=require(script.Parent.Extrude)
local Deform=require(script.Parent.Deform)
local B={MAX_PARTS=6500}

function B.part(parent,spec,collide,preview,style)
    local p=Instance.new("Part")
    p.Name=spec.name
    p.Size=Vector3.new(math.max(spec.size.X,0.05),math.max(spec.size.Y,0.05),math.max(spec.size.Z,0.05))
    p.CFrame=spec.cf
    p.Anchored=true; p.CanCollide=collide and not preview; p.CanTouch=false
    p.Material=Enum.Material[spec.material]; p.Color=Color3.fromRGB(spec.color[1],spec.color[2],spec.color[3])
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    if spec.shape then p.Shape=Enum.PartType[spec.shape] end
    if preview then p.CanQuery=false; p.Archivable=false end
    Materials.apply(p,style)
    p.Parent=parent
    return p
end

-- Builds one generator into `folder`. Returns part count and preview meshes.
function B.entry(path,entry,folder,ctx,budget)
    local o=entry.o
    local styles=entry.styles or {}
    if P.PART_BASED[o.preset] then
        local specs=P.parts(path,o,budget,ctx.budget or B.MAX_PARTS)
        for _,spec in ipairs(specs) do B.part(folder,spec,o.collide,ctx.preview,styles[spec.name]) end
        return #specs
    elseif o.preset=="Custom" then
        local per=Assets.count(entry.source)
        local ds=G.instances(path,o.spacing,math.max(1,math.floor(budget/per)))
        assert(#ds*per<=budget,"Part budget exceeded ("..(ctx.budget or B.MAX_PARTS)..")")
        for _,d in ipairs(ds) do
            local p,f,_,u=G.frame(path,d)
            p+=Vector3.new(0,o.offset,0)
            local c=Assets.clone(entry.source)
            c.Parent=folder
            c:PivotTo(CFrame.lookAt(p,p+f,u)*CFrame.Angles(0,math.rad(o.yaw),0)*CFrame.Angles(0,0,math.rad(o.roll)))
            Assets.configure(c,o.collide,ctx.preview)
        end
        return #ds*per
    end
    assert(budget>=1,"No budget left for base mesh")
    if not ctx.preview then assert(ctx.allowUpload,"Authorize mesh uploads before Generate") end
    local part,mesh
    if o.preset=="Extrude" then
        part,mesh=Extrude.build(path,o,entry.source,ctx.preview,ctx.canContinue,styles.ExtrudedMesh)
    else
        Assets.count(entry.source)
        part,mesh=Deform.build(entry.source,path,o,ctx.canContinue,ctx.preview)
    end
    part.Parent=folder
    return 1,mesh
end

-- Builds every enabled generator. ctx = {preview, allowUpload, canContinue, budget}.
-- Returns the output folder, part count and a list of preview EditableMeshes.
function B.stack(path,entries,ctx)
    local budget=ctx.budget or B.MAX_PARTS
    local output=Instance.new("Folder"); output.Name="Generators"
    local meshes={}
    local count=0
    local ok,err=pcall(function()
        local order={}
        for i,entry in ipairs(entries) do
            if entry.enabled~=false then order[#order+1]=i end
        end
        -- Mesh generators last: nothing is uploaded unless every other generator fits.
        table.sort(order,function(a,b)
            local ma,mb=P.MESH[entries[a].o.preset] and 1 or 0,P.MESH[entries[b].o.preset] and 1 or 0
            if ma~=mb then return ma<mb end
            return a<b
        end)
        local meshCount=0
        for _,i in ipairs(order) do if P.MESH[entries[i].o.preset] then meshCount+=1 end end
        for _,i in ipairs(order) do
            local entry=entries[i]
            local folder=Instance.new("Folder"); folder.Name=string.format("G%02d_%s",i,entry.o.preset); folder.Parent=output
            -- Keep one part of budget per remaining mesh generator.
            local reserve=P.MESH[entry.o.preset] and 0 or meshCount
            local n,mesh=B.entry(path,entry,folder,ctx,budget-count-reserve)
            count+=n
            if P.MESH[entry.o.preset] then meshCount-=1 end
            if mesh then meshes[#meshes+1]=mesh end
            assert(count<=budget,"Part budget exceeded ("..budget..")")
        end
    end)
    if not ok then
        output:Destroy()
        for _,m in ipairs(meshes) do m:Destroy() end
        error(err,0)
    end
    return output,count,meshes
end
return B
