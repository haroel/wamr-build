cmake_minimum_required(VERSION 3.21)

project(wamr_runtime LANGUAGES C ASM)

if(NOT DEFINED WAMR_ROOT_DIR)
    message(FATAL_ERROR "WAMR_ROOT_DIR must point to third_party/wasm-micro-runtime")
endif()

get_filename_component(WAMR_ROOT_DIR "${WAMR_ROOT_DIR}" ABSOLUTE)

set(WAMR_BUILD_PLATFORM "darwin" CACHE STRING "WAMR platform" FORCE)
set(WAMR_BUILD_TARGET "AARCH64" CACHE STRING "WAMR target architecture" FORCE)
set(WAMR_BUILD_INTERP 1 CACHE BOOL "Enable WAMR interpreter" FORCE)
set(WAMR_BUILD_FAST_INTERP 1 CACHE BOOL "Enable WAMR fast interpreter" FORCE)
set(WAMR_BUILD_AOT 0 CACHE BOOL "Disable WAMR AOT runtime for Apple package" FORCE)
set(WAMR_BUILD_JIT 0 CACHE BOOL "Disable WAMR LLVM JIT for Apple package" FORCE)
set(WAMR_BUILD_FAST_JIT 0 CACHE BOOL "Disable WAMR Fast JIT for Apple package" FORCE)
set(WAMR_BUILD_LIBC_BUILTIN 1 CACHE BOOL "Enable WAMR builtin libc" FORCE)
set(WAMR_BUILD_LIBC_WASI 1 CACHE BOOL "Enable WAMR WASI libc" FORCE)
set(WAMR_BUILD_LIB_PTHREAD 0 CACHE BOOL "Disable WAMR pthread library" FORCE)
set(WAMR_BUILD_LIB_WASI_THREADS 0 CACHE BOOL "Disable WAMR WASI threads library" FORCE)
set(WAMR_BUILD_SIMD 0 CACHE BOOL "Disable SIMD in default Apple package" FORCE)
set(WAMR_BUILD_DEBUG_INTERP 0 CACHE BOOL "Disable debug interpreter" FORCE)
set(WAMR_DISABLE_HW_BOUND_CHECK 1 CACHE BOOL "Disable hardware-trap bounds checks on Apple package" FORCE)

include("${WAMR_ROOT_DIR}/build-scripts/runtime_lib.cmake")

add_library(iwasm STATIC ${WAMR_RUNTIME_LIB_SOURCE})
set_target_properties(iwasm PROPERTIES
    OUTPUT_NAME iwasm
    POSITION_INDEPENDENT_CODE ON
)

target_include_directories(iwasm PUBLIC
    "$<BUILD_INTERFACE:${WAMR_ROOT_DIR}/core/iwasm/include>"
    "$<INSTALL_INTERFACE:include>"
)

set(WAMR_PUBLIC_HEADERS
    "${WAMR_ROOT_DIR}/core/iwasm/include/wasm_c_api.h"
    "${WAMR_ROOT_DIR}/core/iwasm/include/wasm_export.h"
    "${WAMR_ROOT_DIR}/core/iwasm/include/lib_export.h"
)

install(TARGETS iwasm
    ARCHIVE DESTINATION lib
)

install(FILES ${WAMR_PUBLIC_HEADERS}
    DESTINATION include
)
