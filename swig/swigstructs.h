//
// Created by Peter Slack on 2023-11-15.
//

#ifndef RTAUDIO_SWIGSTRUCTS_H
#define RTAUDIO_SWIGSTRUCTS_H

struct CallbackUserDataStruct {
    int index;
    jobject object;
};


void* convertSwigCptr(long long cptr);

void *getCallbackUserDataStruct(int index);



#endif //RTAUDIO_SWIGSTRUCTS_H
