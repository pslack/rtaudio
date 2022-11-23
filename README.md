# RtAudio

![Build Status](https://github.com/thestk/rtaudio/actions/workflows/ci.yml/badge.svg)

A set of C++ classes that provide a common API for realtime audio input/output across Linux (native ALSA, JACK, PulseAudio and OSS), Macintosh OS X (CoreAudio and JACK), and Windows (DirectSound, ASIO and WASAPI) operating systems.

By Gary P. Scavone, 2001-2022 (and many other developers!)

This distribution of RtAudio contains the following:

- doc:      RtAudio documentation (see doc/html/index.html)
- tests:    example RtAudio programs
- include:  header and source files necessary for ASIO, DS & OSS compilation
- tests/Windows: Visual C++ .net test program workspace and projects

## Overview

RtAudio is a set of C++ classes that provides a common API (Application Programming Interface) for realtime audio input/output across Linux (native ALSA, JACK, PulseAudio and OSS), Macintosh OS X and Windows (DirectSound, ASIO and WASAPI) operating systems.  RtAudio significantly simplifies the process of interacting with computer audio hardware.  It was designed with the following objectives:

  - object-oriented C++ design
  - simple, common API across all supported platforms
  - only one source and one header file for easy inclusion in programming projects
  - allow simultaneous multi-api support
  - support dynamic connection of devices
  - provide extensive audio device parameter control
  - allow audio device capability probing
  - automatic internal conversion for data format, channel number compensation, (de)interleaving, and byte-swapping

RtAudio incorporates the concept of audio streams, which represent audio output (playback) and/or input (recording).  Available audio devices and their capabilities can be enumerated and then specified when opening a stream.  Where applicable, multiple API support can be compiled and a particular API specified when creating an RtAudio instance.  See the \ref apinotes section for information specific to each of the supported audio APIs.

## Building

Several build systems are available.  These are:

  - autotools (`./autogen.sh; make` from git, or `./configure; make` from tarball release)
  - CMake (`mkdir build; cd build; ../cmake; make`)
  - meson (`meson build; cd build; ninja`)

See `install.txt` for more instructions about how to select the audio backend API.  By
default all detected APIs will be enabled.

We recommend using the autotools-based build for packaging purposes.  Please note that
RtAudio is designed as a single `.cpp` and `.h` file so that it is easy to copy directly
into a project.  In that case you need to define the appropriate flags for the desired
backend APIs.

## Building Java Bindings

Currently only OSX is supported / tested. and this is only available in CMAKE builds

### Prerequisites for build machine
    
      - JDK 11 or later
      - CMake 3.1 or later
      - SWIG 4.0.2 or later and swig available on the environment PATH  
      - maven 3.6.3 or later and on the environment PATH
      - rtAudio installed locally 
        to run tests or use this library in your projects       
        
### Build instructions

1. set cmake option BUILD_JAVA_BINDINGS to ON

This can be done by adding 
> -DBUILD_JAVA_BINDINGS=ON

to the cmake command line. 
Building target 'rtaudiojava' generates the JNI library and generates 
the java wrapper source code in your cmake build directory in a folder named java.
    


This will create a 'target' folder in the cmake project directory. The target folder contains the java wrapper jar file bundled with the JNI native library. The jar file can be used in your java project. 

The maven product is also published to the local maven repository (usually .m2 folder on one's user home directory)

To use this local repository in your maven java project, add the following dependency to your pom.xml file

```xml
<dependency>
   <groupId>ca.mcgill.rtaudio</groupId>
   <artifactId>rtaudio-core</artifactId>
   <version>1.0-SNAPSHOT</version>
   <scope>compile</scope>            
   <type>jar</type>
</dependency>  
```
There are also binary artifacts that are published

For windows

```xml
<dependency>
   <groupId>ca.mcgill.rtaudio</groupId>
   <artifactId>rtaudio-core-native-windows-X86_64</artifactId>
   <version>1.0-SNAPSHOT</version>
   <scope>compile</scope>            
   <type>jar</type>
</dependency>  
```

for OSX

```xml
<dependency>
   <groupId>ca.mcgill.rtaudio</groupId>
   <artifactId>rtaudio-core-native-mac-X86_64</artifactId>
   <version>1.0-SNAPSHOT</version>
   <scope>compile</scope>            
   <type>jar</type>
</dependency>  
```
The binaries are archived inside the jar file and are provided seperately

for hardened exec environments the full path to the library would be required
For systems more permissive the library inside the bundle and expanded at run time
can work.



There is an example maven project that tests the RtAudio java wrapper project in  

> swig/example/RtAudioJavaApp



##FAQ

### Why does audio only come to one ear when I choose 1-channel output?

RtAudio doesn't automatically turn 1-channel output into stereo output with copied values to two channels, since there may be cases when a user truly wants 1-channel behaviour.  If you want monophonic data to be projected to stereo output, open a 2-channel stream and copy the data to both channels in your audio stream callback.

## Further Reading

For complete documentation on RtAudio, see the doc directory of the distribution or surf to http://www.music.mcgill.ca/~gary/rtaudio/.


## Legal and ethical:

The RtAudio license is similar to the MIT License.  Please see [LICENSE](LICENSE).
