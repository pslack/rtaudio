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
    // get system property for jlauncher to see if we are in a production mode
// if so, we need to load the libraries from a full path because of
// the hqrdened code in production you cannot load libraries from
// a path but required to use the full path filename


try {

String prod = System.getProperty("jlauncher.library.path");
String lib = "rtaudiojava";
String os = System.getProperty("os.name");


// if this is mac osx then it is a .dylib
// ifi this is windows then it is a .dll
// if this is linux then it is a .so

if (os.toLowerCase().contains("windows")) {
    lib = lib + ".dll";
} else if (os.toLowerCase().contains("mac")) {
    lib = "lib"+lib;
    lib = lib + ".dylib";
} else {
    lib = "lib"+lib;
    lib = lib + ".so";
}

if (prod != null) {
    String path = System.getProperty("jlauncher.library.path");

    lib = path + File.separator + lib;
    System.out.println("loading library: " + lib);
    System.load(lib);
} else {
    System.loadLibrary(lib);
}
    } catch (UnsatisfiedLinkError e) {
        System.err.println("Native code library failed to load.\n" + e);
        if (!loadLibraries() ) {
            System.err.println("Native code library failed to load.");
            System.exit(1);
        }
    }
}

private static boolean librariesLoaded = false;

private	static boolean loadLibraries() {
    if(librariesLoaded)
        return true;

    String prod = System.getProperty("jlauncher.library.path");
    String lib = "rtaudiojava";
    String os = System.getProperty("os.name");


// if this is mac osx then it is a .dylib
// ifi this is windows then it is a .dll
// if this is linux then it is a .so

    if (os.toLowerCase().contains("windows")) {
        lib = lib + ".dll";
    } else if (os.toLowerCase().contains("mac")) {
        lib = "lib"+lib;
        lib = lib + ".dylib";
    } else {
        lib = "lib"+lib;
        lib = lib + ".so";
    }





    //what is the bitness of our JVM
    final String architecture = System.getProperty("sun.arch.data.model");

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
        basePath = "/" + lib;
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

%pragma(java) modulecode=%{
    public interface RtAudioCallBackInterface {
        public int callback(byte[] outbuffer, byte[] inbuffer, int buffer_size, double stream_time, int status);
    }
    %}

%include <cpointer.i>
%pointer_functions(unsigned int, UnsignedIntPtr);


//%include <carrays.i>
//%array_functions(float, floatArray);

%include <std_string.i>
#include <string>

%include <stdint.i>
%include <typemaps.i>

%include <std_vector.i>
#include <vector>
namespace std {
        %template(vuint) vector<unsigned int>;
        %template(vstring) vector<string>;
};

%{
#include <assert.h>

// NEW: global variables (bleurgh!)
static jobject obj;
static JavaVM *jvm;
static RtAudioCallback  cb = 0;

/*
 This function returns the current thread attached to the jni
 it will return null if unsuccessful otherwise it returns the envinronment
 The caller is responsible for detaching the thread
 */
static JNIEnv * attachJNIThread()
{
    JNIEnv* env;

    if (jvm != NULL) {

        if (jvm->AttachCurrentThread((void**)&env, NULL)<0){
            return (JNIEnv *) NULL;
        } else {
            return env;
        }

    }else{

        return (JNIEnv *) NULL;

    }
}

void SetCallback(const RtAudioCallback SomeCallback) {
    //TODO: we need to handle the case where the callback is already set
    printf("Callback was set in the native code \n");

    cb = SomeCallback;
}

// 2:
static int java_callback(void *outputBuffer, void *inputBuffer,
                         unsigned int nFrames,
                         double streamTime,
                         RtAudioStreamStatus status,
                         void *userData) {

    JNIEnv *jenv = attachJNIThread();
    assert(jenv != NULL);
    const jclass cbintf = jenv->GetObjectClass(obj);    // get the class of the object
    assert(cbintf);

    const jmethodID cbmeth = jenv->GetMethodID( cbintf, "callback", "([B[BIDI)I");
    assert(cbmeth);

//    const jbyteArray jinputbuf = jenv->NewByteArray( nFrames);
//    jenv->SetByteArrayRegion( jinputbuf, 0, nFrames, (jbyte*)inputBuffer);
//
//    const jbyteArray joutputbuf = jenv->NewByteArray( nFrames);
//    jenv->SetByteArrayRegion(joutputbuf, 0, nFrames, (jbyte*)outputBuffer);

    const jint jbufsize = nFrames;
    const jdouble jstreamtime = streamTime;
    const jint jstatus = status;

    //TODO: we want to handle IO with NIO buffers
    const jint jret = jenv->CallIntMethod( obj, cbmeth,NULL, NULL, jbufsize, jstreamtime, jstatus);
//    jenv->DeleteLocalRef( jinputbuf);
//    jenv->DeleteLocalRef( joutputbuf);
    jenv->DeleteLocalRef( cbintf);

    return jret;

}

    %}

// 3:
%typemap(jstype) RtAudioCallback "RtAudioAPI.RtAudioCallBackInterface";
%typemap(jtype) RtAudioCallback "RtAudioAPI.RtAudioCallBackInterface";
%typemap(jni) RtAudioCallback "jobject";
%typemap(javain) RtAudioCallback "$javainput";

// 4: (modified, not a multiarg typemap now)
%typemap(in) RtAudioCallback {
JCALL1(GetJavaVM, jenv, &jvm);
obj = JCALL1(NewGlobalRef, jenv, $input);
JCALL1(DeleteLocalRef, jenv, $input);
$1 = java_callback;
}

//%apply unsigned int *INOUT {unsigned int *x};

%include "../RtAudio.h"
void SetCallback(const RtAudioCallback SomeCallback);
