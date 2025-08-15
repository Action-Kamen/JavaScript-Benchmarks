cmake_minimum_required(VERSION 3.10)
project(benchmarks C)

# Use C99
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Basic warnings
add_compile_options(-Wall -Wextra)

# Feature test macros so quickjs-libc.c sees 'environ' and POSIX APIs.
# Provide as compile definitions on targets below.
set(POSIX_FEATURE_DEFS "_GNU_SOURCE" "_POSIX_C_SOURCE=199309L")

#
# QuickJS paths (user-overridable)
#
# Defaults assume your QuickJS checkout is at ./engines/quickjs
set(QUICKJS_SOURCE_DIR "${CMAKE_SOURCE_DIR}/engines/quickjs" CACHE PATH "QuickJS source dir (contains quickjs-libc.c and headers)")
set(QUICKJS_BUILD_DIR  "${QUICKJS_SOURCE_DIR}/build" CACHE PATH "QuickJS build dir (expected to contain static library like libqjs.a)")
set(QUICKJS_INCLUDE_DIR "${QUICKJS_SOURCE_DIR}" CACHE PATH "QuickJS include directory")

#
# Locate QuickJS static library (try common names and locations)
#
set(QUICKJS_LIB "" CACHE FILEPATH "Full path to QuickJS static library (libqjs.a)")

if(NOT QUICKJS_LIB)
  set(_candidate_names "libqjs.a" "libquickjs.a")
  foreach(_n IN LISTS _candidate_names)
    if(EXISTS "${QUICKJS_BUILD_DIR}/${_n}")
      set(QUICKJS_LIB "${QUICKJS_BUILD_DIR}/${_n}" CACHE FILEPATH "QuickJS static library" FORCE)
      break()
    endif()
  endforeach()
endif()

# fallback: search for any .a in source dir or build dir
if(NOT QUICKJS_LIB)
  file(GLOB _found_a
    "${QUICKJS_BUILD_DIR}/*.a"
    "${QUICKJS_SOURCE_DIR}/*.a"
  )
  if(_found_a)
    list(GET _found_a 0 _first_lib)
    set(QUICKJS_LIB "${_first_lib}" CACHE FILEPATH "QuickJS static library" FORCE)
  endif()
endif()

# If still not found, show a helpful error telling how to fix it.
if(NOT QUICKJS_LIB OR NOT EXISTS "${QUICKJS_LIB}")
  message(FATAL_ERROR
    "QuickJS static library not found.\n\n"
    "Searched:\n"
    "  - expected build path: ${QUICKJS_BUILD_DIR}/libqjs.a\n"
    "  - fallback paths under: ${QUICKJS_BUILD_DIR} and ${QUICKJS_SOURCE_DIR}\n\n"
    "Solutions:\n"
    "  1) Build QuickJS in the source tree:\n"
    "       cd ${QUICKJS_SOURCE_DIR} && make\n"
    "     and ensure libqjs.a exists (copy it to ${QUICKJS_BUILD_DIR}/libqjs.a if necessary).\n\n"
    "  2) Or run cmake with an explicit QUICKJS_BUILD_DIR / QUICKJS_SOURCE_DIR:\n"
    "       cmake -DQUICKJS_SOURCE_DIR=/path/to/quickjs -DQUICKJS_BUILD_DIR=/path/to/quickjs/build ..\n\n"
    "  3) Or set QUICKJS_LIB directly:\n"
    "       cmake -DQUICKJS_LIB=/full/path/to/libqjs.a ..\n"
  )
endif()

# Print configuration summary for debugging
message(STATUS "Configured benchmark build")
message(STATUS " QuickJS source dir : ${QUICKJS_SOURCE_DIR}")
message(STATUS " QuickJS build dir  : ${QUICKJS_BUILD_DIR}")
message(STATUS " QuickJS include dir: ${QUICKJS_INCLUDE_DIR}")
message(STATUS " QuickJS static lib : ${QUICKJS_LIB}")
message(STATUS " Output directory    : ${CMAKE_BINARY_DIR}")

# Include dirs
include_directories(${QUICKJS_INCLUDE_DIR} ${CMAKE_SOURCE_DIR})

# Common libs to link against
set(BENCH_COMMON_LIBS ${QUICKJS_LIB} m pthread)

# helper macro to apply compile defs to a target
macro(apply_common_defs tgt)
  target_compile_definitions(${tgt} PRIVATE ${POSIX_FEATURE_DEFS})
endmacro()

# run_sunspider_like: compile quickjs-libc.c into the executable so js_init_module_std is available.
add_executable(run_sunspider_like
    run_sunspider_like.c
    "${QUICKJS_SOURCE_DIR}/quickjs-libc.c"
)
target_include_directories(run_sunspider_like PRIVATE ${QUICKJS_INCLUDE_DIR} ${CMAKE_SOURCE_DIR})
target_link_libraries(run_sunspider_like PRIVATE ${BENCH_COMMON_LIBS})
apply_common_defs(run_sunspider_like)

# run_octane: same
add_executable(run_octane
    run_octane.c
    "${QUICKJS_SOURCE_DIR}/quickjs-libc.c"
)
target_include_directories(run_octane PRIVATE ${QUICKJS_INCLUDE_DIR} ${CMAKE_SOURCE_DIR})
target_link_libraries(run_octane PRIVATE ${BENCH_COMMON_LIBS})
apply_common_defs(run_octane)

# Put built binaries in the top-level build directory for convenience
set_target_properties(run_sunspider_like PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set_target_properties(run_octane PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

# Provide a small 'info' target to print the important paths at build time
add_custom_target(bench-info
  COMMAND ${CMAKE_COMMAND} -E echo "QuickJS source dir: ${QUICKJS_SOURCE_DIR}"
  COMMAND ${CMAKE_COMMAND} -E echo "QuickJS build dir : ${QUICKJS_BUILD_DIR}"
  COMMAND ${CMAKE_COMMAND} -E echo "QuickJS lib path  : ${QUICKJS_LIB}"
  COMMENT "Show configured QuickJS paths"
)

# End of CMakeLists.txt
