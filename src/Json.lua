-- Small deterministic JSON codec (sorted object keys). Used for saved settings,
-- recipes and cache keys so the same input always produces the same text.
-- Reads HttpService JSON written by earlier PathForge versions.
local J={}
local function isArray(t)
    local n=0
    for k in pairs(t) do
        if type(k)~="number" or k<1 or k%1~=0 then return false end
        n+=1
    end
    for i=1,n do if t[i]==nil then return false end end
    return true,n
end
local escapes={['"']='\\"',["\\"]="\\\\",["\b"]="\\b",["\f"]="\\f",["\n"]="\\n",["\r"]="\\r",["\t"]="\\t"}
local function str(s)
    return '"'..s:gsub('[%c"\\]',function(c) return escapes[c] or string.format("\\u%04x",c:byte()) end)..'"'
end
local function encode(v,depth)
    assert(depth<=32,"JSON nesting too deep")
    local t=type(v)
    if t=="nil" then return "null"
    elseif t=="boolean" then return tostring(v)
    elseif t=="number" then
        assert(v==v and v~=math.huge and v~=-math.huge,"JSON cannot store NaN or infinity")
        if v%1==0 and math.abs(v)<2^53 then return string.format("%d",v) end
        return string.format("%.14g",v)
    elseif t=="string" then return str(v)
    elseif t=="table" then
        local array,n=isArray(v)
        local out={}
        if array then
            for i=1,n do out[i]=encode(v[i],depth+1) end
            return "["..table.concat(out,",").."]"
        end
        local keys={}
        for k in pairs(v) do assert(type(k)=="string","JSON object keys must be strings"); keys[#keys+1]=k end
        table.sort(keys)
        for i,k in ipairs(keys) do out[i]=str(k)..":"..encode(v[k],depth+1) end
        return "{"..table.concat(out,",").."}"
    end
    error("Cannot encode "..t.." as JSON",0)
end
function J.encode(v) return encode(v,0) end
function J.decode(s)
    assert(type(s)=="string","JSON text expected")
    local i=1
    local function ws() i=s:find("[^ \t\r\n]",i) or #s+1 end
    local function fail(msg) error("Invalid JSON at "..i..": "..msg,0) end
    local value
    local function readString()
        i+=1
        local out={}
        while true do
            local c=s:sub(i,i)
            if c=="" then fail("unterminated string") end
            if c=='"' then i+=1; break end
            if c=="\\" then
                local e=s:sub(i+1,i+1)
                local map={['"']='"',["\\"]="\\",["/"]="/",b="\b",f="\f",n="\n",r="\r",t="\t"}
                if map[e] then out[#out+1]=map[e]; i+=2
                elseif e=="u" then
                    local hex=s:sub(i+2,i+5)
                    local code=tonumber(hex,16); if not code or #hex<4 then fail("bad escape") end
                    out[#out+1]=utf8.char(code); i+=6
                else fail("bad escape") end
            else out[#out+1]=c; i+=1 end
        end
        return table.concat(out)
    end
    value=function(depth)
        if depth>32 then fail("nesting too deep") end
        ws()
        local c=s:sub(i,i)
        if c=="{" then
            i+=1; local t={}; ws()
            if s:sub(i,i)=="}" then i+=1; return t end
            while true do
                ws(); if s:sub(i,i)~='"' then fail("key expected") end
                local k=readString(); ws()
                if s:sub(i,i)~=":" then fail("':' expected") end
                i+=1; t[k]=value(depth+1); ws()
                local d=s:sub(i,i); i+=1
                if d=="}" then return t elseif d~="," then fail("',' or '}' expected") end
            end
        elseif c=="[" then
            i+=1; local t={}; ws()
            if s:sub(i,i)=="]" then i+=1; return t end
            while true do
                t[#t+1]=value(depth+1); ws()
                local d=s:sub(i,i); i+=1
                if d=="]" then return t elseif d~="," then fail("',' or ']' expected") end
            end
        elseif c=='"' then return readString()
        elseif s:sub(i,i+3)=="true" then i+=4; return true
        elseif s:sub(i,i+4)=="false" then i+=5; return false
        elseif s:sub(i,i+3)=="null" then i+=4; return nil
        else
            local num=s:match("^-?%d+%.?%d*[eE]?[-+]?%d*",i)
            local v=num and tonumber(num)
            if not v then fail("value expected") end
            i+=#num; return v
        end
    end
    local result=value(0); ws()
    if i<=#s then fail("trailing text") end
    return result
end
return J
