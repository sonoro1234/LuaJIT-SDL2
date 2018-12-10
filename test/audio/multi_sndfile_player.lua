
local sdl = require 'sdl2_ffi'
local ffi = require 'ffi'
--https://github.com/sonoro1234/LuaJIT-libsndfile
local sndf = require"sndfile_ffi"
local AudioPlayer = require"sdlAudioPlayer"

-----------------------main--------------------------------------
local filename = "african_roomS.wav";

--/* Enable standard application logging */
sdl.LogSetPriority(sdl.LOG_CATEGORY_APPLICATION, sdl.LOG_PRIORITY_INFO);

--/* Load the SDL library */
if (sdl.Init(sdl.INIT_AUDIO + sdl.INIT_EVENTS) < 0) then
    sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "Couldn't initialize SDL: %s\n", sdl.GetError());
    return (1);
end
	
--copy specs from file
local info = sndf.get_info(filename)
local audioplayer,err = AudioPlayer({
    --device = device_name,
    freq = info.samplerate, 
    format = sdl.AUDIO_S16SYS,
    channels = info.channels, 
    samples = 1024})

--insert several files
for i=1,10 do
	--filename, level, timeoffset
	audioplayer:insert(filename,(11-i)*0.1,i*0.6)
end
--show them
for node in audioplayer:nodes() do
    print("node",node.sf)
end

--play them 7 secs
audioplayer:start()
sdl.Delay(7000);
--close
audioplayer:close()
sdl.Quit();

