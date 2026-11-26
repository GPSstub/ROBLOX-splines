-- Turns a generator stack into Instances. Part-based and Custom generators are
-- built first so budget failures happen before any mesh upload starts.
local G=require(script.Parent.Geometry)
local P=require(script.Parent.Presets)
local Assets=require(script.Parent.Assets)
local Materials=require(script.Parent.Materials)
local Extrude=require(script.Parent.Extrude)
local Deform=require(script.Parent.Deform)
local Json=require(script.Parent.Json)
local Network=require(script.Parent.Network)
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

-- Builds one generator into `folder`. Returns part count and a list of preview meshes.
function B.entry(path,entry,folder,ctx,budget,meshPlan)
    local o=entry.o
    local styles=entry.styles or {}
    if P.PART_BASED[o.preset] then
        local function make() return P.parts(path,o,budget,ctx.budget or B.MAX_PARTS) end
        -- Part specs are pure data; reuse them when the path and options are unchanged.
        local specs
        if ctx.cache and path.key then
            specs=ctx.cache:memo(path.key.."|"..Json.encode(o),make)
            assert(#specs<=budget,"Part budget exceeded ("..(ctx.budget or B.MAX_PARTS)..")")
        else specs=make() end
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
    if o.preset=="Extrude" then
        meshPlan=meshPlan or Extrude.plan(path,o)
        assert(#meshPlan.chunks<=budget,"No budget left for base mesh")
        local parts,meshes=Extrude.build(path,o,entry.source,ctx.preview,ctx.canContinue,styles.ExtrudedMesh,meshPlan)
        for _,part in ipairs(parts) do part.Parent=folder end
        return #parts,meshes
    end
    Assets.count(entry.source)
    local part,mesh=Deform.build(entry.source,path,o,ctx.canContinue,ctx.preview)
    part.Parent=folder
    return 1,mesh and {mesh} or {}
end

-- Parts a mesh generator will create, checked before anything is built.
function B.meshParts(path,o)
    if o.preset=="Extrude" then
        local plan=Extrude.plan(path,o)
        return #plan.chunks,plan
    end
    return 1
end

-- Builds every enabled generator. ctx = {preview, allowUpload, canContinue, budget}.
-- Returns the output folder, part count and a list of preview EditableMeshes.
function B.stack(path,entries,ctx)
    local budget=ctx.budget or B.MAX_PARTS
    entries=table.clone(entries) -- junction cuts replace entries; never the caller's list
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
        if not ctx.preview and not ctx.allowUpload then
            for _,i in ipairs(order) do assert(not P.MESH[entries[i].o.preset],"Authorize mesh uploads before Generate") end
        end
        -- Plan every mesh first: profile/budget errors surface before any upload.
        local meshCount=0
        local need,plans={},{}
        for _,i in ipairs(order) do
            if P.MESH[entries[i].o.preset] then
                need[i],plans[i]=B.meshParts(path,entries[i].o)
                meshCount+=need[i]
            end
        end
        -- Junctions: roads leave a gap that one pad per crossing fills.
        local junctions=ctx.junctions or {}
        local pads=ctx.junctionPads or junctions
        local padRoad
        if #junctions>0 then
            for _,i in ipairs(order) do
                local e=entries[i]
                if e.o.preset=="Road" then
                    local o=table.clone(e.o); o.cuts=Network.cuts(junctions,path.length)
                    entries[i]={o=o,styles=e.styles,source=e.source,enabled=e.enabled}
                    padRoad=padRoad or entries[i]
                end
            end
        end
        if padRoad and #pads>0 then
            local folder=Instance.new("Folder"); folder.Name="Junctions"; folder.Parent=output
            for _,spec in ipairs(Network.padSpecs(pads,padRoad.o.height,padRoad.o.offset)) do
                B.part(folder,spec,padRoad.o.collide,ctx.preview,(padRoad.styles or {}).RoadSurface)
                count+=1
            end
        end
        if meshCount>0 then assert(meshCount<=budget-count,"No budget left for base mesh") end
        for _,i in ipairs(order) do
            local entry=entries[i]
            local folder=Instance.new("Folder"); folder.Name=string.format("G%02d_%s",i,entry.o.preset); folder.Parent=output
            -- Keep one part of budget per remaining mesh generator.
            local reserve=P.MESH[entry.o.preset] and 0 or meshCount
            local n,built=B.entry(path,entry,folder,ctx,budget-count-reserve,plans[i])
            count+=n
            if need[i] then meshCount-=need[i] end
            for _,m in ipairs(built or {}) do meshes[#meshes+1]=m end
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
