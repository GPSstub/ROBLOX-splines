-- v0.6: JSON codec, part-based presets, generator stack building and saved data.
local t=require('harness').new()
local G=require('Geometry')
local P=require('Presets')
local J=require('Json')
local B=require('Builder')
local S=require('Persist')
local A=require('Assets')
local V=Vector3.new

local function entry(preset,patch)
    local o=P.options(preset)
    for k,v in pairs(patch or {}) do o[k]=v end
    return {o=o,styles={},enabled=true}
end
local function straight(len) return G.path({V(0,0,0),V(0,0,-len)},false) end

t.check("json: round trip keeps values and sorts keys",function()
    local v={b=1,a={1,2.5,"x\n\"y\""},c=true,d={}}
    local s=J.encode(v)
    assert(s=='{"a":[1,2.5,"x\\n\\"y\\""],"b":1,"c":true,"d":[]}',s)
    local back=J.decode(s)
    assert(back.b==1 and back.a[2]==2.5 and back.a[3]=='x\n"y"' and back.c==true)
end)
t.check("json: reads HttpService style text with spaces and unicode",function()
    local v=J.decode(' { "RailFoot" : {"material":"Metal","color":[0.5,0.25,1e-1],"textures":[]}, "k":"\\u00e9" } ')
    t.close(v.RailFoot.color[3],0.1); assert(v.k=="é")
end)
t.check("json: rejects broken text and NaN",function()
    t.fails(function() J.decode('{"a":1') end)
    t.fails(function() J.decode('[1,2] x') end)
    t.fails(function() J.encode({0/0}) end)
end)
t.check("presets: rail on a 20 stud straight path",function()
    local specs=P.parts(straight(20),P.options("Rail"))
    local n={}
    for _,s in ipairs(specs) do n[s.name]=(n[s.name] or 0)+1 end
    -- Straight path: each rail side merges into one foot and one head; sleepers every 1.8 studs -> 12.
    assert(n.RailFoot==2 and n.RailHead==2 and n.Sleeper==12,("%d %d %d"):format(n.RailFoot,n.RailHead,n.Sleeper))
end)
t.check("presets: every part-based preset builds on a curve",function()
    local p=G.path({V(0,0,0),V(10,0,-10),V(20,5,0)},true)
    for name in pairs(P.PART_BASED) do
        local specs=P.parts(p,P.options(name))
        assert(#specs>0,name)
        for _,s in ipairs(specs) do assert(s.size.X>0 and s.size.Z>0 and s.cf.Position.X==s.cf.Position.X,name.." bad spec") end
    end
end)
t.check("presets: invalid options are rejected",function()
    local o=P.options("Wall"); o.width=0
    t.fails(function() P.validate(o) end,"width must be between")
    o=P.options("Road"); o.height=0
    t.fails(function() P.parts(straight(10),o) end,"Height must be positive")
    t.fails(function() P.options("Bridge") end,"Unknown preset")
end)
t.check("presets: part budget is enforced",function()
    t.fails(function() P.parts(straight(200),P.options("Rail"),50) end,"Part budget exceeded (50)")
end)
t.check("builder: stack builds each enabled generator into its own folder",function()
    local entries={entry("Rail"),entry("Wall",{width=1}),entry("Fence")}
    entries[3].enabled=false
    local out,count=B.stack(straight(20),entries,{preview=false,allowUpload=false,canContinue=function() return true end})
    local names={}
    for _,c in ipairs(out:GetChildren()) do names[#names+1]=c.Name end
    table.sort(names)
    assert(table.concat(names,",")=="G01_Rail,G02_Wall",table.concat(names,","))
    local total=0
    for _,c in ipairs(out:GetDescendants()) do if c:IsA("BasePart") then total+=1 end end
    assert(total==count and count==16+1,"count "..count)
end)
t.check("builder: material slot style is applied to matching parts",function()
    local e=entry("Wall")
    e.styles.Wall={material="Brick",variant="",color={1,0,0},transparency=0,reflectance=0,textures={}}
    local out=B.stack(straight(10),{e},{preview=true})
    local part=out:FindFirstChild("G01_Wall"):GetChildren()[1]
    assert(part.Material.Name=="Brick" and part.Color.R==1)
    assert(part.CanCollide==false and part.Archivable==false,"preview parts must not collide or save")
end)
t.check("builder: mesh generator needs authorization and nothing is left behind",function()
    local entries={entry("Rail"),entry("Extrude")}
    local ok,err=pcall(B.stack,straight(10),entries,{preview=false,allowUpload=false,canContinue=function() return true end})
    assert(not ok and tostring(err):find("Authorize mesh uploads",1,true),tostring(err))
end)
t.check("builder: custom generator clones the source and strips scripts",function()
    local m=Instance.new("Model"); m.Name="Lamp"
    local p=Instance.new("Part",m); p.Name="Pole"
    Instance.new("Script",m)
    local e=entry("Custom",{spacing=5}); e.source=m
    local out,count=B.stack(straight(10),{e},{preview=false})
    local clones=out:FindFirstChild("G01_Custom"):GetChildren()
    assert(#clones==3 and count==3,"clones "..#clones)
    assert(clones[1]:FindFirstChildWhichIsA("Script")==nil,"script kept")
    t.close(clones[2]:FindFirstChild("Pole").Position.Z,-5)
end)
t.check("builder: combined budget is enforced across generators",function()
    t.fails(function() B.stack(straight(40),{entry("Rail"),entry("Rail")},{preview=true,budget=200}) end,"Part budget exceeded")
end)
t.check("assets: invalid sources are rejected",function()
    t.fails(function() A.count(nil) end,"Select a Model or BasePart")
    t.fails(function() A.count(Instance.new("Model")) end,"Asset contains no BaseParts")
end)
t.check("persist: format 2 round trip with moved pivot",function()
    local pivot=CFrame.new(10,0,5)*CFrame.Angles(0,math.rad(90),0)
    local pts={V(10,0,5),V(20,1,5),V(30,0,-5)}
    local src=Instance.new("Part"); src.Name="Src"
    local e1=entry("Road",{width=8}); e1.styles.RoadSurface={material="Slate",color={0,0,0},textures={}}
    local e2=entry("Custom"); e2.source=src; e2.enabled=false
    local meta=Instance.new("Folder")
    S.write(meta,{points=pts,smooth=true,entries={e1,e2},layers={}},pivot)
    local state=S.read(meta,pivot)
    assert(#state.points==3 and state.smooth==true and #state.entries==2)
    for i=1,3 do t.close((state.points[i]-pts[i]).Magnitude,0,1e-6,"point "..i) end
    assert(state.entries[1].o.preset=="Road" and state.entries[1].o.width==8)
    assert(state.entries[1].styles.RoadSurface.material=="Slate")
    assert(state.entries[2].source==src and state.entries[2].enabled==false)
    -- Moving the model moves the loaded points with it.
    local moved=CFrame.new(0,50,0)*pivot
    local again=S.read(meta,moved)
    t.close(again.points[1].Y,50)
end)
t.check("persist: reads v0.5 single-generator saves",function()
    local meta=Instance.new("Folder")
    for k,v in pairs({preset="Extrude",width=6,height=1,spacing=5,step=2,offset=0,yaw=0,roll=0,profile="circle",sides=12,
        materialStyles='{"ExtrudedMesh":{"material":"Metal","color":[1,1,1],"textures":[]}}',smooth=false,collide=true,fidelity="Hull",
        PointCount=2,CoordinateSpace="Local"}) do meta:SetAttribute(k,v) end
    for i,p in ipairs({V(0,0,0),V(0,0,-10)}) do local v=Instance.new("Vector3Value"); v.Name=("P%03d"):format(i); v.Value=p; v.Parent=meta end
    local state=S.read(meta,CFrame.new(0,0,0))
    local o=state.entries[1].o
    assert(#state.entries==1 and o.preset=="Extrude" and o.profile=="circle" and o.sides==12 and o.fidelity=="Hull")
    assert(o.uvLength==4 and o.angle==8,"missing v0.3 fields use defaults")
    assert(state.entries[1].styles.ExtrudedMesh.material=="Metal" and state.smooth==false)
end)
t.check("persist: damaged saves fail clearly",function()
    local meta=Instance.new("Folder"); meta:SetAttribute("PointCount",3)
    t.fails(function() S.read(meta,CFrame.new(0,0,0)) end,"Missing control point")
    meta:SetAttribute("PointCount",1)
    t.fails(function() S.read(meta,CFrame.new(0,0,0)) end,"Invalid saved point count")
end)
return t.finish()
