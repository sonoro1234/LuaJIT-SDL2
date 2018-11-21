local sdl = require"sdl2_ffi"
local ffi = require"ffi"
ffi.cdef[[void SDL_AtomicIncRef(SDL_atomic_t* a)]]
if (sdl.init(sdl.INIT_VIDEO+sdl.INIT_TIMER) ~= 0) then

        print(string.format("Error: %s\n", sdl.getError()));
        return -1;
end

local function TestThread()
local ffi = require"ffi"
local sdl = require"sdl2_ffi"
return function(ptr)
    local cnt;
	local atomic = ffi.cast("SDL_atomic_t *",ptr)
    for i = 0,99 do
        sdl.delay(5);
		sdl.AtomicAdd(atomic,1)
		local vv = sdl.AtomicGet(atomic)
        print(string.format("\nThread counter1: %d", vv));
        cnt = i
    end
    return cnt;
end
end

local function TestThread2()
local ffi = require"ffi"
local sdl = require"sdl2_ffi"
return function(ptr)
    local cnt;
	local atomic = ffi.cast("SDL_atomic_t *",ptr)
    for i = 0,99 do
        sdl.delay(4);
		sdl.AtomicAdd(atomic,1)
		local vv = sdl.AtomicGet(atomic)
        print(string.format("\nThread counter2: %d", vv));
        cnt = i
    end
    return cnt;
end
end


--local data = ffi.new("SDL_atomic_t *atomic")
local data = ffi.new("SDL_atomic_t[1]")
local  threadReturnValue = ffi.new("int[1]")

print("\nSimple SDL_CreateThread test:");

local thread = sdl.createThread(sdl.MakeThreadFunc(TestThread), "TestThread",data[0],nil,nil)
local thread2 = sdl.createThread(sdl.MakeThreadFunc(TestThread2), "TestThread2",data[0],nil,nil)


if (nil == thread or nil==thread2)  then
    local err = sdl.getError()
    print(string.format("\nSDL_CreateThread failed: %s\n",ffi.string(err)));
else 
    sdl.waitThread(thread, threadReturnValue);
	sdl.waitThread(thread2, nil);
    print(string.format("\nThread returned value: %d", threadReturnValue[0]),sdl.AtomicGet(data),"should be 200");
end

sdl.Quit()

