local sdl = require"sdl2_ffi"
local ffi = require"ffi"

local oldffistring = ffi.string
ffi.string = function(data) 
    if data == nil then
        return "nil"
    else
        return oldffistring(data)
    end
end

local sampleHz = 48000

local function AudioInit()
local ffi = require"ffi"
local sin = math.sin
local sdl = require"sdl2_ffi"
return function(ud,stream,len)
    
    local buf = ffi.cast("float*",stream)
    local udc = ffi.cast("struct {double Phase;double dPhase;}*",ud)
    local lenf = len/ffi.sizeof"float"

    for i=0,lenf-2,2 do
        local sample = sin(udc.Phase)*0.01
        udc.Phase = udc.Phase + udc.dPhase
        buf[i] = sample
        buf[i+1] = sample
    end
end
end

local ud = ffi.new"struct {double Phase;double dPhase;}"
local function setFreq(ff)
    sdl.LockAudio()
    ud.dPhase = 2 * math.pi * ff / sampleHz
    sdl.UnlockAudio()
end

local want = ffi.new"SDL_AudioSpec[1]"
local have = ffi.new"SDL_AudioSpec[1]"
want[0].freq = sampleHz;
want[0].format = sdl.AUDIO_F32;
want[0].channels = 2;
want[0].samples = 512 --4096;
want[0].callback = sdl.MakeAudioCallback(AudioInit) 
want[0].userdata = ud

if (sdl.init(sdl.INIT_AUDIO+sdl.INIT_TIMER) ~= 0) then
        print(string.format("Error: %s\n", sdl.getError()));
        return -1;
end
print"audio drivers:"
for i=0,sdl.getNumAudioDrivers()-1 do
   print('driver:',i, ffi.string(sdl.getAudioDriver(i)))
end
print("current driver",ffi.string(sdl.GetCurrentAudioDriver()))
print"audio devices:"
for i=0,sdl.getNumAudioDevices(0)-1 do
   print('device:',i,ffi.string(sdl.getAudioDeviceName(i,0)))
end

local dev = sdl.openAudioDevice(nil, 0, want, have, 0)
print("dev",dev)

if (dev == 0) then
    sdl.log("Failed to open audio: %s", sdl.GetError());
else 
    sdl.PauseAudioDevice(dev, 0); -- start audio playing. 
    for i=1,100 do
        setFreq(math.random()*500 + 100)
        sdl.Delay(100)
    end
    sdl.PauseAudioDevice(dev, 1)
    sdl.CloseAudioDevice(dev);
end

sdl.Quit()