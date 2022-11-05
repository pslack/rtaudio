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

# semantics to find our java

include(FindJNI)
if (DARWIN)
    if (NOT JNI_FOUND)
        message (STATUS "Could not find JNI, retrying for JDK.")
        execute_process(COMMAND /usr/libexec/java_home OUTPUT_VARIABLE JAVA_HOME OUTPUT_STRIP_TRAILING_WHITESPACE)
        message (STATUS "my JAVA_HOME=${JAVA_HOME}")
        if (NOT JAVA_HOME)
            message (FATAL_ERROR "Could not find JDK Java home, fatal.")
            return()
        endif ()

        set(JAVA_JNI_INCLUDE ${JAVA_HOME}/include)
        if (APPLE)
            set(JAVA_JNI_INCLUDE ${JAVA_JNI_INCLUDE} ${JAVA_JNI_INCLUDE}/darwin )
        endif()
        message (STATUS "my JAVA_JNI_INCLUDE=${JAVA_JNI_INCLUDE}")

        #message(STATUS "here ${JAVA_HOME}/jre/lib/jli")
        find_library(JAVA_JNI_LIB NAMES jli HINTS "${JAVA_HOME}/lib/jli" "${JAVA_HOME}/jre/lib/jli")
        #message (STATUS "my JAVA_JNI_LIB=${JAVA_JNI_LIB}")

        if (NOT JAVA_JNI_INCLUDE OR NOT JAVA_JNI_LIB)
            message (FATAL_ERROR "Could not find JDK Java JNI, fatal.")
            return()
        else ()
            message (STATUS "JDK resolved.")
            include_directories(${JAVA_JNI_INCLUDE})
        endif ()
    else()
        message (STATUS "JNI_INCLUDE_DIRS=${JNI_INCLUDE_DIRS}")
        set(JAVA_JNI_INCLUDE ${JNI_INCLUDE_DIRS})
        message (STATUS "JNI_LIBRARIES=${JNI_LIBRARIES}")
        set(JAVA_JNI_LIB ${JNI_LIBRARIES})
    endif()
else ()
    if(NOT ANDROID)
        #include(FindJNI)

        include(UseJava)
        if(DEFINED ENV{JAVA_HOME})
            set(JAVA_HOME "$ENV{JAVA_HOME}")
        else()
            set(JAVA_HOME /opt/jdk/jdk8)
        endif()
        message(STATUS "JAVA_HOME  variable is defined or set as '${JAVA_HOME}'")

        # set(JAVA_AWT_LIBRARY "${JAVA_HOME}/lib/amd64") #the path to the Java AWT Native Interface (JAWT) library
        # set(JAVA_JVM_LIBRARY "${JAVA_HOME}/lib/amd64/server") #the path to the Java Virtual Machine (JVM) library
        # set(JAVA_INCLUDE_PATH "${JAVA_HOME}/include")  #the include path to jni.h
        # set(JAVA_INCLUDE_PATH2 "${JAVA_HOME}/include/linux") # the include path to jni_md.h and jniport.h
        # set(JAVA_AWT_INCLUDE_PATH "${JAVA_HOME}/include")    # the include path to jawt.h
        #   set(CMAKE_FIND_ROOT_PATH "${JAVA_HOME}")
        #   set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH "${JAVA_HOME}")

        set(CMAKE_FIND_DEBUG_MODE TRUE)
        find_package(JNI ) #TODO@ add REQUIRED, But cant use PATHS ${JAVA_HOME} as it triggers FindProjname.cmake mode
        set(CMAKE_FIND_DEBUG_MODE FALSE)

        if(JNI_FOUND)
            message (STATUS " JNI_INCLUDE_DIRS=${JNI_INCLUDE_DIRS}")
            message (STATUS " JNI_LIBRARIES=${JNI_LIBRARIES}")
        else()
            message (STATUS " JNI is NOT FOUND")
        endif()

        if (NOT JNI_FOUND)
            message (FATAL_ERROR "No JNI found, cannot build")
        else()
            # message (STATUS "JNI_INCLUDE_DIRS=${JNI_INCLUDE_DIRS}")
            set(JAVA_JNI_INCLUDE ${JNI_INCLUDE_DIRS})
            # message (STATUS "JNI_LIBRARIES=${JNI_LIBRARIES}")
            set(JAVA_JNI_LIB ${JNI_LIBRARIES})
        endif()
    endif(NOT ANDROID)
endif ()


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

target_include_directories(rtaudiojava PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/include")
swig_link_libraries(rtaudiojava PUBLIC rtaudio)

add_custom_command(TARGET rtaudiojava POST_BUILD
        COMMAND mvn clean install -Dcmake.binary.build.dir=${CMAKE_CURRENT_BINARY_DIR}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Building artifacts"
        )


