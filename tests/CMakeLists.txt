add_test(NAME MetalPhysicsEngine.Assets
    COMMAND "${CMAKE_COMMAND}"
        "-DASSET_DIR=$<TARGET_FILE_DIR:MetalPhysicsEngine>/assets"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/check_assets.cmake")
