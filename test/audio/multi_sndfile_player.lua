--[[/*
  Copyright (C) 1997-2018 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely.
*/

/* Program to load several sndfiles and playing them using SDL audio */


--]]

local sdl = require 'sdl2_ffi'
local ffi = require 'ffi'
--https://github.com/sonoro1234/LuaJIT-libsndfile
local sndf = require"sndfile_ffi"

---------------------------------------------audioplayer interface
local audioplayercode = [[
typedef struct sf_node sf_node;
struct sf_node
{
	SNDFILE_ref sf;
	double level;
	double timeoffset;
	sf_node *next;
	sf_node *prev;
} sf_node;

typedef struct audioplayer
{
	SDL_AudioSpec spec;
	sf_node root;
	double streamTime;
} audioplayer;
]]

ffi.cdef(audioplayercode)
AudioPlayer_mt = {}
AudioPlayer_mt.__index = AudioPlayer_mt
function AudioPlayer_mt:__new()
	local ap = ffi.new("audioplayer")
	ffi.gc(ap,self.destroy)
	return ap
end
function AudioPlayer_mt:destroy()
	for node in self:nodes() do
		node.sf:close()
	end
	ffi.gc(self,nil)
end
function AudioPlayer_mt:insert(filename,level,timeoffset)
	level = level or 1
	timeoffset = timeoffset or 0
	local sf = sndf.Sndfile(filename)
	local node = ffi.new"sf_node[1]"
	node[0].sf = sf
	node[0].level = level
	node[0].timeoffset = timeoffset
	
	node[0].next = self.root.next
	self.root.next = node
	return node[0]
end
function AudioPlayer_mt:erase(node)
	local sf_node = self.root
	while true do
		local prev = sf_node
		sf_node = sf_node.next[0]
		if sf_node == node then
			prev.next = sf_node.next
			node.sf:close()
			break
		end
	end
end
function AudioPlayer_mt:nodes()
	local cur_node = self.root
	return function()
		local nextnode = cur_node.next[0]
		if nextnode == nil then return nil end
		cur_node = nextnode
		return nextnode
	end
end
local AudioPlayer = ffi.metatype("audioplayer",AudioPlayer_mt)


--------------------will run in a separate thread and lua state
local function AudioInit(audioplayer,audioplayercode)

    local ffi = require"ffi"
    local sdl = require"sdl2_ffi"
    local sndf = require"sndfile_ffi"
	
	ffi.cdef(audioplayercode)
	audioplayer = ffi.new("audioplayer*",audioplayer)
	local root = audioplayer.root
    local spec = audioplayer.spec
	local streamTime = audioplayer.streamTime
    local typebuffer,lenfac,nchannels = sdl.audio_buffer_type(spec)
    local timefac = 1/spec.freq
    local bufpointer = typebuffer.."*"
    local readfunc = "readf_"..typebuffer
	
    print("Init audio:",spec.freq,bufpointer,readfunc)
    
    return function(ud,stream,len)

        local lenf = len*lenfac
        assert(lenf == math.floor(lenf))
		local windowsize = lenf * timefac
		sdl.memset(stream, 0, len)
		local streamf = ffi.cast(bufpointer,stream)
		local readbuffer = ffi.new(typebuffer.."[?]",lenf*nchannels)
		local sf_node = root
		while true do
			if sf_node.next~=nil then
				sf_node = sf_node.next[0]
				local sf = sf_node.sf
				if sf_node.timeoffset <= streamTime then --already setted 
					sf[readfunc](sf,readbuffer,lenf)
					for i=0,(lenf*nchannels)-1 do
						streamf[i] = streamf[i] + readbuffer[i]*sf_node.level
					end
				elseif sf_node.timeoffset < streamTime + windowsize then --set it here
					local frames = (streamTime + windowsize - sf_node.timeoffset) * spec.freq
					local res = sf:seek( 0, sndf.SEEK_SET)
					sf[readfunc](sf,readbuffer,frames)
					local j=0
					for i=(lenf - frames)*nchannels,(lenf*nchannels)-1 do
						streamf[i] = streamf[i] + readbuffer[j]*sf_node.level
						j = j + 1
					end
				end
			else break end
		end
		streamTime = streamTime + lenf*timefac
		print(streamTime)
    end
end

-----------------------main--------------------------------------
    local filename = "sample.wav";

    --/* Enable standard application logging */
    sdl.LogSetPriority(sdl.LOG_CATEGORY_APPLICATION, sdl.LOG_PRIORITY_INFO);

    --/* Load the SDL library */
    if (sdl.Init(sdl.INIT_AUDIO + sdl.INIT_EVENTS) < 0) then
        sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "Couldn't initialize SDL: %s\n", sdl.GetError());
        return (1);
    end
	
	--copy specs from file
	local sf1 = sndf.Sndfile(filename)
	local audioplayer = AudioPlayer()
    local spec = audioplayer.spec
    spec.freq = sf1:samplerate();
    spec.format = sdl.AUDIO_S16; --try others
    spec.channels = sf1:channels();
    spec.callback = sdl.MakeAudioCallback(AudioInit,audioplayer,audioplayercode)
	sf1:close()
	
	print("samplerate",spec.freq,"channels",spec.channels)
	--insert 3 files
	audioplayer:insert(filename,0.1,0)
	local node2 = audioplayer:insert(filename,0.1,0.75)
	audioplayer:insert(filename,0.1,1.5)
	
	for node in audioplayer:nodes() do
		print("node",node.sf)
	end
	
	audioplayer:erase(node2)
	print"after erase"
	for node in audioplayer:nodes() do
		print("node",node.sf)
	end

    --/* Show the list of available drivers */
    sdl.Log("Available audio drivers:");
    for i = 0,sdl.GetNumAudioDrivers()-1 do
        sdl.Log("%i: %s",ffi.new("int", i), sdl.GetAudioDriver(i));
    end

    sdl.Log("Using audio driver: %s\n", sdl.GetCurrentAudioDriver());

        --/* Initialize callback() variables */
    local device = sdl.OpenAudioDevice(nil, sdl.FALSE, spec, nil, 0);
    if (device==0) then
        sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "Couldn't open audio: %s\n", sdl.GetError());
		audioplayer:destroy()
        sdl.Quit();
    end

    --/* Let the audio run */
    sdl.PauseAudioDevice(device, sdl.FALSE);
--[[
    local done = false;
    while (not done) do
        local event = ffi.new"SDL_Event"

        while (sdl.PollEvent(event) > 0) do
            if (event.type == sdl.QUIT) then
                done = true;
            end
        end
        sdl.Delay(100);
    end
--]]
	sdl.Delay(10000);
    --/* Clean up on signal */
    sdl.CloseAudioDevice(device);
	audioplayer:destroy()
    sdl.Quit();

