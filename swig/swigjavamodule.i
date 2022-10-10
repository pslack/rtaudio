%module(directors="1") RtAudioAPI
%{
#include "RtAudio.h"
%}

%pragma(java) jniclassimports=%{

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;

%}

%pragma(java) jniclasscode=%{
static {
if (! loadLibraries() ) {
System.err.println("Native code library failed to load.");
System.exit(1);
}
}

private static boolean librariesLoaded = false;

private	static boolean loadLibraries() {
    if(librariesLoaded)
        return true;
    //what is the bitness of our JVM
    final String architecture = System.getProperty("sun.arch.data.model");
    final String os = System.getProperty("os.name").toLowerCase();
    String basePath="";
    final String myClassUrl = RtAudioAPIJNI.class.getResource("RtAudioAPIJNI.class").toString();
    final File myClassFile = new File(RtAudioAPIJNI.class.getResource("RtAudioAPIJNI.class").getPath());

    ///we can tell if running in development mode here
    if(myClassUrl.startsWith("file:"))
    {
        return false;
    }
    else
    {
        /// if windows we use native launcher
        if (os.indexOf("win") >= 0)
        {
            /// From the Java documentation, this should be either '32' or '64' or 'unknown'
            if( architecture == null || !( architecture.equals( "32" ) || architecture.equals( "64" ) ) )
            {
                System.err.println("Cannot determine System Architecture, cannot launch Client: "  + architecture );
                return false;
            }
            basePath = "/librtaudiojava.jnilib";
        }
        else
        {
            basePath = "/librtaudiojava.jnilib";
        }

        try {
            loadLibraryFromJar(basePath);
        } catch (FileNotFoundException e) {
            return false;
        } catch (IllegalArgumentException ie) {
            return false;
        } catch (IOException e) {
            return false;
        }
    }
    librariesLoaded=true;
    return true;
}

/**
     * Loads library from current JAR archive
     *
     * The file from JAR is copied into system temporary directory and then loaded. The temporary file is deleted after exiting.
     * Method uses String as filename because the pathname is "abstract", not system-dependent.
     *
     * @param filename The filename inside JAR as absolute path (beginning with '/'), e.g. /package/File.ext
     * @throws IOException If temporary file creation or read/write operation fails
     * @throws IllegalArgumentException If source file (param path) does not exist
     * @throws IllegalArgumentException If the path is not absolute or if the filename is shorter than three characters (restriction of {@see File#createTempFile(java.lang.String, java.lang.String)}).
     */
public static void loadLibraryFromJar(String path) throws IOException {

        if (!path.startsWith("/")) {
            throw new IllegalArgumentException("The path has to be absolute (start with '/').");
        }

        /// Obtain filename from path
        String[] parts = path.split("/");
        String filename = (parts.length > 1) ? parts[parts.length - 1] : null;

        /// Split filename to prexif and suffix (extension)
        String prefix = "";
        String suffix = null;
        if (filename != null) {
            parts = filename.split("\\.", 2);
            prefix = parts[0];
            suffix = (parts.length > 1) ? "."+parts[parts.length - 1] : null; // Thanks, davs! :-)
        }

        /// Check if the filename is okay
        if (filename == null || prefix.length() < 3) {
            throw new IllegalArgumentException("The filename has to be at least 3 characters long.");
        }

        /// Prepare temporary file
        File temp = File.createTempFile(prefix, suffix);
        temp.deleteOnExit();

        if (!temp.exists()) {
            throw new FileNotFoundException("File " + temp.getAbsolutePath() + " does not exist.");
        }

        /// Prepare buffer for data copying
        byte[] buffer = new byte[1024];
        int readBytes;

        /// Open and check input stream
        InputStream is = RtAudioAPIJNI.class.getResourceAsStream(path);
        if (is == null) {
            throw new FileNotFoundException("File " + path + " was not found inside JAR.");
        }

        /// Open output stream and copy data between source file in JAR and the temporary file
        OutputStream os = new FileOutputStream(temp);
        try {
            while ((readBytes = is.read(buffer)) != -1) {
                os.write(buffer, 0, readBytes);
            }
        } finally {
            /// If read/write fails, close streams safely before throwing an exception
            os.close();
            is.close();
        }

        /// Finally, load the library
        System.load(temp.getAbsolutePath());
}
%}

//%pragma(java) modulebase=%{
//    public class RtAudioBase {
//        public RtAudioBase() {
//            // some code goes here to define the base class
//        }
//    }
//    %}
%pragma(java) modulecode=%{
    public interface RtAudioCallBackInterface {
        public void callback(byte[] buffer, int buffer_size, double stream_time, int status);
    }
    %}

%include <cpointer.i>
%pointer_functions(RtAudioCallback, RtAudioCallbackPtr);


//%include <carrays.i>
//%array_functions(float, floatArray);

%include <std_string.i>
#include <string>



//%include <std_map.i>
//%include <std_pair.i>
//%include <std_set.i>
//%include <std_list.i>
//%include <std_shared_ptr.i>


%include <stdint.i>
//%include <arrays_java.i>
%include <typemaps.i>
//%apply unsigned int {long};
%typemap(in) unsigned int = int;
%typemap(out) unsigned int = int;

%include <std_vector.i>
#include <vector>
namespace std {
        %template(vuint) vector<unsigned int>;
        %template(vstring) vector<string>;
};

//typedef int(*RtAudioCallback)(void *outputBuffer, void *inputBuffer, unsigned int nBufferFrames, double streamTime, RtAudioStreamStatus status, void *userData);
//%feature("director") RtAudioCallbackImpl;
//%inline %{
//class RtAudioCallbackImpl  {
//    public:
//        RtAudioCallbackImpl() = default;
//        ~RtAudioCallbackImpl() = default;
//        int callback(void *outputBuffer, void *inputBuffer, unsigned int nBufferFrames, double streamTime, RtAudioStreamStatus status, void *userData);
//};
//
//int    RtAudioCallbackImpl::callback(void *outputBuffer, void *inputBuffer, unsigned int nBufferFrames, double streamTime, RtAudioStreamStatus status, void *userData)
//    {
//        return 0;
//    }
//
//
//%}
//
//

%include "../RtAudio.h"


