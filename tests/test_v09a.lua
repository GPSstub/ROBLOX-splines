-- v0.9a: projection, branch snapping, crossings, junction pads and road cuts.
local t=require('harness').new()
local G=require('Geometry')
local N=require('Network')
local P=require('Presets')
local B=require('Builder')
local V=Vector3.new
local function line(a,b) local p=G.path({a,b},false); p.linear=true; return p end

t.check("project: nearest point and distance along the path",function()
    local p=line(V(0,0,0),V(0,0,-20))
    local d,q,gap=N.project(p,V(3,0,-5))
    t.close(d,5); t.close(q.X,0); t.close(gap,3)
    d=N.project(p,V(0,0,10)); t.close(d,0,1e-6,"clamped to start")
end)
t.check("snap: ends within the radius move onto the other path",function()
    local main=line(V(-20,0,0),V(20,0,0))
    local pts,n=N.snapEnds({V(2,0,-3),V(5,0,-30)},{main},4)
    assert(n==1); t.close(pts[1].Z,0); t.close(pts[1].X,2); t.close(pts[2].Z,-30)
    local _,none=N.snapEnds({V(2,0,-10),V(5,0,-30)},{main},4)
    assert(none==0)
end)
t.check("crossings: X crossing found once at the right place",function()
    local a=line(V(-20,0,0),V(20,0,0))
    local b=line(V(5,0,-20),V(5,0,20))
    local c=N.crossings(a,b)
    assert(#c==1,"count "..#c); t.close(c[1].da,25); t.close(c[1].db,20); t.close(c[1].position.X,5)
end)
t.check("crossings: parallel and far-above paths do not cross",function()
    local a=line(V(-20,0,0),V(20,0,0))
    assert(#N.crossings(a,line(V(-20,0,5),V(20,0,5)))==0,"parallel")
    assert(#N.crossings(a,line(V(0,10,-20),V(0,10,20)))==0,"bridge")
end)
t.check("crossings: snapped branch end is a T junction",function()
    local main=line(V(-20,0,0),V(20,0,0))
    local pts=N.snapEnds({V(0,0,-2),V(0,0,-30)},{main},4)
    local branch=line(pts[1],pts[2])
    local c=N.crossings(branch,main)
    assert(#c==1 and c[1].da<0.01,"T junction "..#c)
end)
t.check("crossings: smooth curve crossing a road twice",function()
    local road=line(V(-30,0,0),V(30,0,0))
    local s=G.path({V(-20,0,10),V(0,0,-10),V(20,0,10)},true)
    assert(#N.crossings(s,road)==2)
end)
t.check("junctions: pad size grows for narrow angles and is capped",function()
    local a=line(V(-30,0,0),V(30,0,0))
    local square=N.junctions(a,8,{{path=line(V(0,0,-30),V(0,0,30)),width=12}})
    t.close(square[1].size.X,12); t.close(square[1].size.Z,12,1e-3)
    local narrow=N.junctions(a,8,{{path=line(V(-30,0,-1),V(30,0,1)),width=8}})
    t.close(narrow[1].size.Z,24,1e-3,"capped at 3x")
end)
t.check("road: junction cut leaves a gap exactly at the pad",function()
    local a=line(V(-20,0,0),V(20,0,0))
    local js=N.junctions(a,12,{{path=line(V(0,0,-20),V(0,0,20)),width=12}})
    local o=P.options("Road"); o.cuts=N.cuts(js,a.length)
    local surface={}
    for _,s in ipairs(P.parts(a,o)) do if s.name=="RoadSurface" then surface[#surface+1]=s end end
    assert(#surface==2,"surface pieces "..#surface)
    -- Pieces end where the pad (x = -6..6) begins, plus the usual end overlap.
    local ends={}
    for _,s in ipairs(surface) do ends[#ends+1]=s.cf.Position.X+(s.size.Z/2)*(s.cf.Position.X<0 and 1 or -1) end
    table.sort(ends); t.close(ends[1],-6+0.06,1e-3); t.close(ends[2],6-0.06,1e-3)
end)
t.check("builder: roads get a junction pad; other generators are untouched",function()
    local a=line(V(-20,0,0),V(20,0,0))
    local js=N.junctions(a,12,{{path=line(V(0,0,-20),V(0,0,20)),width=12}})
    local road={o=P.options("Road"),styles={},enabled=true}
    local wall={o=P.options("Wall"),styles={},enabled=true}
    local entries={road,wall}
    local out=B.stack(a,entries,{preview=true,junctions=js})
    local pads=out:FindFirstChild("Junctions"):GetChildren()
    assert(#pads==1 and pads[1].Name=="Junction")
    t.close(pads[1].Position.Y+pads[1].Size.Y/2,0.01,1e-4,"pad top on road surface")
    assert(#out:FindFirstChild("G02_Wall"):GetChildren()==1,"wall must not be cut")
    assert(entries[1]==road and road.o.cuts==nil,"caller's entries changed")
end)
t.check("road plan: three roads share one pad when they meet at one point",function()
    local roads={
        {path=line(V(-30,0,0),V(30,0,0)),width=12},
        {path=line(V(0,0,-30),V(0,0,30)),width=12},
        {path=line(V(-30,0,-30),V(30,0,30)),width=12},
    }
    local draft,updates=N.planRoads(roads,1,nil,true)
    assert(#draft.junctions==1 and #draft.pads==0)
    assert(#updates==2 and #updates[1].junctions==1 and #updates[2].junctions==1)
    assert(#updates[1].pads==0 and #updates[2].pads==1,"expected one shared junction pad")
end)
t.check("road plan: moving a road away restores the old neighbor's surface",function()
    local fixed={path=line(V(-30,0,0),V(30,0,0)),width=12}
    local old={path=line(V(0,0,-30),V(0,0,30)),width=12}
    local moved={path=line(V(50,0,-30),V(50,0,30)),width=12}
    local draft,updates=N.planRoads({fixed,moved},2,old,true)
    assert(#draft.junctions==0 and #draft.pads==0)
    assert(#updates==1 and updates[1].road==fixed and #updates[1].junctions==0)
end)
return t.finish()
