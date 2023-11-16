//
// Created by Peter Slack on 2023-11-15.
//

#ifndef RTAUDIO_SWIGSTRUCTS_H
#define RTAUDIO_SWIGSTRUCTS_H

struct CallbackUserDataStruct {
    int index;
    int nInputChannels;
    int nOutputChannels;
    long format;
    bool interleaved;

};

void * getCallbackUserDataStruct(int index, int nInputChannels, int nOutputChannels, long format, bool interleaved);


#endif //RTAUDIO_SWIGSTRUCTS_H
