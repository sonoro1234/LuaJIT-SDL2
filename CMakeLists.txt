PROJECT(sdl2_ffi)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.13)


set(SDL_STATIC OFF CACHE INTERNAL "dont build static!")

add_subdirectory(SDL EXCLUDE_FROM_ALL)
set_target_properties(SDL2 PROPERTIES OUTPUT_NAME "SDL2")

add_custom_target(snd2_ffi ALL)
add_dependencies(snd2_ffi SDL2)

install(TARGETS SDL2 RUNTIME DESTINATION ${LUAJIT_BIN}
					LIBRARY DESTINATION ${LUAJIT_BIN})
INSTALL(FILES sdl2_ffi.lua sdlAudioPlayer.lua DESTINATION ${LUAJIT_BIN}/lua)


