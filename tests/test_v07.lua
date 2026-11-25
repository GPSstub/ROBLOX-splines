-- v0.7: beam merging, pipe joints, Extrude chunking (with a fake EditableMesh) and caching.
local t=require('harness').new()
local savedGame,savedContent=game,Content
-- Fake AssetService: EditableMeshes count what is added to them.
local meshes={}
local function fakeMesh()
    local m={v={},tris=0,destroyed=false}
    function m:AddVertex(p) self.v[#self.v+1]=p; return #self.v end
    function m:AddUV() return 1 end
    function m:AddNormal() return 1 end
    function m:AddTriangle() self.tris+=1; return self.tris end
    function m:SetFaceUVs() end
    function m:SetFaceNormals() end
    function m:RemoveUnused() end
    function m:GetCenter() return Vector3.new(0,0,0) end
    function m:GetSize() return Vector3.new(1,1,1) end
    function m:Destroy() self.destroyed=true end
    meshes[#meshes+1]=m
    return m
end
local assetService={
    CreateEditableMesh=function() return fakeMesh() end,
    CreateMeshPartAsync=function() return Instance.new("MeshPart") end,
}
game={GetService=function(_,name) if name=="AssetService" then return assetService end return {} end,CreatorId=0}
Content={fromObject=function(o) return {object=o} end,fromUri=function(u) return {uri=u} end}

local G=require('Geometry')
local P=require('Presets')
local E=require('Extrude')
local B=require('Builder')
local Cache=require('Cache')
local V=Vector3.new
local function straight(len) return G.path({V(0,0,0),V(0,0,-len)},false) end
local function opts(preset,patch) local o=P.options(preset); for k,v in pairs(patch or {}) do o[k]=v end; return o end
local function always() return true end

t.check("merge: straight wall becomes one part with the full length",function()
    local specs=P.parts(straight(30),opts("Wall",{step=2}))
    assert(#specs==1,"parts "..#specs)
    -- 30 studs plus the 0.12 overlap that each segment carried at its ends.
    t.close(specs[1].size.Z,30.12,1e-3,"length")
    t.close(specs[1].cf.Position.Z,-15,1e-3,"center")
end)
t.check("merge: an L-shaped linear path keeps one part per leg",function()
    local p=G.path({V(0,0,0),V(0,0,-20),V(20,0,-20)},false); p.linear=true
    local specs=P.parts(p,opts("Wall"))
    assert(#specs==2,"parts "..#specs)
end)
t.check("merge: smooth curves are not merged",function()
    local p=G.path({V(0,0,0),V(10,0,-10),V(20,0,0)},true)
    local o=opts("Wall")
    local merged=P.parts(p,o)
    assert(#merged>10,"curve parts "..#merged)
end)
t.check("merge: rail sides stay separate",function()
    local specs=P.parts(straight(20),opts("Rail"))
    local feet={}
    for _,s in ipairs(specs) do if s.name=="RailFoot" then feet[#feet+1]=s.cf.Position.X end end
    table.sort(feet)
    assert(#feet==2); t.close(feet[1],-1.6); t.close(feet[2],1.6)
end)
t.check("pipe: joints only where the pipe bends",function()
    local specs=P.parts(straight(20),opts("Pipe"))
    for _,s in ipairs(specs) do assert(s.name~="Joint","joint on a straight pipe") end
    local p=G.path({V(0,0,0),V(0,0,-10),V(10,0,-10)},false); p.linear=true
    local joints=0
    for _,s in ipairs(P.parts(p,opts("Pipe",{step=2}))) do if s.name=="Joint" then joints+=1 end end
    assert(joints==1,"joints "..joints)
end)
t.check("chunks: split respects triangle and vertex limits and shares boundaries",function()
    local chunks=E.chunks(1000,16,16,true,20000,60000)
    local prev
    for _,c in ipairs(chunks) do
        local tris=(c.last-c.first)*16*2+2*14
        assert(tris<=20000,"tris "..tris)
        if prev then assert(c.first==prev.last,"gap between chunks") end
        prev=c
    end
    assert(chunks[1].first==1 and chunks[#chunks].last==1000 and #chunks==2,"#chunks "..#chunks)
    t.fails(function() E.chunks(10,12000,12000,true,20000,60000) end,"Profile too detailed")
end)
t.check("extrude: short sweep is one mesh with caps",function()
    meshes={}
    local parts,ms=E.build(straight(20),opts("Extrude",{step=5}),nil,true,always,nil)
    assert(#parts==1 and #ms==1 and parts[1].Name=="ExtrudedMesh")
    -- 5 rings x 4 sides, 4 spans x 4 sides x 2 + 2 caps x 2 triangles.
    assert(#ms[1].v==20 and ms[1].tris==36,#ms[1].v.." "..ms[1].tris)
end)
t.check("extrude: long sweep is chunked; caps only at the ends",function()
    meshes={}
    local o=opts("Extrude",{profile="circle",sides=64,step=0.5,width=4,height=4})
    local path=straight(400)
    local plan=E.plan(path,o)
    assert(#plan.chunks>=2,"expected chunks, got "..#plan.chunks)
    local parts,ms=E.build(path,o,nil,true,always,nil)
    assert(#parts==#plan.chunks and #ms==#parts)
    local total=0
    for i,m in ipairs(ms) do
        assert(m.tris<=20000 and #m.v<=60000,"chunk too big")
        total+=m.tris
        assert(parts[i].Name==("ExtrudedMesh_%02d"):format(i))
    end
    assert(total==plan.triangles,total.." vs "..plan.triangles)
    -- Seam: last ring of chunk 1 equals first ring of chunk 2 in world space
    -- (vertices are stored relative to each chunk's first sample).
    local c1,c2=plan.chunks[1],plan.chunks[2]
    local a1,a2=G.at(path,plan.samples[c1.first]),G.at(path,plan.samples[c2.first])
    local rings1=c1.last-c1.first+1
    for j=1,64 do
        local p1=ms[1].v[(rings1-1)*64+j]+a1
        local p2=ms[2].v[j]+a2
        t.close((p1-p2).Magnitude,0,1e-6,"seam vertex "..j)
    end
end)
t.check("extrude: failure in a later chunk destroys earlier chunks",function()
    meshes={}
    local calls=0
    local o=opts("Extrude",{profile="circle",sides=64,step=0.5,width=4,height=4})
    local ok=pcall(E.build,straight(400),o,nil,true,function() calls+=1; return calls<2 end,nil)
    assert(not ok)
    for _,m in ipairs(meshes) do assert(m.destroyed,"mesh leaked") end
end)
t.check("builder: chunked extrude counts every chunk against the budget",function()
    meshes={}
    local o=opts("Extrude",{profile="circle",sides=64,step=0.5,width=4,height=4})
    local entry={o=o,styles={},enabled=true}
    local out,count,ms=B.stack(straight(400),{entry},{preview=true,canContinue=always})
    assert(count==#ms and count>=2 and #out:FindFirstChild("G01_Extrude"):GetChildren()==count)
    t.fails(function() B.stack(straight(400),{entry},{preview=true,canContinue=always,budget=1}) end,"No budget left")
end)
t.check("cache: memo reuses results and evicts the oldest",function()
    local c=Cache.new(2)
    local n=0
    local function f() n+=1; return {n} end
    local a=c:memo("a",f); assert(c:memo("a",f)==a and n==1)
    c:memo("b",f); c:memo("c",f)
    assert(c:get("a")==nil and c:get("c")~=nil,"LRU eviction")
    t.fails(function() c:memo("d",function() error("boom") end) end,"boom")
    assert(c:get("d")==nil,"errors must not be cached")
end)
t.check("cache: builder reuses part specs for an unchanged path",function()
    local path=straight(20); path.key="k1"
    local cache=Cache.new(4)
    local e={o=opts("Rail"),styles={},enabled=true}
    B.stack(path,{e},{preview=true,cache=cache})
    B.stack(path,{e},{preview=true,cache=cache})
    assert(cache.hits==1 and cache.misses==1,cache.hits.."/"..cache.misses)
    e.o.width=4
    B.stack(path,{e},{preview=true,cache=cache})
    assert(cache.misses==2,"changed options must miss")
end)
t.check("cache: points key changes when any coordinate changes",function()
    local k1=Cache.pointsKey({V(0,0,0),V(1,2,3)},true)
    assert(k1==Cache.pointsKey({V(0,0,0),V(1,2,3)},true))
    assert(k1~=Cache.pointsKey({V(0,0,0),V(1,2,3.001)},true))
    assert(k1~=Cache.pointsKey({V(0,0,0),V(1,2,3)},false))
end)
game,Content=savedGame,savedContent
return t.finish()
