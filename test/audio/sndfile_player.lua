--[[/*
  Copyright (C) 1997-2018 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely.
*/

/* Program to load a sndfile and playing it using SDL audio */

--]]

local sdl = require 'sdl2_ffi'
local ffi = require 'ffi'
--https://github.com/sonoro1234/LuaJIT-libsndfile
local sf = require"sndfile_ffi"


--will run in a separate thread and lua state
local function fillerup(spec)

    local ffi = require"ffi"
    local sdl = require"sdl2_ffi"
    local sndf = require"sndfile_ffi"

    local spec = ffi.cast("SDL_AudioSpec*",spec)

    local typebuffer,lenfac = sdl.audio_buffer_type(spec[0])
    
    local bufpointer = typebuffer.."*"
    local readfunc = "readf_"..typebuffer
    print("Init audio:",spec[0].freq,bufpointer,readfunc)
    
    return function(ud,stream,len)
        local sf = ffi.cast("SNDFILE_ref*",ud)
        local lenf = len*lenfac
        assert(lenf == math.floor(lenf))
        streamf = ffi.cast(bufpointer,stream) 
        sf[readfunc](sf,streamf,lenf)
    end
end


    local filename = "sample.wav";

    --/* Enable standard application logging */
    sdl.LogSetPriority(sdl.LOG_CATEGORY_APPLICATION, sdl.LOG_PRIORITY_INFO);

    --/* Load the SDL library */
    if (sdl.Init(sdl.INIT_AUDIO + sdl.INIT_EVENTS) < 0) then
        sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "Couldn't initialize SDL: %s\n", sdl.GetError());
        return (1);
    end


    local sf1 = sf.Sndfile(filename)
    local spec = ffi.new"SDL_AudioSpec[1]"
    spec[0].freq = sf1:samplerate();
    spec[0].format = sdl.AUDIO_S16; --try others
    spec[0].channels = sf1:channels();
    spec[0].callback = sdl.MakeAudioCallback(fillerup,spec)--;
    spec[0].userdata = sf1

    --/* Show the list of available drivers */
    sdl.Log("Available audio drivers:");
    for i = 0,sdl.GetNumAudioDrivers()-1 do
        sdl.Log("%i: %s",ffi.new("int", i), sdl.GetAudioDriver(i));
    end

    sdl.Log("Using audio driver: %s\n", sdl.GetCurrentAudioDriver());

        --/* Initialize fillerup() variables */
    local device = sdl.OpenAudioDevice(nil, sdl.FALSE, spec, nil, 0);
    if (device==0) then
        sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "Couldn't open audio: %s\n", sdl.GetError());
        sf1:close()
        quit(2);
    end

    --/* Let the audio run */
    sdl.PauseAudioDevice(device, sdl.FALSE);


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


    --/* Clean up on signal */
    sdl.CloseAudioDevice(device);
    sf1:close()
    sdl.Quit();

