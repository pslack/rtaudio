%module(directors="1") RtAudioAPI

%include <cpointer.i>
%include <std_string.i>
%include <stdint.i>
%include <typemaps.i>
%include <std_vector.i>



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
// Global mutex for protecting callbacks and functors
std::mutex callbackMutex;



static JavaVM *jvm;


// Map to store Java object references and their corresponding wrappers, keyed by index
std::map<int, std::pair<jobject, std::shared_ptr<RtAudioCallbackWrapper>>> callbackWrappers = {};

std::map<int,std::function<int( void *outputBuffer, void *inputBuffer,
                               unsigned int nFrames,
                               double streamTime,
                               RtAudioStreamStatus status,
                               void *userData )>> functors;

std::map<int,std::shared_ptr<CallbackUserDataStruct>> callbackUserDataStructs = {};

std::mutex globalRefMutex; // For thread safety
std::map<jobject, jobject> globalRefs = {}; // Use a map to store the global refs

void *getCallbackUserDataStruct(int index) {
    // see if the index is in the map
    if(callbackUserDataStructs.find(index) == callbackUserDataStructs.end()) {
        // create a new CallbackUserDataStruct at the index
        callbackUserDataStructs[index] = std::make_shared<CallbackUserDataStruct>();
        callbackUserDataStructs[index]->index = index;
    }
    // reinterpret cast to void *
    return reinterpret_cast<void *>(callbackUserDataStructs[index].get());

}

void* convertSwigCptr(long long cptr)
{
    return (void *) cptr;
}


// Function to set the JVM (called during library load)
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    jvm = vm;
    std::cout << "JNI_OnLoad called" << std::endl;
    return JNI_VERSION_1_8;
}

void checkAndClearException(JNIEnv *env) {
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
    }
}


static JNIEnv* getJNIEnv() {
    JNIEnv* env;
    if(jvm == nullptr) {
        std::cerr << "JVM is null" << std::endl;
        return nullptr;
    }
    if (jvm->GetEnv((void**)&env, JNI_VERSION_1_8) == JNI_OK) {
        return env; // Already attached
    } else {
        if (jvm->AttachCurrentThread((void**)&env, NULL) < 0) {
            std::cerr << "Failed to attach thread to JVM" << std::endl;
            return nullptr;
        } else {
            return env;
        }
    }
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

            formatSize = 0;
            nInputChannels = 0;
            nOutputChannels = 0;
            format = 0;
            index = 0;
            interleaved = true;
            cbmeth = NULL;
            outputBufferSize = 0;
            inputBufferSize = 0;

            bufferSize = 0;
            myInputBuffer = nullptr;
            myOutputBuffer = nullptr;

            inbuf = NULL;  // Now a member variable
            outbuf = NULL; // Now a member variable
            byteOrder = NULL;
            javaCallbackObject = NULL;



            JNIEnv *jenv = getJNIEnv();
            if(jenv == nullptr) {
                std::cout<<"Could not get JNIEnv"<<std::endl;

            } else {
                std::cout<<"Got JNIEnv"<<std::endl;
            }
            assert(jenv != NULL);

            javaCallbackObject = javaCallback;
            std::cout << "RtAudioCallbackWrapper constructor called" << std::endl;

            const jclass cbintf = jenv->GetObjectClass(javaCallback);
            if(cbintf == NULL) {
                std::cout << "Could not get callback interface" << std::endl;

            } else {
                std::cout << "Got callback interface" << std::endl;
            }

            checkAndClearException(jenv);

            jclass interfaceCls = jenv->FindClass("ca/mcgill/rtaudio/api/RtAudioAPI$RtAudioCallBackInterface");
            jmethodID method = jenv->GetMethodID(interfaceCls, "getUserData", "()Lca/mcgill/rtaudio/api/RtAudioAPI$CallbackUserData;");


            if(! method) {
                std::cout << "Could not get methodID" << std::endl;
                assert(method != NULL);

            } else {
                std::cout << "getMethodID getuserData called" << std::endl;
            }

            checkAndClearException(jenv);

// get the callbackInfo object
            jobject callbackInfo = jenv->CallObjectMethod(javaCallback, method);
            if (!callbackInfo) {
                std::cout << "Could not get callbackInfo object" << std::endl;

            } else {
                std::cout << "Got callbackInfo object" << std::endl;
            }

            checkAndClearException(jenv);


            jclass callbackInfoClass = jenv->GetObjectClass(callbackInfo);
            if (!callbackInfoClass) {
                std::cout << "Could not get callbackInfo class" << std::endl;

            } else {
                std::cout << "Got callbackInfo class" << std::endl;
            }
            checkAndClearException(jenv);


//get all the fields from the callbackInfo object described above

            jmethodID indexf = jenv->GetMethodID(callbackInfoClass, "getIndex", "()I");
            if(!indexf) {
                std::cout << "Could not get index field" << std::endl;

            } else {
                std::cout << "Got index field ";
            }
            jint index = jenv->CallIntMethod(callbackInfo, indexf);
            std::cout << "Index value: " << index << std::endl;
            checkAndClearException(jenv);

            jmethodID nInputChannelsf = jenv->GetMethodID(callbackInfoClass, "getNInputChannels", "()I");
            if(!nInputChannelsf) {
                std::cout << "Could not get nInputChannels field" << std::endl;

            } else {
                std::cout << "Got nInputChannels field " ;
            }
            jint nInputChannels = jenv->CallIntMethod(callbackInfo, nInputChannelsf);
            std::cout << "nInputChannels value: " << nInputChannels << std::endl;

            checkAndClearException(jenv);
            jmethodID nOutputChannelsf = jenv->GetMethodID(callbackInfoClass, "getNOutputChannels", "()I");
            if(!nOutputChannelsf) {
                std::cout << "Could not get nOutputChannels field" << std::endl;

            } else {
                std::cout << "Got nOutputChannels field ";
            }
            jint nOutputChannels = jenv->CallIntMethod(callbackInfo, nOutputChannelsf);
            std::cout << "nOutputChannels value: " << nOutputChannels << std::endl;
            checkAndClearException(jenv);

            jmethodID formatf = jenv->GetMethodID(callbackInfoClass, "getFormat", "()I");
            if(!formatf) {
                std::cout << "Could not get format field" << std::endl;

            } else {
                std::cout << "Got format field ";
            }

            jint format = jenv->CallIntMethod(callbackInfo, formatf);
            std::cout << "format value: " << format << std::endl;

            checkAndClearException(jenv);

            jmethodID interleavedf = jenv->GetMethodID(callbackInfoClass, "getInterleaved", "()Z");
            if(!interleavedf) {
                std::cout << "Could not get interleaved field" << std::endl;

            } else {
                std::cout << "Got interleaved field " ;
            }
            jboolean interleaved = jenv->CallBooleanMethod(callbackInfo, interleavedf);
            std::cout << "interleaved value: " << interleaved << std::endl;
            checkAndClearException(jenv);

            jmethodID bufferSizef = jenv->GetMethodID(callbackInfoClass, "getBufferSize", "()I");
            if(!bufferSizef) {
                std::cout << "Could not get bufferSize field" << std::endl;

            } else {
                std::cout << "Got bufferSize field ";
            }
            jint buffSize = jenv->CallIntMethod(callbackInfo, bufferSizef);
            std::cout << "bufferSize value: " << buffSize << std::endl;
            checkAndClearException(jenv);

            this->bufferSize = buffSize;

            jclass byteOrderClass = jenv->FindClass("java/nio/ByteOrder");
            if(byteOrderClass == NULL) {
                std::cout << "Could not get ByteOrder class" << std::endl;

            } else {
                std::cout << "Got ByteOrder class" << std::endl;
            }
            jmethodID nativeOrderMethod = jenv->GetStaticMethodID(byteOrderClass, "nativeOrder", "()Ljava/nio/ByteOrder;");
            if(!nativeOrderMethod) {
                std::cout << "Could not get nativeOrder method" << std::endl;

            } else {
                std::cout << "Got nativeOrder method" << std::endl;
            }
            byteOrder = jenv->CallStaticObjectMethod(byteOrderClass, nativeOrderMethod);
            checkAndClearException(jenv);

            this->index = index;
            this->nInputChannels = nInputChannels;
            this->nOutputChannels = nOutputChannels;
            this->format = format;
            this->interleaved = interleaved;
            this->bufferSize = buffSize;

            if ( bufferSize == 0 && (nInputChannels > 0 || nOutputChannels > 0)) {
                std::cout << "bufferSize is 0, setting to 512" << std::endl;
                bufferSize = 256;
            }

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

            myOutputBuffer = NULL;
            myInputBuffer = NULL;

            outputBufferSize = buffSize * formatSize * nOutputChannels;
            std::cout << "outputBufferSize: " << outputBufferSize << std::endl;
            inputBufferSize = buffSize * formatSize * nInputChannels;
            std::cout << "inputBufferSize: " << inputBufferSize << std::endl;

            if (outputBufferSize > 0) {
                myOutputBuffer = std::malloc(outputBufferSize);
                if(myOutputBuffer == NULL) {
                    std::cout << "Could not create output buffer" << std::endl;
                } else {
                    std::cout << "Created native output buffer" << std::endl;
                }

                jobject noutbuf = jenv->NewDirectByteBuffer(myOutputBuffer, outputBufferSize);
                checkAndClearException(jenv);
                if(noutbuf == NULL) {
                    std::cout << "Could not create output buffer" << std::endl;

                } else {
                    std::cout << "Created bytebuffer output buffer" << std::endl;
                };

                jenv->CallObjectMethod(noutbuf, jenv->GetMethodID(jenv->GetObjectClass(noutbuf), "order", "(Ljava/nio/ByteOrder;)Ljava/nio/ByteBuffer;"), byteOrder);
                checkAndClearException(jenv);

                std::cout<<"Called order on output buffer"<<std::endl;
                // make outbuf a global reference so it stays alive past this scope
                outbuf = jenv->NewGlobalRef(noutbuf);
                if (outbuf == NULL) {
                    std::cout << "Could not create output buffer" << std::endl;
                } else {
                    std::cout << "Created global reference to output buffer" << std::endl;
                }
                // Delete the local reference
                jenv->DeleteLocalRef(noutbuf);
                checkAndClearException(jenv);

            }
            if (inputBufferSize > 0) {
                myInputBuffer = std::malloc(inputBufferSize);
                if(myInputBuffer == NULL) {
                    std::cout << "Could not create input buffer" << std::endl;
                } else {
                    std::cout << "Created input buffer" << std::endl;
                }

                jobject ninbuf = jenv->NewDirectByteBuffer(myInputBuffer, inputBufferSize);
                if (ninbuf == NULL) {
                    std::cout << "Could not create input buffer" << std::endl;
                } else {
                    std::cout << "Created input buffer" << std::endl;
                }
                checkAndClearException(jenv);
                jenv->CallObjectMethod(ninbuf, jenv->GetMethodID(jenv->GetObjectClass(ninbuf), "order", "(Ljava/nio/ByteOrder;)Ljava/nio/ByteBuffer;"), byteOrder);
                checkAndClearException(jenv);
                std::cout<<"Called order on input buffer"<<std::endl;
                // make inbuf a global reference so it stays alive past this scope
                inbuf = jenv->NewGlobalRef(ninbuf);
                if (inbuf == NULL) {
                    std::cout << "Could not create input buffer" << std::endl;
                } else {
                    std::cout << "Created global reference to input buffer" << std::endl;
                }
                // Delete the local reference
                jenv->DeleteLocalRef(ninbuf);
            }

            cbmeth = jenv->GetMethodID(interfaceCls, "callback", "(Ljava/nio/ByteBuffer;Ljava/nio/ByteBuffer;IDIJJ)I");
            jenv->DeleteLocalRef(interfaceCls); // Remember to delete local references
            if (!cbmeth) {
                std::cout << "Could not get callback method" << std::endl;
                assert(cbmeth != NULL);
            } else {
                std::cout << "Got callback method" << std::endl;
            }
            checkAndClearException(jenv);


            jenv->DeleteLocalRef(cbintf);

        }

        ~RtAudioCallbackWrapper() {
            std::cout << "RtAudioCallbackWrapper destructor called" << std::endl;


            if (myInputBuffer != nullptr) {
                std::free(myInputBuffer);
                myInputBuffer = nullptr;
            }
            if (myOutputBuffer != nullptr) {
                std::free(myOutputBuffer);
                myOutputBuffer = nullptr;
            }

        }

        // standard copy constructor
        RtAudioCallbackWrapper(const RtAudioCallbackWrapper& other) = delete;
        RtAudioCallbackWrapper operator=(const RtAudioCallbackWrapper& other) = delete;

///
        int javaCallback(void *outputBuffer, void *inputBuffer, unsigned int nFrames, double streamTime,
        RtAudioStreamStatus status, void *userData) {

            JNIEnv *jenv = getJNIEnv();
            assert(jenv != NULL);
            const jint jbufsize = nFrames;
            const jdouble jstreamtime = streamTime;
            const jint jstatus = status;
            jlong joutputBuffer = reinterpret_cast<jlong>(outputBuffer);
            jlong jinputBuffer = reinterpret_cast<jlong>(inputBuffer);
            jint jret;
            struct CallbackUserDataStruct *cbData = (struct CallbackUserDataStruct *)userData;

//            std::cout << "javaCallback called frm : " << nFrames << "  outbuf "  << outputBuffer << " inbuf " << inputBuffer
//            << "nouts " << nOutputChannels << " nins " << nInputChannels << std::endl;
            std::lock_guard<std::mutex> lock(bufferMutex);

            if (this->bufferSize != nFrames) {
                //std::cout << "framesize mismatch : " << nFrames << "  original :" << this->bufferSize << std::endl;
                if (outputBuffer != nullptr && outputBufferSize != 0) {
                    jenv->DeleteGlobalRef(outbuf);
                    std::free(myOutputBuffer);
                    myOutputBuffer = std::malloc(nFrames * formatSize * nOutputChannels);
                    if (myOutputBuffer == NULL) {
                        std::cerr << "Could not allocate output buffer" << std::endl;
                    } else {
                        outputBufferSize = nFrames * formatSize * nOutputChannels;
                        outbuf = jenv->NewDirectByteBuffer(myOutputBuffer, nFrames * formatSize * nOutputChannels);
                        assert(outbuf != NULL);
                        jenv->CallObjectMethod(outbuf, jenv->GetMethodID(jenv->GetObjectClass(outbuf), "order",
                                                                        "(Ljava/nio/ByteOrder;)Ljava/nio/ByteBuffer;"),
                                               byteOrder);
                    }
                }
                if (inputBuffer != nullptr && inputBufferSize != 0) {
                    jenv->DeleteGlobalRef(inbuf);
                    std::free(myInputBuffer);
                    myInputBuffer = std::malloc(nFrames * formatSize * nInputChannels);
                    if (myInputBuffer == NULL) {
                        std::cerr << "Could not allocate input buffer" << std::endl;
                    } else {
                        inputBufferSize = nFrames * formatSize * nInputChannels;
                        inbuf = jenv->NewDirectByteBuffer(myInputBuffer, nFrames * formatSize * nInputChannels);
                        assert(inbuf != NULL);
                        jenv->CallObjectMethod(inbuf, jenv->GetMethodID(jenv->GetObjectClass(inbuf), "order",
                                                                        "(Ljava/nio/ByteOrder;)Ljava/nio/ByteBuffer;"),
                                               byteOrder);
                    }

                    //std::cout << "bufferSize is " << this->bufferSize << " nFrames is " << nFrames << std::endl;
                }
                this->bufferSize = nFrames;
            }


            if (inputBuffer != nullptr && myInputBuffer != nullptr && nInputChannels > 0 ) {
                memcpy(this->myInputBuffer, inputBuffer, nFrames * formatSize * nInputChannels);
            }

            try
            {
                jret = jenv->CallIntMethod(javaCallbackObject, cbmeth, outbuf, inbuf, jbufsize, jstreamtime,
                                           jstatus, joutputBuffer, jinputBuffer);
            } catch (...) {
                std::cerr << "Exception in javaCallback" << std::endl;
                jret = 2;
                return jret;
            }

            //std::cout << "javaCallback returned : " << jret << std::endl;

            if (myOutputBuffer != nullptr && outputBuffer != nullptr && nOutputChannels > 0) {
                memcpy(outputBuffer,this->myOutputBuffer, nFrames * formatSize * nOutputChannels);
            }

            return jret;
        }

        void removeBufferReferences() {
            JNIEnv *jenv = attachJNIThread();
            if(jenv == nullptr) {
                std::cout<<"Could not get JNIEnv"<<std::endl;

            } else {
                std::cout<<"Got JNIEnv"<<std::endl;
            }
            std::lock_guard<std::mutex> lock(bufferMutex);

            std::cout<<"removeBufferReferences called"<<std::endl;

            if (outbuf != nullptr) {
                jenv->DeleteGlobalRef(outbuf);
                outbuf = nullptr;
            }
            if (inbuf != nullptr) {
                jenv->DeleteGlobalRef(inbuf);
                inbuf = nullptr;
            }
            if (myInputBuffer != nullptr) {
                free(myInputBuffer);
                myInputBuffer = nullptr;
            }
            if (myOutputBuffer != nullptr) {
                free(myOutputBuffer);
                myOutputBuffer = nullptr;
            }
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
        size_t outputBufferSize;
        size_t inputBufferSize;
        mutable std::mutex bufferMutex;

        int bufferSize;
        void* myInputBuffer;
        void* myOutputBuffer;

        jobject inbuf;  // Now a member variable
        jobject outbuf; // Now a member variable
        jobject byteOrder;
        jobject javaCallbackObject;
        bool useByteBuffer;
};


// this is the function that all streams use as callback address
// the userdata sets the index into the array of function pointers

static int java_callback(void *outputBuffer, void *inputBuffer,
                         unsigned int nFrames,
                         double streamTime,
                         RtAudioStreamStatus status,
                         void *userData) {

    std::lock_guard<std::mutex> lock(callbackMutex);
   // first cast user data to a callbackUserData struct
    CallbackUserDataStruct* cbData = (CallbackUserDataStruct*)userData;
    // check tht the struct is actually valid
    if(cbData == NULL) {
        // return a stream error abort the stream immediately
        std::cerr << "Error in stream" << std::endl;
        return 2;
    }
    // get the index into the array of function pointers
    int index = cbData->index;
    // get the pointer to the wrapped callback
    // find the wrapper pair in the map
    auto wrapper = callbackWrappers.find(index);
    if (wrapper != callbackWrappers.end()) {
        // call the wrapped callback
         std::shared_ptr<RtAudioCallbackWrapper> wrapper = callbackWrappers[index].second;
        return wrapper->javaCallback(outputBuffer, inputBuffer, nFrames, streamTime, status, userData);
    } else {
        // return a stream error abort the stream immediately
        std::cerr << "Error in stream" << std::endl;
        return 2;
    }


//    // get the function pointer from the array
//    std::function<int( void *outputBuffer, void *inputBuffer,
//                       unsigned int nFrames,
//                       double streamTime,
//                       RtAudioStreamStatus status,
//                       void *userData )> func = functors[index];
//    // check that the function pointer is valid
//   if(func != NULL){
//       // call the function pointer
//       return func(outputBuffer, inputBuffer, nFrames, streamTime, status, userData);
//   } else {
//       // return a stream error abort the stream immediately
//
//       return 2;
//   }

}

void printObjecttoString(jobject obj) {
    JNIEnv *env = getJNIEnv();
    jclass cls = env->GetObjectClass(obj);
    jmethodID mid = env->GetMethodID(cls, "toString", "()Ljava/lang/String;");
    if (mid == 0) {
        return;
    }
    jstring strObj = (jstring)env->CallObjectMethod(obj, mid);
    if (strObj == NULL) {
        return;
    }
    const char *str = env->GetStringUTFChars(strObj, 0);
    if (str == NULL) {
        return;
    }
    printf("Class name: %s\n", str);
    env->ReleaseStringUTFChars(strObj, str);
}


%} //////////////////////////// END OF C++ CODE ////////////////////////////


%pragma(java) modulecode=%{



    public interface RtAudioCallBackInterface {
        public int callback(java.nio.ByteBuffer outbuffer, java.nio.ByteBuffer inbuffer, int buffer_size,
                            double stream_time, int status,long outbufferptr, long inbufferptr);
        // user to provide callback data structure in order to provide information for bytebuffering
        public CallbackUserData getUserData();
}

    public interface CallbackUserData {
        public Object getData();
        public void setData(Object data);
        public Object getUserData();
        public int getIndex();
        public int getNInputChannels();
        public int getNOutputChannels();
        public int getFormat();
        public boolean getInterleaved();
        public int getBufferSize();

        public void setIndex(int index);
        public void setNInputChannels(int iChannels);
        public void setNOutputChannels(int oChannels);
        public void setFormat(int format);
        public void setInterleaved(boolean isInterleaved);
        public void setBufferSize(int bufferSize);
   }



%}




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


%typemap(in) RtAudioCallback {

    std::cout << "hello wrapper XXX"    << std::endl;


  JCALL1(GetJavaVM, jenv, &jvm);
  jobject obj;
  jobject inputObj = $input;

  std::lock_guard<std::mutex> locka(globalRefMutex);
  // check if we already made a global reference to this object
  if (globalRefs.find(inputObj) != globalRefs.end()) {
    // Object already has a global reference, reuse it or handle accordingly
    obj = inputObj;
  } else {
    // Create a new global reference
    obj = JCALL1(NewGlobalRef, jenv, $input);
    globalRefs[inputObj] = obj;
  }

  printObjecttoString(obj);
  // extract the callbackInfo from the obj provided
  const jclass cbintf = jenv->GetObjectClass(obj);
  assert(cbintf != NULL);

  jclass interfaceCls = JCALL1(FindClass, jenv, "ca/mcgill/rtaudio/api/RtAudioAPI$RtAudioCallBackInterface");
  jmethodID method = JCALL3(GetMethodID, jenv, interfaceCls, "getUserData", "()Lca/mcgill/rtaudio/api/RtAudioAPI$CallbackUserData;");
  JCALL1(DeleteLocalRef, jenv, interfaceCls);
  assert(method != NULL);

//jmethodID method = JCALL3(GetMethodID, jenv, cbintf, "getUserData", "()Lca/mcgill/rtaudio/api/RtAudioAPI/CallbackUserData;");
//assert(method != NULL);

// get the callbackInfo object
jobject callbackInfo = JCALL2(CallObjectMethod, jenv, obj, method);
assert (callbackInfo != NULL);

jclass callbackInfoClass = jenv->GetObjectClass(callbackInfo);
assert(callbackInfoClass != NULL);

jmethodID indexf = JCALL3(GetMethodID, jenv, callbackInfoClass, "getIndex", "()I");
jint index = JCALL2(CallIntMethod, jenv, callbackInfo, indexf);

// --- Thread safety with mutex ---
std::unique_lock<std::mutex> lock(callbackMutex);
bool reuse = false;

auto it = callbackWrappers.find(index);
if (it != callbackWrappers.end()) {
  // Wrapper already exists for this index, check if it's for the same Java object
  if (JCALL2(IsSameObject, jenv, it->second.first, obj) == JNI_TRUE) {
      // Same Java object, reuse the existing wrapper
     std::cout <<"Reusing existing callback wrapper" << std::endl;
     reuse = true;
   } else {
      // Different Java object, delete the old global reference and wrapper
      std::cout<<"Different Java object, deleting old global reference and wrapper"<<std::endl;
      JCALL1(DeleteGlobalRef,jenv,it->second.first);
      callbackWrappers.erase(it);
      functors.erase(index);
      callbackUserDataStructs.erase(index);
  }
}

if (! reuse) {
  // create a new wrapper object and add it to vector of std pointers
  std::shared_ptr<RtAudioCallbackWrapper> wrapper(new RtAudioCallbackWrapper(obj));
  // Store the wrapper in the map, associated with the index
  callbackWrappers[index] = std::make_pair(obj, wrapper);
  // check if the callbackUserDataStruct exists
    if(callbackUserDataStructs.find(index) == callbackUserDataStructs.end()) {
        // create a new CallbackUserDataStruct at the index
        callbackUserDataStructs[index] = std::make_shared<CallbackUserDataStruct>();
        callbackUserDataStructs[index]->index = index;
    }

  // Create a new functor and store it in the map
  std::cout << "Adding new callback at index: " << index << std::endl;
  functors[index] = ([index](void *outputBuffer,void *inputBuffer,unsigned int nFrames,double streamTime, RtAudioStreamStatus status, void *userData) {
    return (callbackWrappers[index].second.get()->javaCallback(outputBuffer, inputBuffer, nFrames, streamTime, status, userData));
  });
 }
lock.unlock();

$1 = java_callback;
}


%include "../RtAudio.h"
%include "swigstructs.h"

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

