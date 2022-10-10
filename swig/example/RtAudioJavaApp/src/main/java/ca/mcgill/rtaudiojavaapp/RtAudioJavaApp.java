/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Project/Maven2/JavaApp/src/main/java/${packagePath}/${mainClassName}.java to edit this template
 */

package ca.mcgill.rtaudiojavaapp;

import ca.mcgill.rtaudio.api.RtAudio;
import ca.mcgill.rtaudio.api.RtAudioAPI;
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
    
    
}
