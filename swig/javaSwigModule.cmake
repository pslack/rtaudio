set(DOCUMENTATION "This module generates java wrappers using swig ")

message("Hello from java swig module")


# semantics to find our java
if(APPLE)
    message("DARWIN is active")
    execute_process(COMMAND /usr/libexec/java_home OUTPUT_VARIABLE JAVA_HOME_DEFAULT OUTPUT_STRIP_TRAILING_WHITESPACE)

    set(JAVA_HOME ${JAVA_HOME_DEFAULT} CACHE PATH "Java home directory")
    set(JAVA_INCLUDE_PATH ${JAVA_HOME_DEFAULT}/include CACHE PATH "Java include directory")
    set(JAVA_INCLUDE_PATH2 ${JAVA_HOME_DEFAULT}/include/darwin CACHE PATH "Java include directory2")
    set(JAVA_AWT_INCLUDE_PATH ${JAVA_INCLUDE_PATH} CACHE PATH "Java awt include directory")
endif(APPLE)

# If JNI paths are already defined (e.g. from parent CMake or toolchain hints), use them
if(JAVA_INCLUDE_PATH AND JAVA_INCLUDE_PATH2)
    set(JNI_INCLUDE_DIRS ${JAVA_INCLUDE_PATH} ${JAVA_INCLUDE_PATH2})
    set(JNI_LIBRARIES ${JAVA_JVM_LIBRARY})
    set(JNI_FOUND TRUE)
    message(STATUS "Using pre-configured JNI paths for cross-compilation: ${JNI_INCLUDE_DIRS}")
else()
    find_package(JNI REQUIRED COMPONENTS JVM)
endif()


if (JNI_FOUND)
    message (STATUS "JNI_INCLUDE_DIRS=${JNI_INCLUDE_DIRS}")
    message (STATUS "JNI_LIBRARIES=${JNI_LIBRARIES}")
else()
    message (FATAL_ERROR "Could not find JNI, fatal.")

endif()


cmake_policy(SET CMP0078 NEW)
cmake_policy(SET CMP0086 NEW)
find_package(SWIG REQUIRED)
include(${SWIG_USE_FILE})

if(SWIG_FOUND)
    message("SWIG found: ${SWIG_EXECUTABLE}")
    message("SWIG dir  : ${SWIG_DIR}")
    message("SWIG ver  : ${SWIG_VERSION}")

endif()

find_program(Maven_EXECUTABLE REQUIRED NAMES mvn)
if(NOT Maven_EXECUTABLE)
    message(FATAL_ERROR "Could not find 'mvn' executable...")
endif()


set_property(SOURCE swig/swigjavamodule.i PROPERTY CPLUSPLUS ON)
set_property(SOURCE swig/swigjavamodule.i PROPERTY COMPILE_OPTIONS
        -package ca.mcgill.rtaudio.api -doxygen
        )

set(CMAKE_SWIG_OUTDIR ${CMAKE_CURRENT_BINARY_DIR}/java/ca/mcgill/rtaudio/api)


message("BINARY OUTPUT DIR FOR SWIG OPERATION : ${CMAKE_SWIG_OUTDIR}")
swig_add_library(rtaudiojava TYPE SHARED LANGUAGE java
        SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/swig/swigjavamodule.i"
        )

target_include_directories(rtaudiojava PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}/swig"
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        ${JNI_INCLUDE_DIRS}
        )
swig_link_libraries(rtaudiojava PUBLIC rtaudio)

#add_executable(local_libs_test swig/LocalizeJNILib.cpp)
#add_dependencies(rtaudiojava local_libs_test)

#figure out where our final binaries are and set that for maven build
# if compiler is xcode or visual studio, set the output folder
#if(CMAKE_GENERATOR STREQUAL "Xcode" OR CMAKE_GENERATOR STREQUAL "Visual Studio")
#    set(RT_BT ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_BUILD_TYPE} )
#else()
#    set(RT_BT ${CMAKE_CURRENT_BINARY_DIR})
#endif()
#if the build type is Debug then we add -SNAPSHOT suffix
if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(JAVA_PROJECT_VERSION "${PROJECT_VERSION}-SNAPSHOT")
else()
    set(JAVA_PROJECT_VERSION "${PROJECT_VERSION}")
endif()
message("Java project version: ${JAVA_PROJECT_VERSION}")
set(JAVA_ARTIFACT_DIR "${CMAKE_BINARY_DIR}/java_artifacts")
set(JAVA_CORE_JAR_DEST "${JAVA_ARTIFACT_DIR}/rtaudio-core.jar")
set(JAVA_CORE_JAR_SOURCE "${PROJECT_SOURCE_DIR}/swig/ca.mcgill.rtaudio.rtaudio-core/target/rtaudio-core-${JAVA_PROJECT_VERSION}.jar")

add_custom_command(
        OUTPUT  ${JAVA_CORE_JAR_DEST}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} -E env
        MAVENBUILD=TRUE
        ${Maven_EXECUTABLE} versions:set "-DnewVersion=${JAVA_PROJECT_VERSION}" -DgenerateBackupPoms=false
        COMMAND ${CMAKE_COMMAND} -E echo "--- [DEBUG] Starting Java Packaging..."
        COMMAND ${CMAKE_COMMAND} -E env
        MAVENBUILD=TRUE
        ${Maven_EXECUTABLE} -f "${PROJECT_SOURCE_DIR}/pom.xml" clean install
        -Drtaudio.native.library.path=$<TARGET_FILE_DIR:rtaudio>
        -Dcmake.binary.build.dir=${CMAKE_CURRENT_BINARY_DIR}
        -Dgnarly.keystore.path=$ENV{GNARLY_KEYSTORE_PATH}
        -Dkeystore.type=$ENV{KEYSTORE_TYPE}
        -Dgnarly.keystore.alias=$ENV{GNARLY_KEYSTORE_ALIAS}
        -Dgnarly.keystore.password=$ENV{GNARLY_KEYSTORE_PASSWORD}
        -Dgnarly.tsa=$ENV{GNARLY_TSA}
        COMMAND ${CMAKE_COMMAND} -E echo "--- [DEBUG] Maven finished. Verifying source JAR..."
        COMMAND ${CMAKE_COMMAND} -E echo "--- [DEBUG] Preparing to copy..."
        COMMAND ${CMAKE_COMMAND} -E make_directory "${JAVA_ARTIFACT_DIR}"
        COMMAND ${CMAKE_COMMAND} -E copy "${JAVA_CORE_JAR_SOURCE}" "${JAVA_CORE_JAR_DEST}"
        COMMAND ${CMAKE_COMMAND} -E echo "--- [DEBUG]  finished. ..."


        DEPENDS rtaudiojava
        COMMENT "Packaging Java artifacts with Maven and collecting results..."
        # VERBATIM is important to make sure CMake passes the && characters correctly.
        VERBATIM
)
add_custom_target(java_package_rtaudio DEPENDS ${JAVA_CORE_JAR_DEST} )

#add_custom_command(TARGET rtaudiojava POST_BUILD
#        COMMAND mvn clean install -Dcmake.binary.build.dir=${CMAKE_CURRENT_BINARY_DIR} -Dcmake.build.type=${CMAKE_BUILD_TYPE} -Dcmake.translate=${RT_BT}
#        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#        COMMENT "Building artifacts"
#)


