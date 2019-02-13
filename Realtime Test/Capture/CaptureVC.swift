//
// CaptureVC.swift
//
//  Created by Erik Jackson on 10/23/17.
//  Copyright © 2017. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

let debugMCaptureVCAllOrientationsOn = false

var debug_applyLiveFilter:Bool = true
var debug_applyLiveFilterInDraw:Bool = false
var debug_updateMetalView:Bool = true
var debug_convertCameraImageWithMetal:Bool = true
var debug_useNewMetalViewMode:Bool = true

var readyForNewImage:Bool = true

// Purchase requirements
var appPurchased = false

// Device types:
enum deviceTypes: Int {
	case iPhone6_6S_7_8
	case iPhone6SP_7P_8P
	case iPhoneX_Xs
	case iPhoneXs_Max
	case iPhone_Xr
	case unknown
}

var deviceType: deviceTypes = .unknown

var statusBarShouldBeHidden = true

let myTestFilters = MyTestFilters()

var upresMetalView:Bool = true
var upscaleMult:CGFloat = 1.0
let IVScaleFactor:CGFloat = upresMetalView ? 1.0/1.5 : 1.0 // set this to divide the Metal imageView render

// controls v-offset depending on device's screen height compared to 667 points
var SCVO:CGFloat = 0.0

var currentCameraRes:CGSize? = nil

enum interfaceOrientations: Int {
	case portrait
	case landscapeLeft
	case landscapeRight
	case portraitUpsideDown
}

var selectedInterfaceOrientation: interfaceOrientations = interfaceOrientations.portrait
var ignoreSelectedInterfaceOrientation: Bool = false


var isFrontCamera = false

protocol MainViewControllerAppDelegate: class {
	func capturePhoto(with: AVCapturePhotoSettings, delegate: AVCapturePhotoCaptureDelegate)
}

weak var delegate:MainViewControllerAppDelegate?

class CaptureVC:
UIViewController,
AVCapturePhotoCaptureDelegate,
AVCaptureVideoDataOutputSampleBufferDelegate,
UINavigationControllerDelegate,
MTLImageViewDelegate
{

	
	// tutorial timer to check if settings have been authorized to take away message and continue
	var settingsAuthCheckTimer:Timer? = nil
	
	
	// debug timer
	var db_currentCalls:Int = 0
	var debugTimer:Timer = Timer()
	
	var MTLCaptureView:MetalImageView? = nil
	var MTLContext:CIContext? = nil
	
	
	var captureSession: AVCaptureSession?
	var stillImageOutput: AVCapturePhotoOutput?
	let videoOutput = AVCaptureVideoDataOutput()
	var captureOutput = true
	let captureOutputMTLOptions: [CIImageOption : Any] = [CIImageOption.colorSpace: CGColorSpaceCreateDeviceRGB(),
														  CIContextOption.outputPremultiplied: true,
														  CIContextOption.cacheIntermediates: false,
														  CIContextOption.useSoftwareRenderer: false] as! [CIImageOption : Any]
	enum imageCaptureModes: Int {
		case importPhoto = 1,
		takePhoto,
		takeVideo
	}
	enum FlashModes {
		case off
		case on
		case auto
	}
	var currentFlashMode: CaptureVC.FlashModes = FlashModes.off
	var imageCaptureMode = imageCaptureModes.takePhoto
	var lastImageCaptureMode = imageCaptureModes.takePhoto
	
	// audio recording
	var recordingSession: AVAudioSession!
	
	let bounds = UIScreen.main.bounds
	lazy var deviceWidth = bounds.size.width
	lazy var deviceHeight = bounds.size.height
	
	let boundsNative = UIScreen.main.nativeBounds
	lazy var deviceNativeWidth = boundsNative.size.width
	lazy var deviceNativeHeight = boundsNative.size.height
	
	var loadingContainer: UIView!

	
	var MetalDevice: MTLDevice!
	var textureCache: CVMetalTextureCache?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		setDeviceType()
		
		MetalDevice = MTLCreateSystemDefaultDevice()
		
		setNeedsStatusBarAppearanceUpdate()
		
		// set SCVO
		/* for devices that have an aspect ratio that is not equal to the video size,
		   the position of the video and the UI need to be vertically offset,
		   so that they are centered */
		if deviceType.rawValue > deviceTypes.iPhone6SP_7P_8P.rawValue {
			SCVO = (self.bounds.height - 667) / 2
		}
		
		
		ignoreSelectedInterfaceOrientation = false
		
		// setup camera session
		captureSession = AVCaptureSession()
		setAVCaptureSessionPresetResolution()
		
		// set upscale multiplier
		upscaleMult = deviceNativeWidth / (currentCameraRes?.height)!
		
		// add Metal camera view
		MTLCaptureView = MetalImageView()
		MTLCaptureView?.MTLDelegate = self
		if debug_useNewMetalViewMode {
			// reduce size of MTLCaptureView to the cameraRes converted to points
			guard let cameraRes = currentCameraRes else { return }
			let deviceRenderAtMult:CGFloat = 3
			MTLCaptureView?.frame = CGRect(x:0, y:0, width:cameraRes.height / deviceRenderAtMult, height:cameraRes.width / deviceRenderAtMult)
		}else{
			MTLCaptureView?.frame = view.bounds
		}
		
		translateMTLView()
		view.addSubview(MTLCaptureView!)
		
		MTLContext = MTLCaptureView?.ciContext

		// debug timer
		debugTimer = Timer.scheduledTimer(timeInterval: 1.00, target: self, selector: #selector(self.functionCallsPerSecond), userInfo: nil, repeats: true)
		
		// add bottom black bar for long phones
		addBottomBlackBar()

		setupCameraAndMic()
		
    }
	
	
	override open var shouldAutorotate: Bool {
		return false
	}
	
	@objc func setDefaultFocusAndExposure() {
		
		if let captureDevice = AVCaptureDevice.default(for:AVMediaType.video) {
			do {
				try captureDevice.lockForConfiguration()
					captureDevice.isSubjectAreaChangeMonitoringEnabled = true
					captureDevice.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
					captureDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
				captureDevice.unlockForConfiguration()
				
			} catch {
				// Handle errors here
				print("There was an error focusing the device's camera")
			}
		}
	}
	

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

	}
	

	@objc func applicationDidBecomeActive(notification: NSNotification) {
		print("app became active")
		if captureSession?.isRunning == false { 
			captureSession!.startRunning()
		}
	}
	
	func resetZoom() {
		
		let device = AVCaptureDevice.default(for: .video)
		do {
			try device?.lockForConfiguration()
			defer { device?.unlockForConfiguration() }
			device?.videoZoomFactor = 1.0
		} catch {
			print("\(error.localizedDescription)")
		}
		
	}
	
	
	@objc func functionCallsPerSecond(){
		//print("function calls per sec = \(db_currentCalls)")
		db_currentCalls = 0
	}

	func setAVCaptureSessionPresetResolution(){
		if(captureSession!.canSetSessionPreset(AVCaptureSession.Preset.hd1280x720)){
			captureSession!.sessionPreset = AVCaptureSession.Preset.hd1280x720
			currentCameraRes = CGSize(width:1280, height:720)
		}else if(captureSession!.canSetSessionPreset(AVCaptureSession.Preset.vga640x480)){
			captureSession!.sessionPreset = AVCaptureSession.Preset.vga640x480
			currentCameraRes = CGSize(width:640, height:480)
		}
	}

	
	func translateMTLView() {
		if upresMetalView {
			
			if debug_useNewMetalViewMode {
				
				guard let captureView = self.MTLCaptureView else { return }
				
				let scaleBy:CGFloat = view.bounds.width / captureView.frame.width
				print("scaleBy = \(scaleBy)")
				var mtlTransform: CGAffineTransform = .identity

				mtlTransform = mtlTransform.scaledBy(x: scaleBy, y: scaleBy)
				
				
				UIView.animate(withDuration: 2.3, delay: 0.0, options: [], animations: {
					
					captureView.transform = mtlTransform
					
				}, completion: { (finished: Bool) in
					
					let MTLFrame = captureView.frame
					
					self.MTLCaptureView?.frame = CGRect(x:0,
														y:SCVO,
														width: MTLFrame.width,
														height:MTLFrame.height)
					
				})
				
			}else{
			
				var mtlTransform: CGAffineTransform = .identity
				//IVScaleFactor
				let scaleBy:CGFloat = 1.0/IVScaleFactor
				mtlTransform = mtlTransform.scaledBy(x: scaleBy, y: scaleBy)

				let dbX = (bounds.width * IVScaleFactor) / 4
				let dbY = -((bounds.height * IVScaleFactor) / 4)
				
				mtlTransform = mtlTransform.translatedBy(x: dbX, y: dbY)
				
				UIView.animate(withDuration: 0.3, delay: 0.0, options: [], animations: {
					
					self.MTLCaptureView?.transform = mtlTransform
					
				}, completion: { (finished: Bool) in
					
					if SCVO > 0 {
						
						let MTLFrame = (self.MTLCaptureView?.frame)!
						
						self.MTLCaptureView?.frame = CGRect(x:MTLFrame.minX,
															y:MTLFrame.minY - SCVO,
															width: MTLFrame.width,
															height:MTLFrame.height)
						
					}
					
				})
				
			}
			
		}
		
	}
	

	
	func convertToMTLTexture(sampleBuffer: CMSampleBuffer?) -> MTLTexture? {
		if let textureCache = textureCache,
			let sampleBuffer = sampleBuffer,
			let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

			let width = CVPixelBufferGetWidth(imageBuffer)
			let height = CVPixelBufferGetHeight(imageBuffer)

			var texture: CVMetalTexture?
			CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache,
													  imageBuffer, nil, .bgra8Unorm, width, height, 0, &texture)
			if let texture = texture {
				return CVMetalTextureGetTexture(texture)
			}
		}
		return nil
	}
	
	// live output from camera
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
		
		db_currentCalls += 1
		
		if(captureOutput && readyForNewImage){
			
			DispatchQueue.main.async(){
				
				readyForNewImage = false
				
				// create CIImage from camera
				guard let texture:MTLTexture = self.convertToMTLTexture(sampleBuffer: sampleBuffer) else {
					return
				}
				
				var cameraImage:CIImage? = nil
				
				if debug_convertCameraImageWithMetal {
				
					cameraImage = CIImage(mtlTexture: texture, options: self.captureOutputMTLOptions)!
					
					var transform: CGAffineTransform = .identity
					
					transform = transform.scaledBy(x: 1, y: -1)
					
					transform = transform.translatedBy(x: 0, y: -(cameraImage?.extent.height)!)
					
					cameraImage = cameraImage?.transformed(by: transform)
				
				}else{
				
					// old non-Metal way of getting the ciimage from the cvPixelBuffer
					guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else
					{
						return
					}
					
					cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
				}
				
				guard var camIMG:CIImage = cameraImage else {
					return
				}

				// apply filter to camera image
				if debug_applyLiveFilter && !debug_applyLiveFilterInDraw {
					let orientation = UIImage.Orientation.right

					camIMG = self.applyFilterAndReturnImage(ciImage: camIMG, orientation: orientation, currentCameraRes:currentCameraRes!)
				}

				
				if debug_updateMetalView {
					
					if debug_useNewMetalViewMode {
						let originX = camIMG.extent.origin.x
						let originY = camIMG.extent.origin.y
						
						let customDrawableSize:CGSize = (self.MTLCaptureView?.drawableSize)!
						
						let scaleX = customDrawableSize.width / camIMG.extent.width
						let scaleY = customDrawableSize.height / camIMG.extent.height
						
						let scale = min(scaleX, scaleY)
						
						camIMG = camIMG
							.transformed(by: CGAffineTransform(translationX: -originX, y: -originY))
							.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
					}
					
					self.MTLCaptureView!.image = camIMG
				}
			}
			
		}
		
//		if !readyForNewImage {
//			print("not ready for new image")
//		}
		
	}
	
	func applyFilterAndReturnImage(ciImage:CIImage, orientation:UIImage.Orientation?, currentCameraRes:CGSize?) -> CIImage {
		
		var result:CIImage? = nil
		
		if(myTestFilters.selectedFilter == MyTestFilters.filterNames.TestFilter){
			
			result = myTestFilters.testFilter(with:ciImage,
												imageOrientation:orientation)
			
		}
		
		return result!
		
	}
	

	
	override var prefersStatusBarHidden: Bool {
		return statusBarShouldBeHidden
	}
	
	override var preferredStatusBarStyle : UIStatusBarStyle {
		return .lightContent
	}
	
	func setDeviceFrameRateForCurrentFilter(device:AVCaptureDevice?) {
	
		if let filter = myTestFilters.filters.first(where: {$0.name == myTestFilters.selectedFilter.rawValue}) {
			
			let framesPerSec = filter.fps
			
			do {
				try device!.lockForConfiguration()
				let timeValue = Int64((framesPerSec * 100) / framesPerSec)
				let timeScale: Int64 = Int64(framesPerSec * 100)
				
				device?.activeVideoMinFrameDuration = CMTimeMake(value: timeValue, timescale: Int32(timeScale))
				device?.activeVideoMaxFrameDuration = CMTimeMake(value: timeValue, timescale: Int32(timeScale))
				
				
				device!.unlockForConfiguration()
				
			} catch {
				print("\(error.localizedDescription)")
			}
			
		}
		
	}
	

}

