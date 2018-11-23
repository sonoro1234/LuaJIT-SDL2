local sdl = require"sdl2_ffi"
local ffi = require"ffi"

if (sdl.init(sdl.INIT_VIDEO+sdl.INIT_TIMER) ~= 0) then

        print(string.format("Error: %s\n", sdl.getError()));
        return -1;
end

local function TestThread()
local ffi = require"ffi"
local sdl = require"sdl2_ffi"
return function(ptr)
    local cnt;
	local st = ffi.cast("struct {int data[1];SDL_mutex *mutex;}*",ptr)
	local data = st.data
	local mutex = st.mutex
    for i = 0,99 do
        sdl.delay(5);
		local ret = sdl.LockMutex(mutex)
		data[0] = data[0] + 1
		local vv = data[0]
		sdl.UnlockMutex(mutex)
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
	local st = ffi.cast("struct {int data[1];SDL_mutex *mutex;}*",ptr)
	local data = st.data
	local mutex = st.mutex
    for i = 0,99 do
        sdl.delay(4);
		local ret = sdl.LockMutex(mutex)
		data[0] = data[0] + 1
		local vv = data[0]
		sdl.UnlockMutex(mutex)
        print(string.format("\nThread counter2: %d", vv));
        cnt = i
		
    end
    return cnt;
end
end


local data = ffi.new("struct {int data[1];SDL_mutex *mutex;}")
data.mutex = sdl.createMutex()
local  threadReturnValue = ffi.new("int[1]")

print("\nSimple SDL_CreateThread test:");

local thread = sdl.createThread(sdl.MakeThreadFunc(TestThread), "TestThread",data)
local thread2 = sdl.createThread(sdl.MakeThreadFunc(TestThread2), "TestThread2",data)


if (nil == thread or nil==thread2)  then
    local err = sdl.getError()
    print(string.format("\nSDL_CreateThread failed: %s\n",ffi.string(err)));
else 
    sdl.waitThread(thread, threadReturnValue);
	sdl.waitThread(thread2, nil);
    print(string.format("\nThread returned value: %d", threadReturnValue[0]),data.data[0],"should be 200");
end

sdl.DestroyMutex(data.mutex)
sdl.Quit()

