PROJECT(sdl2_ffi)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.13)


set(SDL_STATIC OFF CACHE INTERNAL "dont build static!")
#set(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR}/install)
add_subdirectory(SDL EXCLUDE_FROM_ALL)

add_custom_target(snd2_ffi ALL)
add_dependencies(snd2_ffi SDL2)

install(TARGETS SDL2 RUNTIME DESTINATION ${LUAJIT_BIN})
INSTALL(FILES sdl2_ffi.lua sdlAudioPlayer.lua DESTINATION ${LUAJIT_BIN}/lua)


