cmake_minimum_required(VERSION 3.22.1)
project(yabot_llama)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED YABOT_LLAMA_DIR)
  set(YABOT_LLAMA_DIR "/Users/rizal/Library/Developer/ya-deps/llama.cpp")
endif()

set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_BLAS OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)

add_subdirectory(${YABOT_LLAMA_DIR} ${CMAKE_BINARY_DIR}/llama-build)

add_library(yabot_llama SHARED yabot_llama_jni.cpp)
target_include_directories(yabot_llama PRIVATE
  ${YABOT_LLAMA_DIR}/include
  ${YABOT_LLAMA_DIR}/ggml/include
)
target_link_libraries(yabot_llama llama ggml android log)
