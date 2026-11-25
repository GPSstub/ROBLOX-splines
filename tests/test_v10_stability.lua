-- v1.0 stability: randomized paths through every module (fixed seeds, so
-- failures repeat), old save formats, and worst-case sizes.
local t=require('harness').new()
local G=require('Geometry')
local P=require('Presets')
local E=require('Extrude')
local B=require('Builder')
local N=require('Network')
local S=require('Scatter')
local Persist=require('Persist')
local V=Vector3.new
local function finite(v) return v.X==v.X and v.Y==v.Y and v.Z==v.Z and math.abs(v.X)<1e7 and math.abs(v.Y)<1e7 and math.abs(v.Z)<1e7 end
local function randomPoints(rng,n,spread)
    local pts={}
    for i=1,n do pts[i]=V((rng()-0.5)*spread,(rng()-0.5)*spread*0.3,(rng()-0.5)*spread) end
    return pts
end
-- Errors a user can cause with bad input are fine; anything else is a bug.
local EXPECTED={"Too many","budget","must be","Path is too short","Add at least two","Profile"}
local function expected(err)
    for _,e in ipairs(EXPECTED) do if tostring(err):find(e,1,true) then return true end end
    return false
end

t.check("fuzz: 200 random paths give finite, orthonormal frames",function()
    local rng=S.rng(11)
    for _=1,200 do
        local pts=randomPoints(rng,2+math.floor(rng()*10),200)
        local smooth=rng()<0.5
        local ok,p=pcall(G.path,pts,smooth)
        if ok then
            for i=0,20 do
                local pos,f,r,u=G.frame(p,p.length*i/20)
                assert(finite(pos) and finite(f) and finite(r) and finite(u),"NaN frame")
                assert(math.abs(f.Magnitude-1)<1e-3 and math.abs(f:Dot(r))<1e-3 and math.abs(r:Dot(u))<1e-3,"frame not orthonormal")
            end
        else assert(expected(p),p) end
    end
end)
t.check("fuzz: every generator on random paths fails cleanly or builds finite parts",function()
    local rng=S.rng(23)
    for k=1,60 do
        local p=G.path(randomPoints(rng,3+k%6,150),k%2==0); p.linear=k%2==1
        for name in pairs(P.PART_BASED) do
            local o=P.options(name); o.step=0.5+rng()*4; o.width=0.5+rng()*20
            local ok,specs=pcall(P.parts,p,o)
            if ok then
                for _,s in ipairs(specs) do assert(finite(s.cf.Position) and s.size.Z==s.size.Z and s.size.Z>0,name.." bad part") end
            else assert(expected(specs),specs) end
        end
        local o=P.options("Extrude"); o.profile=({"rectangle","circle","arch"})[k%3+1]
        local ok,plan=pcall(E.plan,p,o)
        if ok then assert(#plan.chunks>=1 and plan.chunks[#plan.chunks].last==#plan.samples) else assert(expected(plan),plan) end
    end
end)
t.check("fuzz: crossings and scatter on random paths stay finite",function()
    local rng=S.rng(37)
    for _=1,40 do
        local a=G.path(randomPoints(rng,4,100),true)
        local b=G.path(randomPoints(rng,4,100),false)
        for _,c in ipairs(N.crossings(a,b,1000)) do assert(finite(c.position) and c.da>=-1e-6 and c.da<=a.length+1e-6) end
        for _,it in ipairs(S.along(a,{band=10,gap=2,density=0.5,minDistance=2,scaleMin=1,scaleMax=1,seed=3})) do assert(finite(it.position)) end
    end
end)
t.check("worst case: 128-point path stays within part budget or fails clearly",function()
    local pts={}
    for i=1,128 do pts[i]=V(i*8,math.sin(i)*3,math.cos(i/5)*40) end
    local p=G.path(pts,true)
    local entries={}
    for i,name in ipairs({"Road","Wall","Fence","Rail"}) do entries[i]={o=P.options(name),styles={},enabled=true} end
    local ok,err=pcall(B.stack,p,entries,{preview=true})
    assert(ok or tostring(err):find("budget",1,true),tostring(err))
end)
-- Old saves --------------------------------------------------------------------
local function legacyMeta(attrs,points)
    local meta=Instance.new("Folder")
    for k,v in pairs(attrs) do meta:SetAttribute(k,v) end
    meta:SetAttribute("PointCount",#points)
    for i,p in ipairs(points) do local v=Instance.new("Vector3Value"); v.Name=("P%03d"):format(i); v.Value=p; v.Parent=meta end
    return meta
end
t.check("migration: v0.1 world-space save (no CoordinateSpace)",function()
    local meta=legacyMeta({preset="Rail",width=3.2,height=0.2,spacing=1.8,step=1,smooth=true,collide=true},{V(100,0,0),V(100,0,-50)})
    local state=Persist.read(meta,CFrame.new(5,5,5))
    assert(state.points[1]==V(100,0,0),"world points must not move")
    assert(state.entries[1].o.preset=="Rail" and state.junctions==false)
end)
t.check("migration: v0.2 save with offset/yaw/roll and Custom asset ref",function()
    local meta=legacyMeta({preset="Custom",width=1,height=0,spacing=6,step=2,offset=1,yaw=90,roll=0,smooth=false,collide=false,CoordinateSpace="Local"},{V(0,0,0),V(10,0,0)})
    local asset=Instance.new("Part")
    local ref=Instance.new("ObjectValue"); ref.Name="Asset"; ref.Value=asset; ref.Parent=meta
    local state=Persist.read(meta,CFrame.new(0,0,0))
    local e=state.entries[1]
    assert(e.source==asset and e.o.spacing==6 and e.o.yaw==90 and e.o.collide==false and state.smooth==false)
end)
t.check("migration: v0.5 save with repeat layers",function()
    local meta=legacyMeta({preset="Fence",width=0.3,height=4,spacing=5,step=2,smooth=true,collide=true,CoordinateSpace="Local"},{V(0,0,0),V(0,0,-30)})
    local folder=Instance.new("Folder"); folder.Name="RepeatLayers"; folder.Parent=meta
    local ref=Instance.new("ObjectValue"); ref.Name="L01"; ref.Value=Instance.new("Part"); ref.Parent=folder
    for k,v in pairs({spacing=10,side=3,height=0,yaw=0,roll=0,enabled=true,collide=true}) do ref:SetAttribute(k,v) end
    local state=Persist.read(meta,CFrame.new(0,0,0))
    assert(#state.layers==1 and state.layers[1].spacing==10 and state.layers[1].side==3)
end)
t.check("migration: out-of-range old values fall back to defaults",function()
    local meta=legacyMeta({preset="Extrude",width=6,height=1,spacing=5,step=2,sides=999,tolerance=-1,fidelity="Bogus",CoordinateSpace="Local"},{V(0,0,0),V(0,0,-30)})
    local o=Persist.read(meta,CFrame.new(0,0,0)).entries[1].o
    assert(o.sides==16 and o.tolerance==0.05 and o.fidelity=="Default")
end)
return t.finish()
