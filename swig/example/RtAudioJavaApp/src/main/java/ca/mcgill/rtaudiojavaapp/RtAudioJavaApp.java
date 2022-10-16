/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Project/Maven2/JavaApp/src/main/java/${packagePath}/${mainClassName}.java to edit this template
 */

package ca.mcgill.rtaudiojavaapp;

import ca.mcgill.rtaudio.api.RtAudio;
import ca.mcgill.rtaudio.api.RtAudio.StreamParameters;
import ca.mcgill.rtaudio.api.RtAudioAPI;
import ca.mcgill.rtaudio.api.RtAudioErrorType;
import ca.mcgill.rtaudio.api.SWIGTYPE_p_unsigned_int;
import java.util.List;

/**
 *
 * @author peterslack
 */
public class RtAudioJavaApp {

    public static void main(String[] args) {
        System.out.println("Hello World!");
        RtAudio rtAudio = new RtAudio();
        RtAudio.Api api = rtAudio.getCurrentApi();
        
        System.out.println("current api : " + api.toString());
        
        List<Long> deviceIds = rtAudio.getDeviceIds();
        
        for (Long dId:deviceIds) {
            System.out.println("*********************** device id found : " + dId);
            
            RtAudio.DeviceInfo d = rtAudio.getDeviceInfo(dId);
            RtAudioJavaApp.printDeviceInfo(d);
        
        }
        
        // try and open and close a stream on the default device
        long defaultOutputDevice= rtAudio.getDefaultOutputDevice();
        RtAudio.DeviceInfo dOut = rtAudio.getDeviceInfo(defaultOutputDevice);
        
        RtAudio.StreamParameters outParms = new StreamParameters();
        outParms.setNChannels(2);
        outParms.setFirstChannel(0);
        outParms.setDeviceId(defaultOutputDevice);
        
        
        class Callbacker implements RtAudioAPI.RtAudioCallBackInterface {
         public long callBackCounter = 0;

            @Override
            public int callback(byte[] outbytes, byte[] inbytes, int i, double d, int i1) {
                callBackCounter++;
                       
                return 0;
            }
        }
        
       
        Callbacker cb = new Callbacker();
        
        RtAudioAPI.SetCallback(cb);
        
       SWIGTYPE_p_unsigned_int buffers = RtAudioAPI.new_UnsignedIntPtr();
       RtAudioAPI.UnsignedIntPtr_assign(buffers, 256);
       
       long preferredSampleRate = dOut.getPreferredSampleRate();
       
       RtAudioErrorType err = rtAudio.openStream(outParms, null, RtAudioAPI.getRTAUDIO_FLOAT32(), preferredSampleRate, buffers, cb);
       
       if (err != RtAudioErrorType.RTAUDIO_NO_ERROR) {
           System.exit(1);
       }
       
       
       
       System.out.println("\nSTREAM OPEN ATTEMPT *********************** ");
       System.out.println("OPEN STATUS RETURN : " + err.toString());
       System.out.println("Returned buffsize  : " + RtAudioAPI.UnsignedIntPtr_value(buffers));
       System.out.println("Stream Latency     : " + rtAudio.getStreamLatency());
       System.out.println("Stream SampleRate  : " + rtAudio.getStreamSampleRate());
       System.out.println("Stream Time        : " + rtAudio.getStreamTime());
       
       err = rtAudio.startStream();

       System.out.println("START MSG " + err.toString());
       
        pressEnterToContinue(" Press Return Key to shut down stream and exit");
       
        err= rtAudio.abortStream();
        
       System.out.println("ABORT MSG " + err.toString());
        
       
        
       rtAudio.closeStream();
       
       System.out.println("callbacks " + cb.callBackCounter);
       
       System.exit(0);
        
    }
    
    public static void printDeviceInfo(RtAudio.DeviceInfo device) {
    
        System.out.println("Name                  : " + device.getName());
        System.out.println("Current SampleRate    : " + device.getCurrentSampleRate());
        System.out.print(  "Available SampleRates : ");
        for (Long srs:device.getSampleRates()) {
            System.out.print( srs + " ");
        }
        System.out.print("\n");
        System.out.println("Preferred SampleRate  : " + device.getPreferredSampleRate());
        System.out.println("Is Default Input?     : " + device.getIsDefaultInput());
        System.out.println("Is default Output?    : " + device.getIsDefaultOutput());
        System.out.println("Input Channels        : " + device.getInputChannels());
        System.out.println("Output Channels       : " + device.getOutputChannels());
        System.out.println("Native Formats        : " + device.getNativeFormats());
    
    }
    
    
    public static void pressEnterToContinue(String message)
 { 
        System.out.println(message);
        try
        {
            System.in.read();
        }  
        catch(Exception e)
        {}  
 }
    
}
