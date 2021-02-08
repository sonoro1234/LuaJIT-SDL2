rem set your PATH if necessary for gcc and lua with:
set PATH=C:\anima;C:\mingws\i686-7.2.0-release-posix-dwarf-rt_v5-rev1\mingw32\bin;%PATH%
::set PATH=%PATH%;C:\x86_64-8.1.0-release-posix-seh-rt_v6-rev0\mingw64\bin;C:\luaGL;
::gcc -E -dD -I ../SDL/include/ ../SDL/include/SDL.h 
luajit.exe ./generator.lua 
::type tmp.lua glfw_base.lua > glfw.lua
::del tmp.lua

cmd /k

