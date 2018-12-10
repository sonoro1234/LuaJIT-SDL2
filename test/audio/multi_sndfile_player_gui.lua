
local sdl = require 'sdl2_ffi'
local ffi = require 'ffi'
--https://github.com/sonoro1234/LuaJIT-libsndfile
local sndf = require"sndfile_ffi"

local AudioPlayer = require"sdlAudioPlayer"

--------------------------will run in audio thread after playing files
local delaycdef = [[typedef struct delay{double feedback[1];double delay[1];double maxdelay;} delay]]
ffi.cdef(delaycdef)
local fxdata = ffi.new("delay",{ffi.new("double[1]",0.0),ffi.new("double[1]",1),2})

local function delayfunc(data,code,typebuffer,nchannels)
    ffi.cdef(code)
    data = ffi.cast("delay*",data)
    local index = 0
    local lenb = math.floor(spec.freq*nchannels*data.maxdelay)
    local buffer = ffi.new(typebuffer.."[?]",lenb)

    return function(streamf,lenf,streamTime)
        local lenbe = math.floor(spec.freq*nchannels*data.delay[0])
        local j
        for i=0,(lenf*nchannels)-1 do
            j = index + i
            if j > lenbe-1 then j = j - lenbe end
            streamf[i] = streamf[i] + buffer[j]
            buffer[j] = streamf[i] *data.feedback[0]
        end
        index = index + lenf*nchannels
        if index > lenbe-1 then index = index - lenbe end
    end
end

local function ffi_string(cd)
    if not cd then
        return nil
    else
        return ffi.string(cd)
    end
end
------------------------------------------------------------------------
-----------------------main--------------------------------------

local ig = require"imgui.sdl"

local filename = "african_roomS.wav";
--local filename = "arugh.wav" --"sample.wav";

    --/* Enable standard application logging */
sdl.LogSetPriority(sdl.LOG_CATEGORY_APPLICATION, sdl.LOG_PRIORITY_INFO);
if (sdl.Init(sdl.INIT_VIDEO + sdl.INIT_AUDIO + sdl.INIT_EVENTS) < 0) then
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
    samples = 1024},
    delayfunc,fxdata,delaycdef)

if not audioplayer then print(err) end
print("audioplayer.recordfile",audioplayer.recordfile)
print"--------------wanted"
audioplayer.wanted_spec[0]:print()
print("---------------opened device",device)
audioplayer.obtained_spec[0]:print()

----------------------------------------------------

--insert 3 files
--level 0.1, timeoffset 0
if not audioplayer:insert(filename,0.1,0) then error"failed insert" end
--will not load, diferent samplerate and channels
local node2 = audioplayer:insert("arugh.wav",0.1,0.75)
assert(not node2)
audioplayer:insert(filename,0.1,1.5)

for node in audioplayer:nodes() do
    print("node",node.sf)
end

--audioplayer:erase(node2)
print"after erase"
for node in audioplayer:nodes() do
    print("node",node.sf)
end

--audioplayer:record("recording.wav",sndf.SF_FORMAT_WAV+sndf.SF_FORMAT_FLOAT)
print("audioplayer.recordfile",audioplayer.recordfile)

print"--------------------------------------"
--------------------------------------------------

sdl.gL_SetAttribute(sdl.GL_CONTEXT_FLAGS, sdl.GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
sdl.gL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, sdl.GL_CONTEXT_PROFILE_CORE);
sdl.gL_SetAttribute(sdl.GL_DOUBLEBUFFER, 1);
sdl.gL_SetAttribute(sdl.GL_DEPTH_SIZE, 24);
sdl.gL_SetAttribute(sdl.GL_STENCIL_SIZE, 8);
sdl.gL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3);
sdl.gL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 2);

local window = sdl.createWindow("ImGui SDL2+OpenGL3 example", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, 700, 500, sdl.WINDOW_OPENGL+sdl.WINDOW_RESIZABLE);

local gl_context = sdl.gL_CreateContext(window);
sdl.gL_SetSwapInterval(1); -- Enable vsync

local ig_Impl = ig.Imgui_Impl_SDL_opengl3()

ig_Impl:Init(window, gl_context)

local igio = ig.GetIO()

local done = false;
local streamtime = ffi.new("float[1]")
while (not done) do

    local event = ffi.new"SDL_Event"
    while (sdl.pollEvent(event) ~=0) do
        ig.lib.ImGui_ImplSDL2_ProcessEvent(event);
        if (event.type == sdl.QUIT) then
            done = true;
        end
        if (event.type == sdl.WINDOWEVENT and event.window.event == sdl.WINDOWEVENT_CLOSE and event.window.windowID == sdl.getWindowID(window)) then
            done = true;
        end
    end

    sdl.gL_MakeCurrent(window, gl_context);


    ig_Impl:NewFrame()
    -------audio gui
    if ig.Button("start") then
        audioplayer:start()
    end
    if ig.Button("stop") then
        audioplayer:stop()
    end

    streamtime[0] = audioplayer:get_stream_time()
    --print(streamtime[0], audioplayer:get_stream_time())
    if ig.SliderFloat("time",streamtime,0,15) then
        audioplayer:set_stream_time(streamtime[0])
    end

    ig.SliderScalar("delay",ig.lib.ImGuiDataType_Double,fxdata.delay,ffi.new("double[1]",0),ffi.new("double[1]",fxdata.maxdelay))

    ig.SliderScalar("feedback",ig.lib.ImGuiDataType_Double,fxdata.feedback,ffi.new("double[1]",0),ffi.new("double[1]",1))

    if ig.Button("nodes") then
        print"----------nodes---------------"
        print(audioplayer.root.next[0])
        for node in audioplayer:nodes() do
            print(node,node.next[0],node.level,node.timeoffset)
            print(node.sf,node.sf:samplerate(),node.sf:channels(),node.sf:format())
        end
    end

    if ig.Button("specs") then
        audioplayer.obtained_spec[0]:print()
    end
	
	if audioplayer.recordfile.sf~=nil then
	if ig.Button("close record") then
        audioplayer.recordfile:close()
    end
	end
    -- end audio gui
    ig_Impl:Render()
    sdl.gL_SwapWindow(window);
end

audioplayer:close()
ig_Impl:destroy()

sdl.gL_DeleteContext(gl_context);
sdl.destroyWindow(window);
sdl.Quit();

