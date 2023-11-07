set(DOCUMENTATION "This module generates java wrappers using swig ")

message("Hello from java swig module")

set(DARWIN 0)
set(LINUX 0)
set(WINDOWS 0)
set (IOS 0)

if(ANDROID)
    message("Android is active")
endif(ANDROID)

if(${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
    set(IOS 1)
    message("iOS is active")
endif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS")

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(LINUX 1)
    message("Linux is active")
endif(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")

if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
    set(WINDOWS 1)
    message("WINDOWS is active")
endif(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")

if(ANDROID)
    message("ANDROID is active")
endif(ANDROID)

if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
    set(DARWIN 1)
    message("DARWIN is active")
endif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")

message("cmake build type is set to ${CMAKE_BUILD_TYPE}" )
message("cmake binary dir set to ${CMAKE_CURRENT_BINARY_DIR}")
message("build folder is set to $ENV{BUILD_FOLDER}")

# semantics to find our java
if(DARWIN)
    message("DARWIN is active")
    execute_process(COMMAND /usr/libexec/java_home OUTPUT_VARIABLE JAVA_HOME_DEFAULT OUTPUT_STRIP_TRAILING_WHITESPACE)

    set(JAVA_HOME ${JAVA_HOME_DEFAULT} CACHE PATH "Java home directory")
    set(JAVA_INCLUDE_PATH ${JAVA_HOME_DEFAULT}/include CACHE PATH "Java include directory")
    set(JAVA_INCLUDE_PATH2 ${JAVA_HOME_DEFAULT}/include/darwin CACHE PATH "Java include directory2")
    set(JAVA_AWT_INCLUDE_PATH ${JAVA_INCLUDE_PATH} CACHE PATH "Java awt include directory")
endif(DARWIN)


find_package(JNI REQUIRED)

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

set_property(SOURCE swig/swigjavamodule.i PROPERTY CPLUSPLUS ON)
set_property(SOURCE swig/swigjavamodule.i PROPERTY COMPILE_OPTIONS
        -package ca.mcgill.rtaudio.api -doxygen
        )

set(CMAKE_SWIG_OUTDIR ${CMAKE_CURRENT_BINARY_DIR}/java/ca/mcgill/rtaudio/api)


message("BINARY OUTPUT DIR FOR SWIG OPERATION : ${CMAKE_SWIG_OUTDIR}")
swig_add_library(rtaudiojava TYPE SHARED LANGUAGE java
        SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/swig/swigjavamodule.i"
        )

target_include_directories(rtaudiojava PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/include" ${JNI_INCLUDE_DIRS})
swig_link_libraries(rtaudiojava PUBLIC rtaudio)

add_custom_command(TARGET rtaudiojava POST_BUILD
        COMMAND mvn clean install -Dcmake.binary.build.dir=${CMAKE_CURRENT_BINARY_DIR} -Dcmake.build.type=${CMAKE_BUILD_TYPE}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Building artifacts"
        )


