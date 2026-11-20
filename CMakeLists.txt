cmake_minimum_required(VERSION 3.20)

project(MetalPhysicsEngine LANGUAGES CXX OBJCXX)

if(NOT APPLE)
    message(FATAL_ERROR "MetalPhysicsEngine requires macOS and the Metal framework")
endif()

file(GLOB_RECURSE ENGINE_SOURCES CONFIGURE_DEPENDS
    "${PROJECT_SOURCE_DIR}/src/*.cpp"
    "${PROJECT_SOURCE_DIR}/src/*.cc"
    "${PROJECT_SOURCE_DIR}/src/*.cxx"
    "${PROJECT_SOURCE_DIR}/src/*.mm"
)

add_executable(MetalPhysicsEngine main.cpp ${ENGINE_SOURCES}
        src/templates/Engine.hpp
        src/render/render.hpp)
target_compile_features(MetalPhysicsEngine PRIVATE cxx_std_23)
set_target_properties(MetalPhysicsEngine PROPERTIES OBJCXX_STANDARD 17)
target_include_directories(MetalPhysicsEngine PRIVATE "${PROJECT_SOURCE_DIR}/src")

find_library(METAL_FRAMEWORK Metal REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)
find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
target_link_libraries(MetalPhysicsEngine PRIVATE
    "${METAL_FRAMEWORK}"
    "${FOUNDATION_FRAMEWORK}"
    "${QUARTZCORE_FRAMEWORK}"
    "${COCOA_FRAMEWORK}"
    "${METALKIT_FRAMEWORK}"
)

# Keep models beside the executable so loaders can use assets/models.
add_custom_target(StageModels ALL
    COMMAND "${CMAKE_COMMAND}" -E rm -rf "$<TARGET_FILE_DIR:MetalPhysicsEngine>/assets/models"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${PROJECT_SOURCE_DIR}/src/models"
        "$<TARGET_FILE_DIR:MetalPhysicsEngine>/assets/models"
    DEPENDS MetalPhysicsEngine
    VERBATIM
)

# Compile every Metal source into one library beside the executable.
file(GLOB_RECURSE METAL_SOURCES CONFIGURE_DEPENDS
    "${PROJECT_SOURCE_DIR}/src/shaders/*.metal"
)
file(GLOB_RECURSE METAL_HEADERS CONFIGURE_DEPENDS
    "${PROJECT_SOURCE_DIR}/src/shaders/*.metalh"
)

if(METAL_SOURCES)
    find_program(XCRUN_EXECUTABLE xcrun REQUIRED)
    foreach(METAL_TOOL metal metallib)
        execute_process(
            COMMAND "${XCRUN_EXECUTABLE}" -sdk macosx --find "${METAL_TOOL}"
            RESULT_VARIABLE METAL_TOOL_RESULT
            OUTPUT_QUIET ERROR_QUIET
        )
        if(NOT METAL_TOOL_RESULT EQUAL 0)
            message(FATAL_ERROR "Metal shaders require the '${METAL_TOOL}' Xcode tool")
        endif()
    endforeach()

    set(METAL_AIR_FILES)
    foreach(METAL_SOURCE IN LISTS METAL_SOURCES)
        file(RELATIVE_PATH METAL_RELATIVE_PATH
            "${PROJECT_SOURCE_DIR}/src/shaders" "${METAL_SOURCE}")
        set(METAL_AIR "${PROJECT_BINARY_DIR}/metal/${METAL_RELATIVE_PATH}.air")
        get_filename_component(METAL_AIR_DIR "${METAL_AIR}" DIRECTORY)
        add_custom_command(
            OUTPUT "${METAL_AIR}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${METAL_AIR_DIR}"
            COMMAND "${XCRUN_EXECUTABLE}" -sdk macosx metal -c
                "${METAL_SOURCE}" -I "${PROJECT_SOURCE_DIR}/src/shaders"
                "-fmodules-cache-path=${PROJECT_BINARY_DIR}/metal/module-cache"
                -o "${METAL_AIR}"
            DEPENDS "${METAL_SOURCE}" ${METAL_HEADERS}
            VERBATIM
        )
        list(APPEND METAL_AIR_FILES "${METAL_AIR}")
    endforeach()

    set(METAL_LIBRARY "${PROJECT_BINARY_DIR}/metal/PhysicsShaders.metallib")
    add_custom_command(
        OUTPUT "${METAL_LIBRARY}"
        COMMAND "${XCRUN_EXECUTABLE}" -sdk macosx metallib
            ${METAL_AIR_FILES} -o "${METAL_LIBRARY}"
        DEPENDS ${METAL_AIR_FILES}
        VERBATIM
    )
    add_custom_target(MetalShaders DEPENDS "${METAL_LIBRARY}")
    add_custom_target(StageShaders
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "$<TARGET_FILE_DIR:MetalPhysicsEngine>/assets/shaders"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${METAL_LIBRARY}"
            "$<TARGET_FILE_DIR:MetalPhysicsEngine>/assets/shaders/PhysicsShaders.metallib"
        VERBATIM
    )
    add_dependencies(StageShaders MetalShaders)
    # CLion builds the executable target before launching it.
    add_dependencies(MetalPhysicsEngine StageShaders)
endif()

include(CTest)
if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
