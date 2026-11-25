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
