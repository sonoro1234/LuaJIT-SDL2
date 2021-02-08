local ffi = require"ffi"
local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
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

local cp2c = require"cpp2ffi"
------------------------------------------------------
local cdefs = {}

cp2c.save_data("./outheader.h",[[#include <sdl.h>]])
local pipe,err = io.popen([[gcc -E -dD -I ../SDL/include/ ./outheader.h]],"r")
if not pipe then
    error("could not execute gcc "..err)
end

local defines = {}
for line in cp2c.location(pipe,{[[SDL.-]]},defines) do
    --local line = strip(line)
	table.insert(cdefs,line)
end
pipe:close()
os.remove"./outheader.h"


local txt = table.concat(cdefs,"\n")
--cp2c.save_data("./cpreout.txt",txt)

local itemsarr,items = cp2c.parseItems(txt)

print"items"
for k,v in pairs(items) do
	print(k,#v)
end

--make new cdefs
local cdefs = {}
for k,v in ipairs(itemsarr) do
	if v.re_name ~= "functionD_re" then --skip defined funcs
		if v.re_name=="function_re" then
			--skip CreateThread
			if not v.item:match("CreateThread") then
				local item = v.item
				if item:match("^%s*extern") then
					item = item:gsub("^%s*extern%s*(.+)","\n%1")
				end
				table.insert(cdefs,item)
			end
		else
			table.insert(cdefs,v.item)
		end
	end
end
------------------------------
local deftab = {}
local ffi = require"ffi"
ffi_cdef(table.concat(cdefs,""))
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


local special_win = [[
typedef unsigned long (__cdecl *pfnSDL_CurrentBeginThread) (void *, unsigned,
        unsigned (__stdcall *func)(void *), void *arg,
        unsigned, unsigned *threadID);
typedef void (__cdecl *pfnSDL_CurrentEndThread)(unsigned code);

 uintptr_t __cdecl _beginthreadex(void *_Security,unsigned _StackSize,unsigned (__stdcall *_StartAddress) (void *),void *_ArgList,unsigned _InitFlag,unsigned *_ThrdAddr);
   void __cdecl _endthreadex(unsigned _Retval);
  
static const int SDL_WINDOWPOS_CENTERED = SDL_WINDOWPOS_CENTERED_MASK;
SDL_Thread * SDL_CreateThread(SDL_ThreadFunction fn, const char *name, void *data,pfnSDL_CurrentBeginThread bf,pfnSDL_CurrentEndThread ef);
SDL_Thread * SDL_CreateThreadWithStackSize(int ( * fn) (void *),const char *name, const size_t stacksize, void *data,pfnSDL_CurrentBeginThread bf,pfnSDL_CurrentEndThread ef);
]]

local special =[[
static const int SDL_WINDOWPOS_CENTERED = SDL_WINDOWPOS_CENTERED_MASK;
SDL_Thread * SDL_CreateThread(SDL_ThreadFunction fn, const char *name, void *data);
SDL_Thread * SDL_CreateThreadWithStackSize(int ( * fn) (void *),const char *name, const size_t stacksize, void *data);
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

--local ffi_cdef = ffi.cdef
local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
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

ffi_cdef]].."[["..table.concat(cdefs,"").."]]"..[[

ffi_cdef]].."[["..table.concat(deftab,"\n").."]]"..[[

if ffi.os == 'Windows' then
ffi_cdef]].."[["..special_win.."]]"..[[

else
ffi_cdef]].."[["..special.."]]"..[[

end

local lib = ffi.load"SDL2"

local M = {C=lib}

if ffi.os == "Windows" then

   function M.createThread(a,b,c)
   	return lib.SDL_CreateThread(a,b,c,ffi.C._beginthreadex, ffi.C._endthreadex)
   end
   
   function M.createThreadWithStackSize(a,b,c,d)
   	return lib.SDL_CreateThreadWithStackSize(a,b,c,d,ffi.C._beginthreadex, ffi.C._endthreadex)
   end

end

function M.LoadBMP(file)
    return M.LoadBMP_RW(M.RWFromFile(file, 'rb'), 1)
end
function M.LoadWAV(file, spec, audio_buf, audio_len)
   return M.LoadWAV_RW(M.RWFromFile(file, "rb"), 1, spec, audio_buf, audio_len)
end
function M.SaveBMP(surface, file)
   return M.SaveBMP_RW(surface, M.RWFromFile(file, 'wb'), 1)
end

local AudioSpecs = {}
AudioSpecs.__index = AudioSpecs
function AudioSpecs:print()
	print(string.format('spec parameters: \nfreq=%s, \nformat=%s, \nformat bits=%s, \nis float %s,\nendianess=%d, \nis signed %s, \nchannels=%s \nsilence=%s, \nsamples=%s bytes,\nsize=%s bytes', self.freq,self.format, bit.band(self.format, 0xff),tostring(bit.band(0x1000,self.format)>0), bit.band(0x100,self.format) , tostring(bit.band(0xF000,self.format)>0),self.channels,  self.silence,  self.samples,  self.size))
end
ffi.metatype("SDL_AudioSpec",AudioSpecs)

--function returning typebuffer,lenfac,nchannels from spec
function M.audio_buffer_type(spec)
	local nchannels = spec.channels
	local bitsize = bit.band(spec.format,0xff)
	local isfloat = bit.band(spec.format,0x100)
	local typebuffer
	if isfloat>0 then
		if bitsize == 32 then typebuffer = "float"
		else error("unknown float buffer type bits:"..tostring(bitsize)) end
	else
		if bitsize == 16 then typebuffer = "short"
		elseif bitsize == 32 then typebuffer = "int"
		else error("unknown buffer type bits:"..tostring(bitsize)) end
	end
	local lenfac = 1/(ffi.sizeof(typebuffer)*nchannels)
	return typebuffer,lenfac,nchannels
end


local callback_t
local states_anchor = {}
function M.MakeAudioCallback(func, ...)
	if not callback_t then
		local CallbackFactory = require "lj-async.callback"
		callback_t = CallbackFactory("void(*)(void*,uint8_t*,int)") --"SDL_AudioCallback"
	end
	local cb = callback_t(func, ...)
	table.insert(states_anchor,cb)
	return cb:funcptr(), cb
end
local threadfunc_t
function M.MakeThreadFunc(func, ...)
	if not threadfunc_t then
		local CallbackFactory = require "lj-async.callback"
		threadfunc_t = CallbackFactory("int(*)(void*)")
	end
	local cb = threadfunc_t(func, ...)
	table.insert(states_anchor,cb)
	return cb:funcptr(), cb
end

setmetatable(M,{
__index = function(t,k)
	local ok,ptr = pcall(function(str) return lib["SDL_"..str] end,k)
	if not ok then ok,ptr = pcall(function(str) return lib[str] end,k) end --some defines without SDL_
	if not ok then --torch sdl2 calling
		local str2 = "SDL_"..string.upper(k:sub(1,1))..k:sub(2)
		ok,ptr = pcall(function(str) return lib[str] end,str2) 
	end
	if not ok then error(k.." not found") end
	rawset(M, k, ptr)
	return ptr
end
})


]]..table.concat(funcnames,"\n")..[[

return M
]]

cp2c.save_data("./sdl2_ffi.lua",sdlstr)
cp2c.copyfile("./sdl2_ffi.lua","../sdl2_ffi.lua")
