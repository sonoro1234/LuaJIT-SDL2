local ffi = require"ffi"
local sdl = require"sdl2_ffi"
local sndf = require"sndfile_ffi"

--------------will run in a same thread and different lua state and return the callback
local function AudioInit(audioplayer,audioplayercdef,postfunc,postdata,postcode)
    --postfunc will get upvalues from AudioInit (ffi,spec)
    local function setupvalues(func)
        for i=1,math.huge do
            local name,val =debug.getupvalue(func,i)
            if not name then break end
            if not val then
                --print("searching",name)
                local found = false
                for j=1,math.huge do
                    local name2,val2 = debug.getlocal(2,j)
                    if not name2 then break end
                    --print("found",name2)
                    if name == name2 then
                        debug.setupvalue(func,i,val2)
                        found = true
                        break
                    end
                end
                if not found then error("value for upvalue "..name.." not found") end
            end
        end
    end

    local ffi = require"ffi"
    local sdl = require"sdl2_ffi"
    local sndf = require"sndfile_ffi"
    
    
    ffi.cdef(audioplayercdef)
    audioplayer = ffi.cast("audioplayer*",audioplayer)
    local root = audioplayer.root
    local spec 
    
    local typebuffer,lenfac,nchannels 
    local timefac 
    local bufpointer 
    local readfunc,writefunc
    local postfuncS
    
    --wait until device is opened
    local function setspecs()
    
        spec = audioplayer.obtained_spec[0]
        
        typebuffer,lenfac,nchannels = sdl.audio_buffer_type(spec)
        timefac = 1/spec.freq
        bufpointer = typebuffer.."*"
        readfunc = "readf_"..typebuffer
        writefunc = "writef_"..typebuffer

        postfunc = setfenv(postfunc,setmetatable({spec=spec,ffi=ffi,sdl=sdl},{__index=_G}))
        postfuncS = postfunc(postdata,postcode,typebuffer,nchannels)
    end
    setupvalues(postfunc)

    local floor = math.floor
    -- this is the real callback
    return function(ud,stream,len)
        if not spec then setspecs() end
        
        local streamTime = audioplayer.streamTime
        local lenf = len*lenfac
        assert(lenf == floor(lenf))
        local windowsize = lenf * timefac
        sdl.memset(stream, 0, len)
        local streamf = ffi.cast(bufpointer,stream)
        ffi.fill(stream,len)
        local readbuffer = ffi.new(typebuffer.."[?]",lenf*nchannels)
        local sf_node = root
        while true do
            if sf_node.next~=nil then
                sf_node = sf_node.next[0]
                local sf = sf_node.sf
                if sf.resampler~=nil then
                    sf = sf.resampler
                end

                if sf_node.timeoffset <= streamTime then --already setted 
                    local readen = tonumber(sf[readfunc](sf,readbuffer,lenf))
                    for i=0,(readen*nchannels)-1 do
                        streamf[i] = streamf[i] + readbuffer[i]*sf_node.level
                    end
                elseif sf_node.timeoffset < streamTime + windowsize then --set it here
                    --print"sett--------------------------------"
                    local frames = floor((streamTime + windowsize - sf_node.timeoffset) * spec.freq)
                    local res = sf:seek( 0, sndf.SEEK_SET)
                    local readen = tonumber(sf[readfunc](sf,readbuffer,frames))
                    local j=0
                    for i=(lenf - frames)*nchannels,((readen+lenf-frames)*nchannels)-1 do
                    --for i=(lenf - frames)*nchannels,((lenf)*nchannels)-1 do
                        streamf[i] = streamf[i] + readbuffer[j]*sf_node.level
                        j = j + 1
                    end
                end
            else break end
            
        end

        postfuncS(streamf,lenf,streamTime)
        if audioplayer.recordfile~= nil then
            audioplayer.recordfile[writefunc](audioplayer.recordfile,streamf,lenf)
        end
        audioplayer.streamTime = streamTime + lenf*timefac
    end
end
---------------------------------------------------
---------------------------------------------audioplayer interface
local audioplayercdef = [[
typedef struct sf_node sf_node;
struct sf_node
{
    SNDFILE_ref *sf;
    double level;
    double timeoffset;
    sf_node *next;
} sf_node;

typedef struct audioplayer
{
    SDL_AudioSpec wanted_spec[1];
    SDL_AudioSpec obtained_spec[1];
    sf_node root;
    SNDFILE_ref *recordfile;
    double streamTime;
    SDL_AudioDeviceID device;
    src_callback_t resampler_input_cb;
} audioplayer;
]]


ffi.cdef(audioplayercdef)
local ap_resampler_input_cb
local ancla_nodes = {}
local ancla_resam = {}
local AudioPlayer_mt = {}
AudioPlayer_mt.__index = AudioPlayer_mt
function AudioPlayer_mt:__new(t,postfunc,postdata,postcode)
    local postfunc = postfunc or function() return function() end end
    local ap = ffi.new("audioplayer")
    assert(ap.root.next == nil)
    local spec = ap.wanted_spec[0]
    spec.freq = t.freq or 44100
    spec.format = t.format or 0
    spec.channels = t.channels or 2
    spec.samples = t.samples or 0
    local callback, cbmaker = sdl.MakeAudioCallback(AudioInit,ap,audioplayercdef,postfunc,postdata,postcode)
    spec.callback = callback
    ap_resampler_input_cb = cbmaker:additional_cb(function()
        local sndf = require"sndfile_ffi"
        return sndf.resampler_input_cb
    end,"long (*) (void *cb_data, float **data)")--"src_callback_t")
    ap.resampler_input_cb = ap_resampler_input_cb
    ap.device = sdl.OpenAudioDevice(t.device, sdl.FALSE, ap.wanted_spec, ap.obtained_spec,sdl.AUDIO_ALLOW_FORMAT_CHANGE);
    if ap.device == 0 then
        local err = sdl.GetError()
        return nil, err~=nil and ffi.string(err) or "unknown error opening device"
    end
    ffi.gc(ap,self.close)
    return ap
end
function AudioPlayer_mt:close()
    ffi.gc(self,nil)
    for node in self:nodes() do
        node.sf:close()
    end
    if self.recordfile ~=nil then
        self.recordfile:close()
    end
    sdl.CloseAudioDevice(self.device);

end
function AudioPlayer_mt:get_stream_time()
    self:lock()
    local ret = self.streamTime
    self:unlock()
    return ret
end
function AudioPlayer_mt:set_stream_time(time)
    self:lock()
    self.streamTime = time
    local sf_node = self.root
    while true do
        sf_node = sf_node.next[0]
        if sf_node == nil then break end
        local sf = sf_node.sf
        if sf.resampler~=nil then
            sf = sf.resampler
        end
        if sf_node.timeoffset <= time then
            local frames = math.floor((time - sf_node.timeoffset) * sf_node.sf:samplerate())
            local res = sf:seek( frames, sndf.SEEK_SET) ;
        end
    end
    self:unlock()
end
function AudioPlayer_mt:lock()
    sdl.LockAudioDevice(self.device)
end
function AudioPlayer_mt:unlock()
    sdl.UnlockAudioDevice(self.device)
end
function AudioPlayer_mt:start()
    --sdl.LockAudio()
    sdl.PauseAudioDevice(self.device, 0)
    --sdl.UnlockAudio()
end
function AudioPlayer_mt:stop()
    --sdl.LockAudio()
    sdl.PauseAudioDevice(self.device, 1)
    --sdl.UnlockAudio()
end

function AudioPlayer_mt:insert(filename,level,timeoffset)
    level = level or 1
    timeoffset = timeoffset or 0
    local sf = sndf.Sndfile(filename)
    --check channels and samplerate
    if sf:channels() ~= self.obtained_spec[0].channels then
        print(filename,"has wrong number of channels",sf:channels())
        sf:close()
        return nil
    end
    local selfkey = tostring(self)
    if sf:samplerate() ~= self.obtained_spec[0].freq then
        local resamp = sf:resampler_create(nil, nil,ap_resampler_input_cb)
        resamp:set_ratio(self.obtained_spec[0].freq/sf:samplerate())
        local anchor = ancla_resam[selfkey] or {}
        ancla_resam[selfkey] = anchor
        table.insert(anchor,resamp)
    end
    local node = ffi.new"sf_node[1]"
    local anchor = ancla_nodes[selfkey] or {}
    ancla_nodes[selfkey] = anchor
    table.insert(anchor,node)
    node[0].sf = sf
    node[0].level = level
    node[0].timeoffset = timeoffset
    
    node[0].next = self.root.next
    self:lock()
    self.root.next = node
    self:unlock()
    return node[0]
end
local recordfile_anchor
function AudioPlayer_mt:record(filename,format)
    assert(self.recordfile==nil,"AudioPlayer already has recording file.")
    local sf = sndf.Sndfile(filename,"w",self.obtained_spec[0].freq,self.obtained_spec[0].channels,format)
    recordfile_anchor = sf
    self.recordfile = sf
    return sf
end
function AudioPlayer_mt:erase(node)
    self:lock()
    local sf_node = self.root
    local anchor = ancla_nodes[tostring(self)]
    assert(anchor)
    while true do
        local prev = sf_node
        sf_node = sf_node.next[0]
        if sf_node == nil then break end
        if sf_node == node then
            --remove from ancla_nodes
            for i,nodeptr in ipairs(anchor) do
                if nodeptr[0]==node then
                    table.remove(anchor,i)
                    break
                end
            end
            prev.next = sf_node.next
            node.sf:close()
            break
        end
    end
    self:unlock()
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
return AudioPlayer