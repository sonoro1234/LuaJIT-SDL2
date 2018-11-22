
local function strip(cad)
    return cad:gsub("^%s*(.-)%s*$","%1") --remove initial and final spaces
end

local function clean_spaces(cad)
    cad = strip(cad)
    cad = cad:gsub("%s+"," ") --not more than one space
    cad = cad:gsub("%s*([%(%),=])%s*","%1") --not spaces with ( , )
    return cad
end

local function save_data(filename,...)
    local file = io.open(filename,"w")
    for i=1, select('#', ...) do
        local data = select(i, ...)
        file:write(data)
    end
    file:close()
end

local doprint = true
--iterates lines from a gcc/clang -E in a specific location
local function location(file,locpathT,defines)
	local define_re = "^#define%s+([^%s]+)%s+([^%s]+)$"
	local number_re = "^-?[0-9]+u*$"
	local hex_re = "0x[0-9a-fA-F]+u*$"
    local location_re 
    if COMPILER == "cl" then
        location_re = '^#line (%d+) "([^"]*)"'
    else --gcc, clang
        location_re = '^# (%d+) "([^"]*)"'
    end
    local path_reT = {}
    for i,locpath in ipairs(locpathT) do
        table.insert(path_reT,'^.*[\\/]('..locpath..')%.h$')
    end
    local in_location = false
    local which_location = ""
    local loc_num
    local loc_num_incr
    local lineold = "" 
    local which_locationold,loc_num_realold
    local lastdumped = false
    local function location_it()
        repeat
            local line = file:read"*l"
            if not line then
                if not lastdumped then
                    lastdumped = true
                    return lineold, which_locationold,loc_num_realold
                else
                    return nil
                end
            end
            if #line==0 then --nothing on emptyline
            elseif not line:match("%S") then --nothing if only spaces
            elseif line:sub(1,1) == "#" then
                -- Is this a location pragma?
                local loc_num_t,location_match = line:match(location_re)
                if location_match then
                    in_location = false
                    for i,path_re in ipairs(path_reT) do
						local locpath = location_match:match(path_re)
                        if locpath then 
                            in_location = true;
                            loc_num = loc_num_t
                            loc_num_incr = 0
                            which_location = locpath --locpathT[i]
                            break 
                        end
                    end
				elseif in_location then
					local name,val = line:match(define_re)
					if name and val then
						--while defines[val] do val = defines[val] end
						--if val:match(number_re) or val:match(hex_re) then
							table.insert(defines,{name , val})
						--end
					end
                end
				
            elseif in_location then
                local loc_num_real = loc_num + loc_num_incr
                loc_num_incr = loc_num_incr + 1
				--if doprint then print(which_locationold,which_location) end
                if (which_locationold~=which_location) or (loc_num_realold and loc_num_realold < loc_num_real) then
                    --old line complete
					--doprint = false
                    local lineR,which_locationR,loc_num_realR = lineold, which_locationold,loc_num_realold
                    lineold, which_locationold,loc_num_realold = line,which_location,loc_num_real
                    return lineR,which_locationR,loc_num_realR
                else
                    lineold=lineold..line
                    which_locationold,loc_num_realold = which_location,loc_num_real
                --return line,loc_num_real, which_location
                end
            end
        until false --forever
    end
    return location_it
end

local function parseFunction(line,numfunc)
	line = clean_spaces(line)
	--move *
	line = line:gsub("%s*%*","%*")
	line = line:gsub("%*([%w_])","%* %1")
	line = line:gsub("(%(%*)%s","%1")

	--print(line)
    --clean implemetation
    line = line:gsub("%s*%b{}","")
    --clean attribute
    line = line:gsub("%s*__attribute__%b()","")
    --clean static
    line = line:gsub("static","")
    
    local ret = line:match("([^%(%)]+[%*%s])%s?~?[_%w]+%b()")
    local funcname, args = line:match("(~?[_%w]+)%s*(%b())")
	
	--print(line)
	--print(funcname,"args",args)
    
    local argscsinpars = args:gsub("(=[^,%(%)]*)(%b())","%1")
    argscsinpars = argscsinpars:gsub("(=[^,%(%)]*)([,%)])","%2")
    -- if argscsinpars:match("&") then 
        -- for arg in argscsinpars:gmatch("[%(,]*([^,%(%)]+)[%),]") do
            -- if arg:match("&") and not arg:match("const") then
                -- print(funcname,argscsinpars)
            -- end
        -- end
    -- end
    --argscsinpars = argscsinpars:gsub("&","")
    
    argscsinpars = argscsinpars:gsub("<([%w_]+)>","_%1") --ImVector
    
    local argsArr = {}
    local functype_re =       "^%s*[%w%s%*]+%(%*[%w_]+%)%([^%(%)]*%)"
    local functype_reex =     "^(%s*[%w%s%*]+)%(%*([%w_]+)%)(%([^%(%)]*%))"
    local functype_arg_rest = "^(%s*[%w%s%*]+%(%*[%w_]+%)%([^%(%)]*%)),*(.*)"
    local rest = argscsinpars:sub(2,-2) --strip ()
    
    while true do
    --local tt = strsplit(rest,",")
    --for ii,arg in ipairs(tt) do
    --for arg in argscsinpars:gmatch("[%(,]*([^,%(%)]+)[%),]") do
		if rest == "void" then break end
        local type,name,retf,sigf
        local arg,restt = rest:match(functype_arg_rest)
        if arg then
            local t1,namef,t2 = arg:match(functype_reex)
            type=t1.."(*)"..t2;name=namef
            retf = t1
            sigf = t2
            rest = restt
        else
            arg,restt = rest:match(",*([^,%(%)]+),*(.*)")
            if not arg then break end
            rest = restt
            if arg:match("&") and arg:match("const") then
                arg = arg:gsub("&","")
            end
            if arg:match("%.%.%.") then 
                type="...";name="..."
            else
                type,name = arg:match("(.+)%s([^%s]+)")
            end

            if not type or not name then 
                print("failure arg detection",funcname,type,name,argscsinpars,arg)

            else
				if name:match"%*" then print("**",numfunc,funcname) end
                --float name[2] to float[2] name
                local siz = name:match("(%[%d*%])")
                if siz then
                    type = type..siz
                    name = name:gsub("(%[%d*%])","")
                end
            end
        end
        table.insert(argsArr,{type=type,name=name,ret=retf,signature=sigf})
        if arg:match("&") and not arg:match("const") then
            --only post error if not manual
            local cname = getcimguiname(stname,funcname)
            if not cimgui_manuals[cname] then
                print("reference to no const arg in",funcname,argscsinpars)
            end
        end
    end
    argscsinpars = argscsinpars:gsub("&","")
    
    local signature = argscsinpars:gsub("([%w%s%*_]+)%s[%w_]+%s*([,%)])","%1%2")
    signature = signature:gsub("%s*([,%)])","%1") --space before , and )
    signature = signature:gsub(",%s*",",")--space after ,
    signature = signature:gsub("([%w_]+)%s[%w_]+(%[%d*%])","%1%2") -- float[2]
    signature = signature:gsub("(%(%*)[%w_]+(%)%([^%(%)]*%))","%1%2") --func defs
    
    local call_args = argscsinpars:gsub("([%w_]+%s[%w_]+)%[%d*%]","%1") --float[2]
    call_args = call_args:gsub("%(%*([%w_]+)%)%([^%(%)]*%)"," %1") --func type
    call_args = call_args:gsub("[^%(].-([%w_]+)%s*([,%)])","%1%2")
    
    if not ret and stname then --must be constructors
        if not (stname == funcname or "~"..stname==funcname) then --break end
            print("false constructor:",line);
            print("b2:",ret,stname,funcname,args)
            return --are function defs
        end
    end
    
    -- local cimguiname = getcimguiname(stname,funcname)
    -- table.insert(cdefs,{stname=stname,funcname=funcname,args=args,argsc=argscsinpars,signature=signature,cimguiname=cimguiname,call_args=call_args,ret =ret,comment=comment})

    local defT = {} 
    defT.defaults = {}
    --for k,def in args:gmatch("([%w%s%*_]+)=([%w_%(%)%s,%*]+)[,%)]") do
    --for k,def in args:gmatch("([%w_]+)=([%w_%(%)%s,%*%.%-]+)[,%)]") do
    for k,def in args:gmatch('([%w_]+)=([%w_%(%)%s,%*%.%-%+%%"]+)[,%)]') do
        defT.defaults[k]=def
    end

    defT.stname = stname
    defT.funcname = funcname
    defT.argsoriginal = args
    defT.args=argscsinpars
    defT.signature = signature
    defT.call_args = call_args
    defT.isvararg = signature:match("%.%.%.%)$")
    defT.location = locat
    defT.comment = comment
    defT.argsT = argsArr

    if ret then
        defT.ret = clean_spaces(ret:gsub("&","*"))
        defT.retref = ret:match("&")
        -- if defT.ret=="ImVec2" or defT.ret=="ImVec4" or defT.ret=="ImColor" then
            -- defT.ret = defT.ret.."_Simple"
        -- end
    end
	return defT
end

local function copyfile(src,dst,blocksize)
    blocksize = blocksize or 1024*4
    print( "copyfile", src, dst)
    local srcf, err = io.open(src,"rb")
    if not srcf then error(err) end
    local dstf, err = io.open(dst,"wb")
    if not dstf then error(err) end
    while true do
        local data = srcf:read(blocksize)
        if not data then break end
        dstf:write(data)
    end
    srcf:close()
    dstf:close()
end
------------------------------------------------------
local cdefs = {}

save_data("./outheader.h",[[#include <sdl.h>]])
local pipe,err = io.popen([[gcc -E -dD -I ../SDL/include/ ./outheader.h]],"r")
if not pipe then
    error("could not execute gcc "..err)
end

local defines = {}
for line in location(pipe,{[[SDL.-]]},defines) do
    --local line = strip(line)
	table.insert(cdefs,line)
end
pipe:close()
os.remove"./outheader.h"


local function_re = "^([^;{}]+%b()[\n%s]*;)"
local struct_re = "^([^;{}]-struct[^;{}]-%b{}[%s%w_%(%)]*;)"
local enum_re = "^([^;{}]-enum[^;{}]-%b{}[%s%w_%(%)]*;)"
local union_re = "^([^;{}]-union[^;{}]-%b{}[%s%w_%(%)]*;)"
local structenum_re = "^([^;{}]-%b{}[%s%w_%(%)]*;)"
local typedef_re = "^\n*(typedef[^;]+;)"
local functypedef_re = "^\n*%s*(typedef[%w%s%*_]+%(%s*%*%s*[%w_]+%s*%)%s*%b()%s*;)"
local functypedef_re = "^\n*%s*(typedef[%w%s%*_]+%([^*]+%*%s*[%w_]+%s*%)%s*%b()%s*;)"
local vardef_re = "^\n*([^;{}%(%)]+;)"
local functionD_re = "^([^;]-%b()[\n%s]*%b{})"

local res = {functypedef_re,function_re,functionD_re,struct_re,enum_re,union_re,typedef_re,vardef_re}
--local res = {function_re,functionD_re,structenum_re,typedef_re,vardef_re}

local txt = table.concat(cdefs,"\n")
--local txt2 = table.concat(cdefs," rayo ")
--save_data("./cpreout.txt",txt)

local ini = 1
local items = {}
local cdefs = {}
while true do
	local found = false
	for ire,re in ipairs(res) do
		local i,e = txt:find(re,ini)
		if i then
			local item = txt:sub(i,e)
			if re~=functionD_re then --skip defined functions
				item = item:gsub("extern __attribute__%(%(dllexport%)%) ","")
				table.insert(cdefs,item)
			end
			--[[
			if re==function_re and item:match"typedef" then
				--function typedefs
				items[typedef_re] = items[typedef_re] or {}
				table.insert(items[typedef_re],item)
			else
				items[re] = items[re] or {}
				table.insert(items[re],item)
			end
			--]]
			items[re] = items[re] or {}
			table.insert(items[re],item)
			found = true
			ini = e + 1
			--print(item)
			--print(ire,"------------------------------------------------------")
			break
		end
	end
	if not found then
		print(ini,#txt)
		assert(ini >= #txt)
		break 
	end
end

print"items"
for k,v in pairs(items) do
	print(k,#v)
end

--for k,v in pairs(defines) do print("define",k,v) end
local deftab = {}
local ffi = require"ffi"
ffi.cdef(table.concat(cdefs,""))
local wanted_strings = {"^SDL","^AUDIO_","^KMOD_","^RW_"}
for i,v in ipairs(defines) do
	local wanted = false
	for _,wan in ipairs(wanted_strings) do
		if (v[1]):match(wan) then wanted=true; break end
	end
	if wanted then
		local lin = "static const int "..v[1].." = " .. v[2] .. ";"
		local ok,msg = pcall(function() return ffi.cdef(lin) end)
		if not ok then
			print("skipping def",lin)
			print(msg)
		else
			table.insert(deftab,lin)
		end
	end
end

local special =[[
static const int SDL_WINDOWPOS_CENTERED = SDL_WINDOWPOS_CENTERED_MASK
]]

-----------make test
local funcnames = {}
--[[
for i,v in ipairs(items[function_re]) do
	local funcname = v:match("([%w_]+)%s*%(")
	if not funcname then print(v) end
	table.insert(funcnames,"if not pcall(function() local nn=M.C."..funcname.." end) then print('bad','"..funcname.."') end")
end
--]]


--output sdl2_ffi
local sdlstr = [[
local ffi = require"ffi"

--uncomment to debug cdef calls]]..
"\n---[["..[[

local ffi_cdef = ffi.cdef
ffi.cdef = function(code)
    local ret,err = pcall(ffi_cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end
]].."--]]"..[[

ffi.cdef]].."[["..table.concat(cdefs,"").."]]"..[[

ffi.cdef]].."[["..table.concat(deftab,"\n").."]]"..[[

ffi.cdef]].."[["..special.."]]"..[[

local lib = ffi.load"SDL2"

local M = {C=lib}

function M.loadBMP(file)
    return M.loadBMP_RW(M.RWFromFile(file, 'rb'), 1)
end
function M.loadWAV(file, spec, audio_buf, audio_len)
   return M.loadWAV_RW(M.RWFromFile(file, "rb"), 1, spec, audio_buf, audio_len)
end
function M.saveBMP(surface, file)
   return M.saveBMP_RW(surface, M.RWFromFile(file, 'wb'), 1)
end

local callback_t
local callbacks_anchor = {}
function M.MakeAudioCallback(func)
	if not callback_t then
		local CallbackFactory = require "lj-async.callback"
		callback_t = CallbackFactory("void(*)(void*,uint8_t*,int)") --"SDL_AudioCallback"
	end
	local cb = callback_t(func)
	table.insert(callbacks_anchor,cb)
	return cb:funcptr()
end
local threadfunc_t
function M.MakeThreadFunc(func)
	if not threadfunc_t then
		local CallbackFactory = require "lj-async.callback"
		threadfunc_t = CallbackFactory("int(*)(void*)")
	end
	local cb = threadfunc_t(func)
	table.insert(callbacks_anchor,cb)
	return cb:funcptr()
end

setmetatable(M,{
__index = function(t,k)
	local str2 = "SDL_"..string.upper(k:sub(1,1))..k:sub(2)
	local ok,ptr = pcall(function(str) return lib[str] end,str2)
	if not ok then ok,ptr = pcall(function(str) return lib[str] end,k) end
	if not ok then error(k.." not found") end
	rawset(M, k, ptr)
	return ptr
end
})


]]..table.concat(funcnames,"\n")..[[

return M
]]

save_data("./sdl2_ffi.lua",sdlstr)
copyfile("./sdl2_ffi.lua","../sdl2_ffi.lua")
-------------------------------
--[[
require"anima.utils"
for i=1,#items[function_re] do
--for i=11,11 do
 local defT = parseFunction(items[function_re][i],i)
--prtable(defT)
end

print"typedefs--------------------------------------"
for i=1,#items[typedef_re] do print(items[typedef_re][i]) end
print"functypedefs--------------------------------------"
for i=1,#items[functypedef_re] do print(items[functypedef_re][i]) end
print"struct--------------------------------------"
for i=1,#items[struct_re] do print(items[struct_re][i]) end
print"union--------------------------------------"
for i=1,#items[union_re] do print(items[union_re][i]) end
print"enum--------------------------------------"
for i=1,#items[enum_re] do print(items[enum_re][i]) end
print"vardef--------------------------------------"
for i=1,#items[vardef_re] do print(items[vardef_re][i]) end

--]]
--[=[
--save
local glfwstr = "local cdecl=[[\n"..table.concat(cdefs,"\n").."]]\n"
glfwstr = glfwstr..define_str("glfwc",defines)
local hfile = io.open("./glfw_base.lua","r")
local hstrfile = hfile:read"*a"
hfile:close()
save_data("./glfw.lua",glfwstr,hstrfile)


copyfile("./glfw.lua","../glfw.lua")
copyfile("./gl.lua","../gl.lua")
--]=]