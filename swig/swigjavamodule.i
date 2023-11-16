%module(directors="1") RtAudioAPI
%{
#include "RtAudio.h"
#include <string>
#include <vector>
#include <map>
#include <assert.h>
#include <memory>
#include "swigstructs.h"

class RtAudioCallbackWrapper;

// NEW: global variables (bleurgh!)
static jobject obj;
static JavaVM *jvm;
static RtAudioCallback  cb = 0;
std::map<int,std::shared_ptr<RtAudioCallbackWrapper>> callbacks = {};
std::map<int,std::function<int( void *outputBuffer, void *inputBuffer,
                               unsigned int nFrames,
                               double streamTime,
                               RtAudioStreamStatus status,
                               void *userData )>> functors;

std::vector<std::shared_ptr<CallbackUserDataStruct>> callbackUserDataStructs;



void* getCallbackUserDataStruct(int index, int nInputChannels, int nOutputChannels, long format, bool interleaved) {

    // let's manage the memory for this new pointer keep it alive until the end of the program
    std::shared_ptr<CallbackUserDataStruct> cbDataptr = std::make_shared<CallbackUserDataStruct>();
    callbackUserDataStructs.push_back(cbDataptr);

    CallbackUserDataStruct * cbData = cbDataptr.get();

    cbData->index = index;
    cbData->nInputChannels = nInputChannels;
    cbData->nOutputChannels = nOutputChannels;
    cbData->format = format;
    cbData->interleaved = interleaved;


    return cbData;
}

void* convertSwigCptr(long long cptr)
{
    return (void *) cptr;

}



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

// we will use user data to index into an array of function pointers to class instances
// create a user dat astruct that has the index into the array of function pointers, the number of input and output channels, the format size and boolean if interleaved


class RtAudioCallbackWrapper{
        public:
        RtAudioCallbackWrapper(jobject javaCallback) {
            JNIEnv *jenv = attachJNIThread();
            assert(jenv != NULL);

            javaCallbackObject = javaCallback;
            std::cout << "RtAudioCallbackWrapper constructor called" << std::endl;

            const jclass cbintf = jenv->GetObjectClass(javaCallback);
            assert(cbintf != NULL);

            jmethodID method = jenv->GetMethodID(cbintf, "getUserData",
                                                 "()Lca/mcgill/rtaudio/api/RtAudioAPI$CallbackUserData;");

            assert(method != NULL);

// get the callbackInfo object
            jobject callbackInfo = jenv->CallObjectMethod(javaCallback, method);
            assert(callbackInfo != NULL);

            jclass callbackInfoClass = jenv->GetObjectClass(callbackInfo);
            assert(callbackInfoClass != NULL);


//get all the fields from the callbackInfo object described above

            jfieldID indexf = jenv->GetFieldID(callbackInfoClass, "index", "I");
            jint index = jenv->GetIntField(callbackInfo, indexf);

            jfieldID nInputChannelsf = jenv->GetFieldID(callbackInfoClass, "nInputChannels", "I");
            jint nInputChannels = jenv->GetIntField(callbackInfo, nInputChannelsf);

            jfieldID nOutputChannelsf = jenv->GetFieldID(callbackInfoClass, "nOutputChannels", "I");
            jint nOutputChannels = jenv->GetIntField(callbackInfo, nOutputChannelsf);


            jfieldID formatf = jenv->GetFieldID(callbackInfoClass, "format", "I");
            jint format = jenv->GetIntField(callbackInfo, formatf);

            jfieldID interleavedf = jenv->GetFieldID(callbackInfoClass, "interleaved", "Z");
            jboolean interleaved = jenv->GetBooleanField(callbackInfo, interleavedf);




            this->index = index;
            this->nInputChannels = nInputChannels;
            this->nOutputChannels = nOutputChannels;
            this->format = format;
            this->interleaved = interleaved;


            if (format == RTAUDIO_SINT8) {
                formatSize = 1;
            }
            if (format == RTAUDIO_SINT16) {
                formatSize = 2;
            }
            if (format == RTAUDIO_SINT24) {
                formatSize = 3;
            }
            if (format == RTAUDIO_SINT32) {
                formatSize = 4;
            }
            if (format == RTAUDIO_FLOAT32) {
                formatSize = 4;
            }
            if (format == RTAUDIO_FLOAT64) {
                formatSize = 8;
            }

            cbmeth = jenv->GetMethodID(cbintf, "callback", "(Ljava/nio/ByteBuffer;Ljava/nio/ByteBuffer;IDIJJ)I");
            assert(cbmeth);

            jenv->DeleteLocalRef(cbintf);

        }

        ~RtAudioCallbackWrapper() {
            std::cout << "RtAudioCallbackWrapper destructor called" << std::endl;


        }

        // standard copy constructor
        RtAudioCallbackWrapper(const RtAudioCallbackWrapper& other) {
            std::cout << "RtAudioCallbackWrapper copy constructor called" << std::endl;
            javaCallbackObject = other.javaCallbackObject;
        }

        int javaCallback(void *outputBuffer, void *inputBuffer, unsigned int nFrames, double streamTime,
        RtAudioStreamStatus status, void *userData) {

            JNIEnv *jenv = attachJNIThread();
            assert(jenv != NULL);
            const jint jbufsize = nFrames;
            const jdouble jstreamtime = streamTime;
            const jint jstatus = status;
            jint jret;


            jobject inbuf = NULL;
            jobject outbuf = NULL;
            const jlong joutputBuffer = (jlong) outputBuffer;
            const jlong jinputBuffer = (jlong) inputBuffer;

            // todo make sizes of bytebuffer match the format and channels etc
            if (outputBuffer != NULL) {
                outbuf = jenv->NewDirectByteBuffer(outputBuffer, nFrames * formatSize * nOutputChannels);
            }
            if (inputBuffer != NULL) {
                inbuf = jenv->NewDirectByteBuffer(inputBuffer, nFrames * formatSize * nInputChannels);
            }
            jret = jenv->CallIntMethod(javaCallbackObject, cbmeth, outbuf, inbuf, jbufsize, jstreamtime,
                                       jstatus,joutputBuffer,jinputBuffer);
            if (inbuf != NULL) {
                jenv->DeleteLocalRef(inbuf);
            }
            if (outbuf != NULL) {
                jenv->DeleteLocalRef(outbuf);
            }

            return jret;
        }

        private:
        // the size related to the format requested
        int formatSize;
        int nInputChannels;
        int nOutputChannels;
        int format;
        int index;
        bool interleaved;
        jmethodID cbmeth;

        jobject javaCallbackObject;
        bool useByteBuffer;
};


void SetCallback(const RtAudioCallback SomeCallback) {
    //TODO: we need to handle the case where the callback is already set
    printf("Callback was set in the native code \n");

    cb = SomeCallback;
}

// this is the function that all streams use as callback address
// the userdata sets the index into the array of function pointers

static int java_callback(void *outputBuffer, void *inputBuffer,
                         unsigned int nFrames,
                         double streamTime,
                         RtAudioStreamStatus status,
                         void *userData) {

   // first cast user data to a callbackUserData struct
    CallbackUserDataStruct* cbData = (CallbackUserDataStruct*)userData;
    // check tht the struct is actually valid
    if(cbData == NULL) {
        // return a stream error abort the stream immediately
        return 2;
    }
    // get the index into the array of function pointers
    int index = cbData->index;
    // get the function pointer from the array
    std::function<int( void *outputBuffer, void *inputBuffer,
                       unsigned int nFrames,
                       double streamTime,
                       RtAudioStreamStatus status,
                       void *userData )> func = functors[index];
    // che3ck that the function pointer is valid
   if(func != NULL){
       // call the function pointer
       return func(outputBuffer, inputBuffer, nFrames, streamTime, status, userData);
   } else {
       // return a stream error abort the stream immediately

       return 2;
   }

}

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
import java.nio.ByteBuffer;


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

if (prod != null) {
    String path = System.getProperty("jlauncher.library.path");

// if this is mac osx then it is a .dylib
// ifi this is windows then it is a .dll
// if this is linux then it is a .so

if (os.toLowerCase().contains("windows")) {
lib = lib + ".dll";
} else if (os.toLowerCase().contains("mac")) {
    lib = "lib"+lib;
    lib = lib + ".jnilib";
} else {
    lib = "lib"+lib;
    lib = lib + ".so";
}
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
        lib = lib + ".jnilib";
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

   public static class CallbackUserData {
    public CallbackUserData() {
    }
    public int index;
    public int nInputChannels;
    public int nOutputChannels;
    public int format;
    public boolean interleaved;


   }

    public interface RtAudioCallBackInterface {
        public int callback(java.nio.ByteBuffer outbuffer, java.nio.ByteBuffer inbuffer, int buffer_size, double stream_time, int status,long outbufferptr, long inbufferptr);
        // user to provide callback data structure in order to provide information for bytebuffering
        public CallbackUserData getUserData();
    }

    %}

%include <cpointer.i>

%include <std_string.i>
%include <stdint.i>
%include <typemaps.i>
%include <std_vector.i>

namespace std {
        %template(vuint) vector<unsigned int>;
        %template(vstring) vector<string>;
};

%pointer_functions(unsigned int, UnsignedIntPtr);


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

// extract the callbackInfo from the obj provided
// obj is RtAudioAPI.RtAudioCallBackInterface
// we need to get the callbackInfo from the object
// get the method getCallbackInfo
// get the class of the object
const jclass cbintf = jenv->GetObjectClass(obj);
assert(cbintf != NULL);

jmethodID method = JCALL3(GetMethodID, jenv, cbintf, "getUserData", "()Lca/mcgill/rtaudio/api/RtAudioAPI$CallbackUserData;");
assert(method != NULL);

// get the callbackInfo object
jobject callbackInfo = JCALL2(CallObjectMethod, jenv, obj, method);
assert (callbackInfo != NULL);

jclass callbackInfoClass = jenv->GetObjectClass(callbackInfo);
assert(callbackInfoClass != NULL);

//public int index;
//public int nInputChannels;
//public int nOutputChannels;
//public int format;
//public boolean interleaved;

//get all the fields from the callbackInfo object described above

jfieldID indexf = JCALL3(GetFieldID, jenv, callbackInfoClass, "index", "I");
jint index = JCALL2(GetIntField, jenv, callbackInfo, indexf);


// create a new wrapper object and add it to vector of std pointers
std::shared_ptr< RtAudioCallbackWrapper > wrapper(new RtAudioCallbackWrapper(obj));
callbacks[index]=wrapper;


functors[index] = ([index](void *outputBuffer, void *inputBuffer,
                                   unsigned int nFrames,
                                   double streamTime,
                                   RtAudioStreamStatus status,
                                   void *userData) {
    return (callbacks[index].get()->javaCallback(outputBuffer, inputBuffer, nFrames, streamTime, status, userData));
});

//$1 = std::bind(test, wrapper, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, std::placeholders::_4, std::placeholders::_5, std::placeholders::_6);
//}
$1 = java_callback;
//$1=*functors.back().target<RtAudioCallback>();

}

%include "../RtAudio.h"
%include "swigstructs.h"



