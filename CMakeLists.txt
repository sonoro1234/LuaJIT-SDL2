PROJECT(sdl2_ffi)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.13)


set(SDL_STATIC OFF CACHE INTERNAL "dont build static!")
add_subdirectory(SDL) #EXCLUDE_FROM_ALL)
#get_directory_property(SDL2 DIRECTORY SDL DEFINITION SDL2)
#message(STATUS "SDL2 is: ${SDL2}")

install(TARGETS SDL2 RUNTIME DESTINATION .)
INSTALL(FILES sdl2_ffi.lua DESTINATION ./lua)
INSTALL(FILES luajit-async/lj-async/callback.lua luajit-async/lj-async/thread.lua DESTINATION ./lua/lj-async/)

