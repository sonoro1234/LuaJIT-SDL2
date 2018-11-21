local sdl = require"sdl2_ffi"
local ffi = require"ffi"

local function ffistring(cd)
	if not cd then
		return nil
	else
		return ffi.string(cd)
	end
end
if (sdl.init(sdl.INIT_AUDIO+sdl.INIT_TIMER) ~= 0) then
        print(string.format("Error: %s\n", sdl.GetError()));
        return -1;
end
--print("current driver:",ffistring(sdl.GetCurrentAudioDriver()))
for i = 0, sdl.GetNumAudioDrivers()-1 do
    local driver_name = ffistring(sdl.GetAudioDriver(i));
	print(i,driver_name)
    if (sdl.AudioInit(driver_name)<0) then
		local errstr = ffistring(sdl.GetError())
        print(string.format("Audio driver failed to initialize: %s error: %s\n", driver_name,errstr));
    else
		print("current driver:",ffistring(sdl.GetCurrentAudioDriver()))
		print"\tplaying audio devices:"
		for i=0,sdl.getNumAudioDevices(0)-1 do
			print('\t\tdevice:',i,ffistring(sdl.getAudioDeviceName(i,0)))
		end
		print"\trecording audio devices:"
		for i=0,sdl.getNumAudioDevices(1)-1 do
			print('\t\tdevice:',i,ffistring(sdl.getAudioDeviceName(i,1)))
		end
		sdl.AudioQuit();
	end
end

sdl.Quit()