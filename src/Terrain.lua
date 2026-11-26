-- Terrain-aware paths: draping points onto the ground, and planning terrain
-- fill (support under the path) and carve (clear space above it).
-- Pure planning; the plugin applies blocks with Terrain:FillBlock.
local G=require(script.Parent.Geometry)
local T={MAX_BLOCKS=2000,MAX_PREVIEW_BLOCKS=400,MAX_VOLUME=64000000}
T.MATERIALS={"Ground","Grass","Rock","Asphalt","Sand","Mud","Slate","Concrete"}

-- heightAt(x, z) -> ground Y or nil. Points without ground keep their height.
function T.drape(points,heightAt,offset)
    local out,hit={},0
    for i,p in ipairs(points) do
        local y=heightAt(p.X,p.Z)
        if y then out[i]=Vector3.new(p.X,y+offset,p.Z); hit+=1 else out[i]=p end
    end
    return out,hit
end

-- Resamples the path every `spacing` studs (keeping both ends) and drapes the
-- new points, so the path follows hills between the original points.
function T.resample(path,spacing,heightAt,offset,maxPoints)
    assert(spacing>0,"Resample spacing must be positive")
    local n=math.max(1,math.ceil(path.length/spacing))
    assert(n+1<=maxPoints,"Too many points: increase resample spacing")
    local pts={}
    for i=0,n do pts[#pts+1]=G.at(path,path.length*i/n) end
    function T.checkBudget(plan)
    assert(#plan.fill+#plan.carve<=T.MAX_PREVIEW_BLOCKS,"Terrain edit exceeds 400 blocks; split the path")
    local volume=0
    for _,group in ipairs({plan.fill,plan.carve}) do
        for _,b in ipairs(group) do volume+=b.size.X*b.size.Y*b.size.Z end
    end
    assert(volume<=T.MAX_VOLUME,"Terrain edit volume too large; split the path")
    return volume
end
return T.drape(pts,heightAt,offset)
end

-- Plans terrain blocks along the path. o = {width, shoulder, depth, clear, step, offset, sink}.
-- The fill top sits `sink` studs below the path so terrain does not poke through roads.
-- Each block follows the path frame; fill sits below the path surface,
-- carve (air) above it. Returns {fill={...}, carve={...}} of {cf, size}.
function T.plan(path,o)
    assert(o.width>0 and o.depth>=0 and o.clear>=0,"Invalid terrain settings")
    local ds=G.segments(path,o.step,T.MAX_BLOCKS)
    local fill,carve={},{}
    local w=o.width+2*o.shoulder
    for i=1,#ds-1 do
        local a,_,_,ua=G.frame(path,ds[i]); local b,_,_,ub=G.frame(path,ds[i+1])
        local up=(ua+ub).Unit
        local len=(b-a).Magnitude
        if len>1e-4 then
            local mid=(a+b)/2+Vector3.new(0,o.offset,0)
            -- Terrain voxels are 4 studs; overlap blocks so curves leave no gaps.
            local along=len+2
            local look=CFrame.lookAt(mid,mid+(b-a),up)
            if o.depth>0 then fill[#fill+1]={cf=look*CFrame.new(0,-(o.sink or 0.5)-o.depth/2,0),size=Vector3.new(w,o.depth,along)} end
            if o.clear>0 then carve[#carve+1]={cf=look*CFrame.new(0,o.clear/2,0),size=Vector3.new(w,o.clear,along)} end
        end
    end
    return {fill=fill,carve=carve}
end
return T
