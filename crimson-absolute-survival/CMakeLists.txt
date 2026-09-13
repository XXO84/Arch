cmake_minimum_required(VERSION 3.20)
project(CrimsonDesertAbsoluteSurvival LANGUAGES CXX)

if(NOT WIN32)
  message(FATAL_ERROR "Windows x64 only")
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

include(FetchContent)

FetchContent_Declare(
  minhook
  GIT_REPOSITORY https://github.com/TsudaKageyu/minhook.git
  GIT_TAG master
)
FetchContent_MakeAvailable(minhook)

set(SAFETYHOOK_FETCH_ZYDIS ON CACHE BOOL "" FORCE)
set(SAFETYHOOK_BUILD_TEST OFF CACHE BOOL "" FORCE)
set(SAFETYHOOK_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
  safetyhook
  GIT_REPOSITORY https://github.com/cursey/safetyhook.git
  GIT_TAG f44cc070a8340f2f26649553c49533475417304d
)
FetchContent_MakeAvailable(safetyhook)

add_library(AbsoluteSurvival SHARED
  src/absolute_survival_main.cpp
  src/durability_guard.cpp
  src/game/player.cpp
  src/game/inventory.cpp
  src/mem/scanner.cpp
)

target_include_directories(AbsoluteSurvival PRIVATE src)
target_link_libraries(AbsoluteSurvival PRIVATE minhook safetyhook)
target_compile_definitions(AbsoluteSurvival PRIVATE
  WIN32_LEAN_AND_MEAN
  NOMINMAX
  _CRT_SECURE_NO_WARNINGS
)

set_target_properties(AbsoluteSurvival PROPERTIES
  PREFIX ""
  SUFFIX ".asi"
  OUTPUT_NAME "CrimsonDesert_AbsoluteSurvival"
)

if(MSVC)
  target_compile_options(AbsoluteSurvival PRIVATE /W4 /guard:cf /utf-8 /EHsc)
  target_link_options(AbsoluteSurvival PRIVATE /DYNAMICBASE /HIGHENTROPYVA /NXCOMPAT /guard:cf)
endif()
