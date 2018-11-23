local sdl = require"sdl2_ffi"
local ffi = require"ffi"


if (sdl.init(sdl.INIT_VIDEO+sdl.INIT_TIMER) ~= 0) then

        print(string.format("Error: %s\n", sdl.getError()));
        return -1;
end

--/* Very simple thread - counts 0 to 9 delaying 1000ms between increments */
local function TestThread()
local sdl = require"sdl2_ffi"
return function(ptr)
    local cnt;
    for i = 0,9 do
        sdl.delay(1000);
        print(string.format("\nThread counter: %d", i));
        cnt = i
    end
    return cnt;
end
end

local  threadReturnValue = ffi.new("int[1]")

print("\nSimple SDL_CreateThread test:");

local thread = sdl.createThread(sdl.MakeThreadFunc(TestThread), "TestThread",nil)

if (nil == thread)  then
    local err = sdl.getError()
    print(string.format("\nSDL_CreateThread failed: %s\n",ffi.string(err)));
else 
    sdl.waitThread(thread, threadReturnValue);
    print(string.format("\nThread returned value: %d", threadReturnValue[0]));
end

