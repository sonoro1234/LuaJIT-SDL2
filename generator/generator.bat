rem set your PATH if necessary for gcc and lua with:
set PATH=%PATH%;C:\mingw32\bin;C:\luaGL;
::set PATH=%PATH%;C:\x86_64-8.1.0-release-posix-seh-rt_v6-rev0\mingw64\bin;C:\luaGL;
::gcc -E -dD -I ../SDL/include/ ../SDL/include/SDL.h 
luajit.exe ./generator.lua 
::type tmp.lua glfw_base.lua > glfw.lua
::del tmp.lua

cmd /k

