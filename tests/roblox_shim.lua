-- Minimal Roblox datatype shims (Vector3, Vector2, CFrame) and Luau stdlib extras,
-- enough to run PathForge's pure-geometry modules outside Studio.
local sqrt=math.sqrt
math.clamp=math.clamp or function(x,a,b) if x<a then return a elseif x>b then return b end return x end
table.find=table.find or function(t,v,init) for i=init or 1,#t do if t[i]==v then return i end end return nil end

local V3={}; V3.__index=function(v,k)
    if k=="Magnitude" then return sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)
    elseif k=="Unit" then local m=sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z); return Vector3.new(v.X/m,v.Y/m,v.Z/m) end
    return V3[k]
end
local function v3(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V3) end
V3.__add=function(a,b) return v3(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V3.__sub=function(a,b) return v3(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V3.__unm=function(a) return v3(-a.X,-a.Y,-a.Z) end
V3.__mul=function(a,b)
    if type(a)=="number" then return v3(a*b.X,a*b.Y,a*b.Z) end
    if type(b)=="number" then return v3(a.X*b,a.Y*b,a.Z*b) end
    return v3(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
V3.__div=function(a,b) if type(b)=="number" then return v3(a.X/b,a.Y/b,a.Z/b) end return v3(a.X/b.X,a.Y/b.Y,a.Z/b.Z) end
V3.__eq=function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
V3.__tostring=function(a) return string.format("%g, %g, %g",a.X,a.Y,a.Z) end
function V3.Dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
function V3.Cross(a,b) return v3(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end
Vector3={new=v3,xAxis=v3(1,0,0),yAxis=v3(0,1,0),zAxis=v3(0,0,1),zero=v3(0,0,0)}

local V2={}; V2.__index=function(v,k)
    if k=="Magnitude" then return sqrt(v.X*v.X+v.Y*v.Y)
    elseif k=="Unit" then local m=sqrt(v.X*v.X+v.Y*v.Y); return Vector2.new(v.X/m,v.Y/m) end
    return V2[k]
end
local function v2(x,y) return setmetatable({X=x or 0,Y=y or 0},V2) end
V2.__add=function(a,b) return v2(a.X+b.X,a.Y+b.Y) end
V2.__sub=function(a,b) return v2(a.X-b.X,a.Y-b.Y) end
V2.__unm=function(a) return v2(-a.X,-a.Y) end
V2.__mul=function(a,b) if type(a)=="number" then return v2(a*b.X,a*b.Y) end return v2(a.X*b,a.Y*b) end
V2.__div=function(a,b) return v2(a.X/b,a.Y/b) end
Vector2={new=v2}

-- CFrame stored as position + rotation columns (right, up, back).
local CF={}; CF.__index=function(c,k)
    if k=="LookVector" then return -c.back elseif k=="RightVector" then return c.right
    elseif k=="UpVector" then return c.up end
    return CF[k]
end
local function cf(p,r,u,b) return setmetatable({Position=p,right=r,up=u,back=b},CF) end
local function rot(c,v) return c.right*v.X+c.up*v.Y+c.back*v.Z end
CF.__mul=function(a,b)
    if getmetatable(b)==V3 then return a.Position+rot(a,b) end
    return cf(a.Position+rot(a,b.Position),rot(a,b.right),rot(a,b.up),rot(a,b.back))
end
local I=cf(v3(),v3(1,0,0),v3(0,1,0),v3(0,0,1))
local function axis(m) -- m = rows
    return cf(v3(),v3(m[1][1],m[2][1],m[3][1]),v3(m[1][2],m[2][2],m[3][2]),v3(m[1][3],m[2][3],m[3][3]))
end
CFrame={
    new=function(x,y,z) if getmetatable(x)==V3 then return cf(x,I.right,I.up,I.back) end return cf(v3(x,y,z),I.right,I.up,I.back) end,
    lookAt=function(at,target,up)
        up=up or Vector3.yAxis
        local look=(target-at).Unit
        local right=look:Cross(up).Unit
        local u=right:Cross(look)
        return cf(at,right,u,-look)
    end,
    Angles=function(rx,ry,rz)
        local cx,sx,cy,sy,cz,sz=math.cos(rx),math.sin(rx),math.cos(ry),math.sin(ry),math.cos(rz),math.sin(rz)
        local X=axis{{1,0,0},{0,cx,-sx},{0,sx,cx}}
        local Y=axis{{cy,0,sy},{0,1,0},{-sy,0,cy}}
        local Z=axis{{cz,-sz,0},{sz,cz,0},{0,0,1}}
        return X*Y*Z
    end,
}

-- CFrame helpers used by saved-path conversion.
function CF.Inverse(c)
    -- Rotation is orthonormal: inverse = transpose.
    local r,u,b=c.right,c.up,c.back
    local rt=cf(v3(),v3(r.X,u.X,b.X),v3(r.Y,u.Y,b.Y),v3(r.Z,u.Z,b.Z))
    local p=rot(rt,c.Position)
    return cf(-p,rt.right,rt.up,rt.back)
end
function CF.PointToObjectSpace(c,v) return CF.Inverse(c)*v end
function CF.PointToWorldSpace(c,v) return c*v end
CF.__eq=function(a,b) return a.Position==b.Position and a.right==b.right and a.up==b.up and a.back==b.back end
CFrame.identity=I

-- Luau table / string extras.
table.clone=table.clone or function(t) local c={} for k,v in pairs(t) do c[k]=v end return c end
table.clear=table.clear or function(t) for k in pairs(t) do t[k]=nil end end
table.unpack=table.unpack or unpack

Color3={
    new=function(r,g,b) return {R=r or 0,G=g or 0,B=b or 0} end,
    fromRGB=function(r,g,b) return {R=(r or 0)/255,G=(g or 0)/255,B=(b or 0)/255} end,
}

-- Enum.<Type>.<Item> -> {Name, EnumType}; any name is accepted unless listed in ENUM_KNOWN.
ENUM_KNOWN={Material={Plastic=1,SmoothPlastic=1,Metal=1,Wood=1,WoodPlanks=1,Concrete=1,Asphalt=1,Neon=1,Grass=1,Slate=1,Brick=1,Cobblestone=1,Sand=1,Rock=1,Ground=1,Mud=1,Pavement=1,Granite=1,Marble=1,Glass=1,DiamondPlate=1,CorrodedMetal=1,Foil=1,Fabric=1,Ice=1,LeafyGrass=1,Limestone=1,Salt=1,Sandstone=1,Basalt=1,CrackedLava=1,Glacier=1,Snow=1,Air=1,Water=1,Cardboard=1,Carpet=1,CeramicTiles=1,ClayRoofTiles=1,RoofShingles=1,Leather=1,Plaster=1,Rubber=1}}
Enum=setmetatable({},{__index=function(e,typ)
    local t=setmetatable({},{__index=function(t,name)
        local known=ENUM_KNOWN[typ]
        if known and not known[name] then return nil end
        local item={Name=name,EnumType=typ}; rawset(t,name,item); return item
    end})
    rawset(e,typ,t); return t
end})

-- Minimal Instance tree: properties, attributes, children, Clone and Destroy.
local CLASS_PARENT={Part="BasePart",MeshPart="BasePart",WedgePart="BasePart",BasePart="PVInstance",Model="PVInstance",
    PVInstance="Instance",Folder="Instance",Configuration="Instance",ObjectValue="ValueBase",StringValue="ValueBase",
    Vector3Value="ValueBase",NumberValue="ValueBase",ValueBase="Instance",Texture="Decal",Decal="Instance",
    Script="LuaSourceContainer",LuaSourceContainer="Instance",Weld="JointInstance",JointInstance="Instance",
    Bone="Instance",SurfaceAppearance="Instance"}
local INST={}
-- Signals: Connect/Fire; Instances expose any *signal-like* property lazily.
local SIG={}; SIG.__index=SIG
function SIG.new() return setmetatable({_c={}},SIG) end
function SIG:Connect(fn) local c={Connected=true}; self._c[#self._c+1]={fn=fn,c=c}; function c.Disconnect() c.Connected=false end; return c end
function SIG:Fire(...) for _,x in ipairs(self._c) do if x.c.Connected then x.fn(...) end end end
Signal=SIG
local SIGNAL_NAMES={Activated=1,MouseButton1Down=1,MouseButton1Up=1,MouseDrag=1,Click=1,Changed=1,Move=1,Button1Down=1,Button1Up=1,Heartbeat=1,Deactivation=1,Unloading=1}
local function isA(class,want)
    while class do if class==want then return true end; class=CLASS_PARENT[class] end
    return false
end
local methods={}
function methods:GetPropertyChangedSignal(k)
    local sigs=rawget(self,"_signals"); local key="prop:"..k
    sigs[key]=sigs[key] or SIG.new(); return sigs[key]
end
function methods:IsA(c) return isA(rawget(self,"_class"),c) end
function methods:GetChildren() local o={} for i,c in ipairs(rawget(self,"_children")) do o[i]=c end return o end
function methods:GetDescendants()
    local o={}
    local function walk(x) for _,c in ipairs(rawget(x,"_children")) do o[#o+1]=c; walk(c) end end
    walk(self); return o
end
function methods:FindFirstChild(name) for _,c in ipairs(rawget(self,"_children")) do if c.Name==name then return c end end end
function methods:FindFirstChildWhichIsA(class,recursive)
    for _,c in ipairs(recursive and self:GetDescendants() or self:GetChildren()) do if c:IsA(class) then return c end end
end
function methods:IsDescendantOf(other) local p=self.Parent; while p do if p==other then return true end; p=p.Parent end; return false end
function methods:SetAttribute(k,v) rawget(self,"_attrs")[k]=v end
function methods:GetAttribute(k) return rawget(self,"_attrs")[k] end
function methods:GetAttributes() return table.clone(rawget(self,"_attrs")) end
function methods:Destroy() self.Parent=nil; rawset(self,"_destroyed",true); for _,c in ipairs(self:GetChildren()) do c:Destroy() end end
function methods:Clone()
    if rawget(self,"_props").Archivable==false then return nil end
    local c=Instance.new(rawget(self,"_class"))
    for k,v in pairs(rawget(self,"_props")) do if k~="Parent" then rawget(c,"_props")[k]=v end end
    for k,v in pairs(rawget(self,"_attrs")) do rawget(c,"_attrs")[k]=v end
    for _,child in ipairs(self:GetChildren()) do local cc=child:Clone(); if cc then cc.Parent=c end end
    return c
end
function methods:GetPivot()
    local p=rawget(self,"_props")
    if p.CFrame then return p.CFrame end
    return p.WorldPivot or CFrame.identity
end
function methods:PivotTo(cf)
    local old=self:GetPivot()
    local delta=cf*CF.Inverse(old)
    local p=rawget(self,"_props")
    if p.CFrame then p.CFrame=cf else p.WorldPivot=cf end
    for _,d in ipairs(self:GetDescendants()) do
        local dp=rawget(d,"_props")
        if dp.CFrame then dp.CFrame=delta*dp.CFrame end
    end
end
INST.__index=function(o,k)
    if methods[k] then return methods[k] end
    if k=="ClassName" then return rawget(o,"_class") end
    local v=rawget(o,"_props")[k]
    if v==nil and SIGNAL_NAMES[k] then local sigs=rawget(o,"_signals"); sigs[k]=sigs[k] or SIG.new(); return sigs[k] end
    if v==nil and k=="Archivable" then return true end
    if v==nil and k=="Position" and rawget(o,"_props").CFrame then return rawget(o,"_props").CFrame.Position end
    return v
end
INST.__newindex=function(o,k,v)
    local props=rawget(o,"_props")
    if k=="Parent" then
        local old=props.Parent
        if old then local list=rawget(old,"_children"); for i=#list,1,-1 do if list[i]==o then table.remove(list,i) end end end
        if v then local list=rawget(v,"_children"); list[#list+1]=o end
        props.Parent=v
    elseif k=="Position" and props.CFrame then
        props.CFrame=CFrame.new(v)
    else
        local changed=props[k]~=v
        props[k]=v
        local sig=rawget(o,"_signals")["prop:"..k]
        if changed and sig then sig:Fire() end
    end
end
INST.__tostring=function(o) return rawget(o,"_props").Name or rawget(o,"_class") end
Instance={new=function(class,parent)
    local o=setmetatable({_class=class,_props={Name=class},_attrs={},_children={},_signals={}},INST)
    if isA(class,"BasePart") then rawget(o,"_props").CFrame=CFrame.identity; rawget(o,"_props").Size=v3(4,1,2) end
    if parent then o.Parent=parent end
    return o
end}
function typeof(v)
    local mt=getmetatable(v)
    if mt==INST then return "Instance" elseif mt==V3 then return "Vector3" elseif mt==CF then return "CFrame" elseif mt==V2 then return "Vector2" end
    return type(v)
end
