-- Sweeps a closed convex or open cross-section along an arc-length spline.
-- All mesh vertices are shared between rings; UV and normal seams are independent.
local G=require(script.Parent.Geometry)
local A=game:GetService("AssetService")
local O=require(script.Parent.MeshOutput)
local Materials=require(script.Parent.Materials)
local E={}
local function cross(a,b) return a.X*b.Y-a.Y*b.X end
local function finite(x) return x and x==x and math.abs(x)<=1000 end
function E.profile(o)
    local profile={}
    local w,h=o.width,o.height
    assert(w>0 and h>0,"Extrude width and height must be positive")
    local closed=true
    if o.profile=="rectangle" then
        profile={Vector2.new(-w/2,-h/2),Vector2.new(w/2,-h/2),Vector2.new(w/2,h/2),Vector2.new(-w/2,h/2)}
    elseif o.profile=="circle" then
        for i=0,o.sides-1 do local a=2*math.pi*i/o.sides; profile[#profile+1]=Vector2.new(w/2*math.cos(a),h/2*math.sin(a)) end
    elseif o.profile=="arch" then
        closed=false
        for i=0,o.sides do local a=math.pi*i/o.sides; profile[#profile+1]=Vector2.new(w/2*math.cos(a),h*math.sin(a)) end
    else
        -- Custom convex polygon, normalized only by the supplied coordinates in studs.
        for pair in string.gmatch(o.profile,"[^;]+") do
            local x,y=pair:match("^%s*([^,]+),([^,]+)%s*$")
            x=tonumber(x); y=tonumber(y)
            assert(finite(x) and finite(y),"Custom profile: x,y;x,y;... (studs)")
            profile[#profile+1]=Vector2.new(x,y)
        end
        assert(#profile>=3 and #profile<=64,"Custom profile needs 3–64 points")
        local area=0
        for i=1,#profile do area+=cross(profile[i],profile[i%#profile+1]) end
        assert(math.abs(area)>1e-5,"Profile area is zero")
        if area<0 then local rev={}; for i=#profile,1,-1 do rev[#rev+1]=profile[i] end; profile=rev end
        -- Strictly convex, ordered polygon: every other vertex left of every edge.
        for i=1,#profile do
            local j=i%#profile+1
            local a,b=profile[i],profile[j]
            assert((b-a).Magnitude>1e-4,"Duplicate profile point")
            for k=1,#profile do
                if k~=i and k~=j then assert(cross(b-a,profile[k]-a)>1e-6,"Profile must be a strictly convex ordered polygon") end
            end
        end
    end
    return profile,closed
end
E.MAX_CHUNK_VERTICES=60000
E.MAX_CHUNK_TRIANGLES=20000
E.MAX_CHUNKS=8
local function corner(a,b,combine)
    return Vector3.new(combine(a.X,b.X),combine(a.Y,b.Y),combine(a.Z,b.Z))
end

-- Long sweeps are split into chunks that each fit one EditableMesh. Chunks share
-- their boundary ring position, and UVs use absolute path distance, so seams line up.
function E.chunks(sampleCount,n,edges,closed,maxTriangles,maxVertices,bounds)
    local capTris=closed and 2*(n-2) or 0
    local perRing=edges*2
    local maxRings=math.min(math.floor((maxTriangles-capTris)/perRing)+1,math.floor(maxVertices/n))
    assert(maxRings>=2,"Profile too detailed for one mesh; reduce profile sides")
    local chunks={}
    local first=1
    while first<sampleCount do
        local last=math.min(sampleCount,first+maxRings-1)
        if bounds then
            local lo,hi=bounds[first].lo,bounds[first].hi
            for i=first+1,last do
                local nextLo=corner(lo,bounds[i].lo,math.min)
                local nextHi=corner(hi,bounds[i].hi,math.max)
                local size=nextHi-nextLo
                -- Allow for Vector3 rounding when vertices are rebuilt in chunk-local space.
                if math.max(size.X,size.Y,size.Z)>O.MAX_DIMENSION-0.05 then
                    last=i-1
                    break
                end
                lo,hi=nextLo,nextHi
            end
            assert(last>first,"Profile is too large for a mesh chunk; reduce its dimensions or the segment length")
        end
        chunks[#chunks+1]={first=first,last=last}
        first=last
    end
    return chunks
end

local function ringFrame(path,d,co,si)
    local pos,_,right,up=G.frame(path,d)
    return pos,right*co+up*si,up*co-right*si
end

function E.plan(path,o)
    local profile,closed=E.profile(o)
    local samples=G.adaptive(path,o.step,math.rad(o.angle),o.tolerance,E.MAX_CHUNKS*2000)
    local n=#profile
    local edges=closed and n or n-1
    local bounds={}
    local origin=G.at(path,0)
    local roll=math.rad(o.roll or 0)
    local co,si=math.cos(roll),math.sin(roll)
    for i,d in ipairs(samples) do
        local pos,right,up=ringFrame(path,d,co,si)
        local center=pos-origin
        local lo,hi
        for _,q in ipairs(profile) do
            local vertex=center+right*q.X+up*q.Y
            lo=lo and corner(lo,vertex,math.min) or vertex
            hi=hi and corner(hi,vertex,math.max) or vertex
        end
        bounds[i]={lo=lo,hi=hi}
    end
    local chunks=E.chunks(#samples,n,edges,closed,E.MAX_CHUNK_TRIANGLES,E.MAX_CHUNK_VERTICES,bounds)
    assert(#chunks<=E.MAX_CHUNKS,"Mesh budget exceeded; increase step/tolerance or reduce profile sides")
    local triangles=(#samples-1)*edges*2+(closed and 2*(n-2) or 0)
    local perimeter={0}
    for i=1,edges do perimeter[i+1]=perimeter[i]+(profile[i%n+1]-profile[i]).Magnitude end
    return {profile=profile,closed=closed,samples=samples,edges=edges,triangles=triangles,
        vertices=#samples*n+(#chunks-1)*n,perimeter=perimeter,chunks=chunks}
end
-- Builds one chunk (sample range first..last) into an EditableMesh and MeshPart.
local function buildChunk(path,o,plan,chunk,source,preview,canContinue,style,index)
    local mesh,part
    local ok,result=pcall(function()
        mesh=A:CreateEditableMesh(); assert(mesh,"EditableMesh memory budget unavailable")
        local rings,uvs,normals={},{},{}
        local round=o.profile=="circle" or o.profile=="arch"
        local anchor=G.at(path,plan.samples[chunk.first])
        local roll=math.rad(o.roll)
        local co,si=math.cos(roll),math.sin(roll)
        local n=#plan.profile
        for i=chunk.first,chunk.last do
            local d=plan.samples[i]
            local pos,right,up=ringFrame(path,d,co,si)
            local k=i-chunk.first+1
            rings[k]={}; uvs[k]={}; normals[k]={}
            for j,q in ipairs(plan.profile) do
                rings[k][j]=mesh:AddVertex(pos-anchor+right*q.X+up*q.Y+Vector3.new(0,o.offset,0))
            end
            for j=1,plan.edges+1 do uvs[k][j]=mesh:AddUV(Vector2.new(d/o.uvLength,plan.perimeter[j]/o.uvWidth)) end
            -- Per-edge smoothing along length, with a hard profile corner.
            if round then
                local rx=o.width/2
                local ry=o.profile=="arch" and o.height or o.height/2
                for j,q in ipairs(plan.profile) do
                    local normal=(right*(q.X/(rx*rx))+up*(q.Y/(ry*ry))).Unit
                    if o.profile=="arch" then normal=-normal end -- clockwise open profile winding
                    normals[k][j]=mesh:AddNormal(normal)
                end
            else
                for j=1,plan.edges do
                    local nextJ=j%n+1
                    local edge=plan.profile[nextJ]-plan.profile[j]
                    normals[k][j]=mesh:AddNormal((right*edge.Y-up*edge.X).Unit)
                end
            end
        end
        local function tri(a,b,c,ua,ub,uc,na,nb,nc)
            local f=mesh:AddTriangle(a,b,c)
            mesh:SetFaceUVs(f,{ua,ub,uc}); mesh:SetFaceNormals(f,{na,nb,nc})
        end
        for i=1,#rings-1 do
            for j=1,plan.edges do
                local k=j%n+1
                local a,b,c,d=rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j]
                local ua,ub,uc,ud=uvs[i][j],uvs[i][j+1],uvs[i+1][j+1],uvs[i+1][j]
                local na,nb=normals[i][j],normals[i+1][j]
                -- Local right × up = -forward; this winding points outward.
                local nc=round and normals[i+1][k] or nb
                local nd=round and normals[i][k] or na
                tri(a,d,c,ua,ud,uc,na,nb,nc)
                tri(a,c,b,ua,uc,ub,na,nc,nd)
            end
        end
        if plan.closed then
            -- Caps only at the ends of the whole sweep, never between chunks.
            local caps={}
            if chunk.first==1 then caps[#caps+1]={ring=1,sample=chunk.first,start=true} end
            if chunk.last==#plan.samples then caps[#caps+1]={ring=#rings,sample=chunk.last,start=false} end
            for _,cap in ipairs(caps) do
                local _,f=G.frame(path,plan.samples[cap.sample])
                local normal=mesh:AddNormal(cap.start and -f or f)
                local capUV={}
                for j,q in ipairs(plan.profile) do capUV[j]=mesh:AddUV(Vector2.new(q.X/o.uvLength,q.Y/o.uvWidth)) end
                for j=2,n-1 do
                    local b,c=j,j+1
                    if not cap.start then b,c=c,b end
                    tri(rings[cap.ring][1],rings[cap.ring][b],rings[cap.ring][c],capUV[1],capUV[b],capUV[c],normal,normal,normal)
                end
            end
        end
        mesh:RemoveUnused()
        local name=#plan.chunks>1 and string.format("ExtrudedMesh_%02d",index) or "ExtrudedMesh"
        part=O.create(mesh,anchor,o,name,source,preview,canContinue)
        part.Name=name
        if not source then
            part.Material=Enum.Material.Concrete; part.Color=Color3.fromRGB(150,150,150)
            Materials.apply(part,style)
        end
        if not plan.closed then part.DoubleSided=true; part.CanCollide=false end
        part:SetAttribute("PathForgeTriangles",plan.triangles)
        part:SetAttribute("PathForgeVertices",plan.vertices)
        return part
    end)
    if not ok then if part then part:Destroy() end; if mesh then mesh:Destroy() end; error(result,0) end
    return result,mesh
end
-- Returns a list of MeshParts (one per chunk) and, for previews, their EditableMeshes.
function E.build(path,o,source,preview,canContinue,style,plan)
    plan=plan or E.plan(path,o)
    local parts,meshes={},{}
    local ok,err=pcall(function()
        for i,chunk in ipairs(plan.chunks) do
            local part,mesh=buildChunk(path,o,plan,chunk,source,preview,canContinue,style,i)
            parts[#parts+1]=part
            if preview then meshes[#meshes+1]=mesh else mesh:Destroy() end
        end
    end)
    if not ok then
        for _,p in ipairs(parts) do p:Destroy() end
        for _,m in ipairs(meshes) do m:Destroy() end
        error(err,0)
    end
    return parts,meshes
end
return E
