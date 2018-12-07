--[[/*
  Copyright (C) 1997-2018 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely.
*/

/* Program to load a wave file and loop playing it using SDL audio */

/* loopwaves.c is much more robust in handling WAVE files --
    This is only for simple WAVEs
*/
--]]

local sdl = require 'sdl2_ffi'
local ffi = require 'ffi'


local ud_code = [[
typedef struct
{
    SDL_AudioSpec spec[1];
    Uint8 *sound[1];               /* Pointer to wave data */
    Uint32 soundlen[1];            /* Length of wave data */
    int soundpos;               /* Current play position */
} wave;
]]

ffi.cdef(ud_code)
local wave = ffi.new"wave"
local device;

--/* Call this instead of exit(), so we can clean up SDL: atexit() is evil. */
function quit(rc)
    sdl.Quit();
    os.exit(rc);
end

function close_audio()
    if (device ~= 0) then
        sdl.CloseAudioDevice(device);
        device = 0;
    end
end


function open_audio()

    --/* Initialize fillerup() variables */
    device = sdl.OpenAudioDevice(nil, sdl.FALSE, wave.spec, nil, 0);
    if (device==0) then
        sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "Couldn't open audio: %s\n", sdl.GetError());
        sdl.FreeWAV(wave.sound);
        quit(2);
    end


    --/* Let the audio run */
    sdl.PauseAudioDevice(device, sdl.FALSE);
end

function reopen_audio()
    close_audio();
    open_audio();
end


local function fillerup(udcode)
    local ffi = require"ffi"
    local sdl = require"sdl2_ffi"
    local waveptr = ffi.new"Uint8[1]"
    ffi.cdef(udcode)
    return function(ud,stream,len)
    
        local waveleft;
        local wave = ffi.cast("wave*",ud)
        --/* Set up the pointers */
        waveptr = wave.sound[0] + wave.soundpos;
        waveleft = wave.soundlen[0] - wave.soundpos;
    
        --/* Go! */
        while (waveleft <= len) do
            sdl.C.SDL_memcpy(stream, waveptr, waveleft);
            stream = stream + waveleft;
            len = len - waveleft;
            waveptr = wave.sound[0];
            waveleft = wave.soundlen[0];
            wave.soundpos = 0;
        end
        sdl.C.SDL_memcpy(stream, waveptr, len);
        wave.soundpos = wave.soundpos + len;
    end
end
local done = false;



    local filename = ffi.new"char[4096]";

    --/* Enable standard application logging */
    sdl.LogSetPriority(sdl.LOG_CATEGORY_APPLICATION, sdl.LOG_PRIORITY_INFO);

    --/* Load the SDL library */
    if (sdl.Init(sdl.INIT_AUDIO + sdl.INIT_EVENTS) < 0) then
        sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "Couldn't initialize SDL: %s\n", sdl.GetError());
        return (1);
    end

    sdl.strlcpy(filename, "sample.wav", ffi.sizeof(filename));

    --/* Load the wave file into memory */
    if (sdl.LoadWAV(filename, wave.spec, wave.sound, wave.soundlen) == nil) then
        sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "Couldn't load %s: %s\n", filename, sdl.GetError());
        quit(1);
    end

    wave.spec[0].callback = sdl.MakeAudioCallback(fillerup,ud_code)
    wave.spec[0].userdata = wave

    --/* Show the list of available drivers */
    sdl.Log("Available audio drivers:");
    for i = 0,sdl.GetNumAudioDrivers()-1 do
        sdl.Log("%i: %s",ffi.new("int", i), sdl.GetAudioDriver(i));
    end

    sdl.Log("Using audio driver: %s\n", sdl.GetCurrentAudioDriver());

    open_audio();

    sdl.FlushEvents(sdl.AUDIODEVICEADDED, sdl.AUDIODEVICEREMOVED);


    while (not done) do
        local event = ffi.new"SDL_Event"

        while (sdl.PollEvent(event) > 0) do
            if (event.type == sdl.QUIT) then
                done = true;
            end
            if ((event.type == sdl.AUDIODEVICEADDED and not event.adevice.iscapture==1) or
                (event.type == sdl.AUDIODEVICEREMOVED and not event.adevice.iscapture==1 and event.adevice.which == device)) then
                reopen_audio();
            end
        end
        sdl.Delay(100);
    end


    --/* Clean up on signal */
    close_audio();
    sdl.FreeWAV(wave.sound);
    sdl.Quit();
    return (0);
