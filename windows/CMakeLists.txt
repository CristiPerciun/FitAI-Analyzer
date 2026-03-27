# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(fitai_analyzer LANGUAGES CXX)

# --- Firebase SDK pre-download (workaround: path con spazi rompe file(ARCHIVE_EXTRACT), usiamo PowerShell) ---
set(FIREBASE_SDK_VERSION "13.4.0")
set(FIREBASE_SDK_PATH "${CMAKE_BINARY_DIR}/extracted/firebase_cpp_sdk_windows")

if(NOT EXISTS "${FIREBASE_SDK_PATH}/include/firebase/version.h")
  message(STATUS "Firebase C++ SDK non trovato, download in corso...")
  set(firebase_sdk_url "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_windows_${FIREBASE_SDK_VERSION}.zip")
  set(firebase_sdk_filename "${CMAKE_BINARY_DIR}/firebase_cpp_sdk_windows_${FIREBASE_SDK_VERSION}.zip")
  set(extracted_path "${CMAKE_BINARY_DIR}/extracted")

  if(NOT EXISTS "${firebase_sdk_filename}")
    message(STATUS "Download Firebase SDK da ${firebase_sdk_url}")
    file(DOWNLOAD "${firebase_sdk_url}" "${firebase_sdk_filename}"
      SHOW_PROGRESS
      STATUS download_status
      LOG download_log)
    list(GET download_status 0 status_code)
    if(NOT status_code EQUAL 0)
      message(FATAL_ERROR "Download Firebase SDK fallito: ${download_log}")
    endif()
  endif()

  if(EXISTS "${extracted_path}")
    file(REMOVE_RECURSE "${extracted_path}")
  endif()
  file(MAKE_DIRECTORY "${extracted_path}")
  message(STATUS "Estrazione Firebase SDK con PowerShell (evita errore ZIP con path spazi)...")
  execute_process(
    COMMAND PowerShell -NoProfile -ExecutionPolicy Bypass -Command
      "Expand-Archive -Path '${firebase_sdk_filename}' -DestinationPath '${extracted_path}' -Force"
    RESULT_VARIABLE extract_result
    OUTPUT_VARIABLE extract_output
    ERROR_VARIABLE extract_error)
  if(NOT extract_result EQUAL 0)
    message(FATAL_ERROR "Estrazione Firebase SDK fallita: ${extract_error} ${extract_output}")
  endif()
  if(NOT EXISTS "${FIREBASE_SDK_PATH}/include/firebase/version.h")
    message(FATAL_ERROR "Firebase SDK estratto ma struttura errata. Controlla: ${FIREBASE_SDK_PATH}")
  endif()
  message(STATUS "Firebase SDK pronto.")
endif()

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "fitai_analyzer")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100" /FS)
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# Profile uses the same /MD runtime as Release. firebase_core only sets
# IMPORTED_LOCATION_DEBUG/RELEASE on Firebase prebuilt libs; Profile would
# otherwise link Debug .lib and fail (e.g. _calloc_dbg / _CrtDbgReport).
set(_FIREBASE_CPP_IMPORT_LIBS firebase_app firebase_auth firebase_storage firebase_firestore)
foreach(_fblib IN LISTS _FIREBASE_CPP_IMPORT_LIBS)
  if(TARGET ${_fblib})
    get_target_property(_imp_dbg ${_fblib} IMPORTED_LOCATION_DEBUG)
    if(_imp_dbg)
      string(REPLACE "Debug" "Release" _imp_prof ${_imp_dbg})
      set_target_properties(${_fblib} PROPERTIES
        IMPORTED_LOCATION_PROFILE "${_imp_prof}")
    endif()
  endif()
endforeach()

# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
