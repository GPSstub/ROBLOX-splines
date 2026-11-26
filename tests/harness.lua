-- Shared mini test harness, loaded by each tests/test_*.lua file.
local H={}
function H.new()
    local results={}
    local t={}
    function t.check(name,fn)
        local ok,err=pcall(fn)
        results[#results+1]=(ok and "ok   " or "FAIL ")..name..(ok and "" or (" -> "..tostring(err)))
    end
    function t.close(a,b,e,msg) assert(math.abs(a-b)<(e or 1e-4),(msg or "")..": expected "..tostring(b)..", got "..tostring(a)) end
    function t.fails(fn,pattern)
        local ok,err=pcall(fn)
        assert(not ok,"expected an error")
        if pattern then assert(tostring(err):find(pattern,1,true),"wrong error: "..tostring(err)) end
    end
    function t.finish()
        local failed=0
        for _,line in ipairs(results) do if line:sub(1,4)=="FAIL" then failed=failed+1 end end
        local msg=table.concat(results,"\n    ")
        if failed>0 then error(failed.." of "..#results.." failed\n    "..msg,0) end
        return #results.." passed\n    "..msg
    end
    return t
end
return H
