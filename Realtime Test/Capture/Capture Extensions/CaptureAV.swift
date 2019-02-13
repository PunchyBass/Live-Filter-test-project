//
//  CaptureAV.swift
//
//  Created by Erik Jackson on 12/6/18.
//  Copyright © 2018. All rights reserved.
//

import Foundation
import UIKit
import AVKit

extension CaptureVC {
	

	func setupCameraAndMic(){
		let backCamera = AVCaptureDevice.default(for:AVMediaType.video)
		
		var error: NSError?
		var videoInput: AVCaptureDeviceInput!
		do {
			videoInput = try AVCaptureDeviceInput(device: backCamera!)
		} catch let error1 as NSError {
			error = error1
			videoInput = nil
			print(error!.localizedDescription)
		}
		
		if error == nil &&
			captureSession!.canAddInput(videoInput) {
			
			guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, MetalDevice, nil, &textureCache) == kCVReturnSuccess else {
				print("Error: could not create a texture cache")
				return
			}
			
			captureSession!.addInput(videoInput)
			
			setDeviceFrameRateForCurrentFilter(device:backCamera)
			
			stillImageOutput = AVCapturePhotoOutput()
			print("stillImageOutput?.isHighResolutionCaptureEnabled = \(String(describing: stillImageOutput?.isHighResolutionCaptureEnabled))")
			
			
			if captureSession!.canAddOutput(stillImageOutput!) {
				captureSession!.addOutput(stillImageOutput!)

				
				let q = DispatchQueue(label: "sample buffer delegate", qos: .default)
				videoOutput.setSampleBufferDelegate(self, queue: q)
				videoOutput.videoSettings = [
					kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA),
				]
				videoOutput.alwaysDiscardsLateVideoFrames = false
				
				if captureSession!.canAddOutput(videoOutput){
					captureSession!.addOutput(videoOutput)
				}
				
				recordingSession = AVAudioSession.sharedInstance()
				
				do {
					try recordingSession.setCategory(.playAndRecord, mode: .default, options: [])
					try recordingSession.setActive(true)
					try recordingSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
					recordingSession.requestRecordPermission({(granted: Bool)-> Void in
						if granted {
							DispatchQueue.main.async {
								print("failed to start audio session! user didn't allow permission")
							}
						}
					})
				} catch let error as NSError {
					print("audioSession error: \(error.localizedDescription)")
				}
				
				
				captureSession!.startRunning()
								
			}
			
		}
		
		setDefaultFocusAndExposure()
	}
	
}
