-- Path networks: snapping branch ends onto other paths and finding where paths
-- cross, so roads can get a junction pad instead of overlapping surfaces.
local G=require(script.Parent.Geometry)
local N={}
local EPS=1e-6

-- Nearest point on a sampled path. Returns distance along path, position, gap.
function N.project(path,q)
    local ps,ds=path.positions,path.distances
    local best,bestD,bestP=math.huge,0,ps[1]
    for i=1,#ps-1 do
        local a,b=ps[i],ps[i+1]
        local ab=b-a
        local len2=ab:Dot(ab)
        local t=len2>EPS and math.clamp((q-a):Dot(ab)/len2,0,1) or 0
        local p=a+ab*t
        local gap=(q-p).Magnitude
        if gap<best then best=gap; bestP=p; bestD=ds[i]+(ds[i+1]-ds[i])*t end
    end
    return bestD,bestP,best
end

-- Moves the first/last draft point onto the nearest other path within radius.
-- Returns new points and how many ends were snapped.
function N.snapEnds(points,paths,radius)
    assert(radius>0,"Snap radius must be positive")
    local out=table.clone(points)
    local snapped=0
    for _,i in ipairs(#out>=2 and {1,#out} or {}) do
        local bestGap,bestP=radius,nil
        for _,path in ipairs(paths) do
            local _,p,gap=N.project(path,out[i])
            if gap<=bestGap then bestGap=gap; bestP=p end
        end
        if bestP then out[i]=bestP; snapped+=1 end
    end
    return out,snapped
end

-- 2D (XZ) intersection of segments ab and cd; returns ta, tc or nil.
local function cross2(ax,az,bx,bz) return ax*bz-az*bx end
local function intersect(a,b,c,d)
    local rx,rz=b.X-a.X,b.Z-a.Z
    local sx,sz=d.X-c.X,d.Z-c.Z
    local den=cross2(rx,rz,sx,sz)
    if math.abs(den)<EPS then return nil end
    local qx,qz=c.X-a.X,c.Z-a.Z
    local t=cross2(qx,qz,sx,sz)/den
    local u=cross2(qx,qz,rx,rz)/den
    if t<-EPS or t>1+EPS or u<-EPS or u>1+EPS then return nil end
    return t,u
end

local function horizontalBounds(path)
    if path.junctionBounds then return path.junctionBounds end
    local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
    for _,p in ipairs(path.positions) do
        minX,maxX=math.min(minX,p.X),math.max(maxX,p.X)
        minZ,maxZ=math.min(minZ,p.Z),math.max(maxZ,p.Z)
    end
    local bounds={minX=minX,maxX=maxX,minZ=minZ,maxZ=maxZ}
    path.junctionBounds=bounds
    return bounds
end

-- Where path A meets path B in plan view (crossings and T-junction ends).
-- maxGap limits the vertical difference (bridges over roads are not junctions).
-- Returns a list of {da, db, position}, sorted along A, duplicates merged.
function N.crossings(a,b,maxGap)
    maxGap=maxGap or 2
    local x,y=horizontalBounds(a),horizontalBounds(b)
    local tolerance=0.05
    if x.maxX+tolerance<y.minX or y.maxX+tolerance<x.minX
        or x.maxZ+tolerance<y.minZ or y.maxZ+tolerance<x.minZ then return {} end
    local out={}
    local pa,da,pb,db=a.positions,a.distances,b.positions,b.distances
    for i=1,#pa-1 do
        for j=1,#pb-1 do
            local t,u=intersect(pa[i],pa[i+1],pb[j],pb[j+1])
            if t then
                local qa=pa[i]+(pa[i+1]-pa[i])*t
                local qb=pb[j]+(pb[j+1]-pb[j])*u
                if math.abs(qa.Y-qb.Y)<=maxGap then
                    out[#out+1]={da=da[i]+(da[i+1]-da[i])*t,db=db[j]+(db[j+1]-db[j])*u,position=(qa+qb)/2}
                end
            end
        end
    end
    -- Ends of A that touch B (a snapped branch) count even without a strict crossing.
    for _,d in ipairs({0,a.length}) do
        local p=G.at(a,d)
        local dbHit,q,gap=N.project(b,p)
        if gap<=tolerance and math.abs(p.Y-q.Y)<=maxGap then out[#out+1]={da=d,db=dbHit,position=q} end
    end
    for _,d in ipairs({0,b.length}) do
        local p=G.at(b,d)
        local daHit,q,gap=N.project(a,p)
        if gap<=tolerance and math.abs(p.Y-q.Y)<=maxGap then out[#out+1]={da=daHit,db=d,position=q} end
    end
    table.sort(out,function(x,y) return x.da<y.da end)
    local merged={}
    for _,c in ipairs(out) do
        local last=merged[#merged]
        if not last or c.da-last.da>0.5 then merged[#merged+1]=c end
    end
    return merged
end

-- Junction pads for this path against other paths.
-- others: list of {path, width}; width is the other road's width.
-- Returns {d, position, forward, up, size, half} for each junction.
function N.junctions(path,width,others,maxGap)
    local out={}
    for _,other in ipairs(others) do
        for _,c in ipairs(N.crossings(path,other.path,maxGap)) do
            local _,fa,_,ua=G.frame(path,c.da)
            local _,fb=G.frame(other.path,c.db)
            -- Narrow crossing angles need a longer pad; capped at 3x.
            local sin=fa:Cross(fb).Magnitude
            local cos=math.abs(fa:Dot(fb))
            local w=math.max(width,other.width)
            local otherHalf=w/2
            -- Enclose the second road's cut rectangle in the owner's pad frame.
            local half=math.max(w/(2*math.max(sin,1/3)),otherHalf*cos+other.width/2*sin)
            local padWidth=math.max(w,2*otherHalf*sin+other.width*cos)
            out[#out+1]={d=c.da,position=c.position,forward=fa,up=ua,size=Vector3.new(padWidth,0,half*2),half=half,
                otherD=c.db,otherHalf=otherHalf}
        end
    end
    table.sort(out,function(x,y) return x.d<y.d end)
    return out
end

-- Both roads cut to the same pad. The later road in the saved order owns it.
-- Only the draft and its old/new neighbors need to rebuild generated road parts.
function N.planRoads(roads,index,previous,updateNeighbors)
    local pairsByOwner={}
    local function pair(a,b)
        local owner,other=math.max(a,b),math.min(a,b)
        local high,low=roads[owner],roads[other]
        if not high.width or not low.width then return {} end
        pairsByOwner[owner]=pairsByOwner[owner] or {}
        local matches=pairsByOwner[owner][other]
        if not matches then
            matches=N.junctions(high.path,high.width,{low})
            pairsByOwner[owner][other]=matches
        end
        return matches
    end
    local function layout(i)
        local result={road=roads[i],junctions={},pads={}}
        local matches={}
        for j=1,#roads do
            if i~=j then
                for _,junction in ipairs(pair(i,j)) do
                    matches[#matches+1]={owner=math.max(i,j),junction=junction,
                        d=i>j and junction.d or junction.otherD,half=i>j and junction.half or junction.otherHalf}
                end
            end
        end
        table.sort(matches,function(a,b) return a.d<b.d end)
        local crossings={}
        for _,match in ipairs(matches) do
            local last=crossings[#crossings]
            if not last or match.d-last.d>0.05 or (last.junction.position-match.junction.position).Magnitude>0.05 then
                crossings[#crossings+1]=match
            elseif match.owner>last.owner then
                crossings[#crossings]=match
            elseif match.owner==i and last.owner==i then
                -- Multiple roads can meet at one point. The owner covers all their cuts.
                local pad=table.clone(last.junction)
                last.half=math.max(last.half,match.half)
                pad.size=Vector3.new(math.max(pad.size.X,match.junction.size.X),0,last.half*2)
                last.junction=pad
            end
        end
        for _,crossing in ipairs(crossings) do
            result.junctions[#result.junctions+1]={d=crossing.d,half=crossing.half}
            if crossing.owner==i then result.pads[#result.pads+1]=crossing.junction end
        end
        return result
    end
    local draft=layout(index)
    local updates={}
    if updateNeighbors then
        for i,road in ipairs(roads) do
            if i~=index and road.width then
                local matches=#pair(index,i)>0
                local draftChanged=previous and (previous.path~=draft.road.path or not draft.road.width)
                if matches or (draftChanged and #N.crossings(previous.path,road.path)>0) then
                    updates[#updates+1]=layout(i)
                end
            end
        end
    end
    return draft,updates
end

-- Distance ranges along the path that a road should leave to the junction pad.
function N.cuts(junctions,length)
    local cuts={}
    for _,j in ipairs(junctions) do
        cuts[#cuts+1]={math.max(0,j.d-j.half),math.min(length,j.d+j.half)}
    end
    return cuts
end

-- Part specs for the pads: flat asphalt slabs whose top sits on the road surface.
function N.padSpecs(junctions,height,offset)
    local specs={}
    for _,j in ipairs(junctions) do
        local h=math.max(height,0.05)
        local top=j.position+Vector3.new(0,offset+0.01,0)
        local center=top-j.up*(h/2)
        specs[#specs+1]={name="Junction",cf=CFrame.lookAt(center,center+j.forward,j.up),
            size=Vector3.new(j.size.X,h,j.size.Z),material="Asphalt",color={54,58,63}}
    end
    return specs
end
return N
