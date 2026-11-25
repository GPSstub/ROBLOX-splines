-- Built-in generators. Part-based generators return plain part specs
-- ({name, cf, size, material, color, shape}) so they can be tested and
-- previewed without creating Instances.
local G=require(script.Parent.Geometry)
local P={}
P.LIST={"Rail","Road","Wall","Fence","Pipe","Custom","Deform","Extrude"}
P.MESH={Deform=true,Extrude=true}
P.PART_BASED={Rail=true,Road=true,Wall=true,Fence=true,Pipe=true}
P.DEFAULTS={
    Rail={width=3.2,height=0.2,spacing=1.8,step=1},
    Road={width=12,height=0.35,spacing=8,step=2},
    Wall={width=0.8,height=8,spacing=5,step=2},
    Fence={width=0.3,height=4,spacing=5,step=2},
    Pipe={width=1.4,height=1.5,spacing=8,step=1},
    Custom={width=1,height=0,spacing=5,step=2},
    Deform={width=1,height=0,spacing=5,step=2},
    Extrude={width=6,height=1,spacing=5,step=2},
}
-- Material slot names each generator can produce, for the material slot picker.
P.SLOTS={
    Rail={"RailFoot","RailHead","Sleeper"},
    Road={"RoadSurface","EdgeLine","CenterMark"},
    Wall={"Wall"},
    Fence={"FenceRail","FencePost"},
    Pipe={"Pipe","Joint"},
    Custom={},
    Deform={},
    Extrude={"ExtrudedMesh"},
}
-- Numeric options shared by every generator: key -> {min, max, default}.
P.NUMBERS={
    width={0.05,100,3.2}, height={-50,100,0.2}, spacing={0.2,200,1.8}, step={0.15,100,1},
    offset={-100,100,0}, yaw={-360,360,0}, roll={-360,360,0},
    sides={3,64,16}, uvLength={0.05,1000,4}, uvWidth={0.05,1000,4},
    angle={1,90,8}, tolerance={0.005,10,0.05},
}
P.FIDELITY={"Default","Box","Hull","PreciseConvexDecomposition"}
local STEEL={103,110,119}
local TIMBER={91,67,46}
local ASPHALT={54,58,63}
local CONCRETE={129,130,124}
local LINE={220,220,210}
local MARK={233,184,62}

function P.isPreset(name) return table.find(P.LIST,name)~=nil end

-- Default option table for a preset (used for new generators and old saves).
function P.options(preset)
    assert(P.isPreset(preset),"Unknown preset")
    local o={preset=preset,profile="rectangle",fidelity="Default",collide=true}
    for k,spec in pairs(P.NUMBERS) do o[k]=spec[3] end
    for k,v in pairs(P.DEFAULTS[preset]) do o[k]=v end
    return o
end

-- Validates and normalizes an option table in place; returns it.
function P.validate(o)
    assert(type(o)=="table","Invalid generator options")
    assert(P.isPreset(o.preset),"Unknown preset")
    for k,spec in pairs(P.NUMBERS) do
        local v=o[k]
        assert(type(v)=="number" and v==v and v>=spec[1] and v<=spec[2],k.." must be between "..spec[1].." and "..spec[2])
    end
    o.sides=math.floor(o.sides)
    assert(type(o.profile)=="string" and #o.profile<=2000,"Invalid profile text")
    assert(table.find(P.FIDELITY,o.fidelity),"Invalid collision fidelity")
    assert(type(o.collide)=="boolean","Invalid collision switch")
    return o
end

local function axisCF(a,b,up)
    local v=b-a
    if v.Magnitude<1e-5 then return nil,0 end
    if math.abs(v.Unit:Dot(up))>0.995 then up=Vector3.new(0,0,1); if math.abs(v.Unit:Dot(up))>0.995 then up=Vector3.new(1,0,0) end end
    return CFrame.lookAt((a+b)/2,b,up),v.Magnitude
end
P.axisCF=axisCF

-- Returns an array of part specs for a part-based preset.
function P.parts(path,o,limit,shown)
    assert(P.PART_BASED[o.preset],"Not a part-based generator")
    limit=limit or 6500; shown=shown or limit
    local specs={}
    local function add(name,cf,size,material,color,shape)
        assert(#specs<limit,"Part budget exceeded ("..shown..")")
        specs[#specs+1]={name=name,cf=cf,size=size,material=material,color=color,shape=shape}
    end
    local function frame(d)
        local p,f,r,u=G.frame(path,d); return p+Vector3.new(0,o.offset,0),f,r,u
    end
    local function beam(name,a,b,up,w,h,mat,col,overlap)
        local cf,len=axisCF(a,b,up)
        if cf then add(name,cf,Vector3.new(w,h,len+(overlap or 0)),mat,col) end
    end
    if o.preset=="Wall" or o.preset=="Fence" or o.preset=="Road" then assert(o.height>0,"Height must be positive for this preset") end
    local ds=G.segments(path,o.step,2000)
    for i=1,#ds-1 do
        local a,_,ra,ua=frame(ds[i]); local b,_,rb,ub=frame(ds[i+1])
        local up=ua+ub; up=up.Magnitude>1e-4 and up.Unit or ua
        if o.preset=="Rail" then
            for _,side in ipairs({-1,1}) do
                local aa=a+ra*o.width/2*side+ua*o.height
                local bb=b+rb*o.width/2*side+ub*o.height
                beam("RailFoot",aa,bb,up,0.30,0.10,"Metal",STEEL,0.06)
                beam("RailHead",aa+ua*0.11,bb+ub*0.11,up,0.13,0.17,"Metal",STEEL,0.06)
            end
        elseif o.preset=="Road" then
            beam("RoadSurface",a-ua*o.height/2,b-ub*o.height/2,up,o.width,o.height,"Asphalt",ASPHALT,0.12)
            for _,side in ipairs({-1,1}) do
                beam("EdgeLine",a+ra*(o.width/2-0.3)*side+ua*0.025,b+rb*(o.width/2-0.3)*side+ub*0.025,up,0.10,0.035,"SmoothPlastic",LINE,0.06)
            end
        elseif o.preset=="Wall" then
            beam("Wall",a+ua*o.height/2,b+ub*o.height/2,up,o.width,o.height,"Concrete",CONCRETE,0.12)
        elseif o.preset=="Fence" then
            for _,h in ipairs({0.38,0.82}) do beam("FenceRail",a+ua*o.height*h,b+ub*o.height*h,up,o.width,0.20,"Wood",TIMBER,0.06) end
        elseif o.preset=="Pipe" then
            local aa=a+ua*o.height; local bb=b+ub*o.height
            local cf,len=axisCF(aa,bb,up)
            if cf then
                add("Pipe",cf*CFrame.Angles(0,math.pi/2,0),Vector3.new(len+0.04,o.width,o.width),"Metal",STEEL,"Cylinder")
                if i>1 then add("Joint",CFrame.new(aa),Vector3.new(o.width,o.width,o.width),"Metal",STEEL,"Ball") end
            end
        end
    end
    if o.preset=="Rail" or o.preset=="Fence" or o.preset=="Road" then
        for _,d in ipairs(G.instances(path,o.spacing,2000)) do
            local p,f,_,u=frame(d); local cf=CFrame.lookAt(p,p+f,u)
            if o.preset=="Rail" then
                add("Sleeper",cf*CFrame.new(0,o.height-0.14,0),Vector3.new(o.width+1.25,0.20,0.40),"Wood",TIMBER)
            elseif o.preset=="Fence" then
                add("FencePost",cf*CFrame.new(0,o.height/2,0),Vector3.new(o.width*1.7,o.height,o.width*1.7),"Wood",TIMBER)
            else
                local len=math.min(2,o.spacing*0.45,path.length)
                if d-len/2>=0 and d+len/2<=path.length then add("CenterMark",cf*CFrame.new(0,0.028,0),Vector3.new(0.15,0.035,len),"SmoothPlastic",MARK) end
            end
        end
    end
    return specs
end
return P
