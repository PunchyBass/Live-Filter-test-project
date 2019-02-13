//
//  ImageView.swift
//  CoreImageHelpers
//
//  Created by Simon Gladman on 09/01/2016.
//  Updated by Erik Jackson
//  Copyright © 2016 Simon Gladman. All rights reserved.
//
import GLKit
import UIKit
import MetalKit
import QuartzCore


protocol MTLImageViewDelegate: class {
	func applyFilterAndReturnImage(ciImage:CIImage, orientation:UIImage.Orientation?, currentCameraRes:CGSize?) -> CIImage
}

extension MTLTexture {
	
	func threadGroupCount() -> MTLSize {
		return MTLSizeMake(8, 8, 1)
	}
	
	func threadGroups() -> MTLSize {
		let groupCount = threadGroupCount()
		return MTLSizeMake(Int(self.width) / groupCount.width, Int(self.height) / groupCount.height, 1)
	}
}

/// `MetalImageView` extends an `MTKView` and exposes an `image` property of type `CIImage` to
/// simplify Metal based rendering of Core Image filters.
class MetalImageView: MTKView
{
	
	weak var MTLDelegate: MTLImageViewDelegate?
	
	let colorSpace = CGColorSpaceCreateDeviceRGB()
	
	var textureCache: CVMetalTextureCache?
	
	var sourceTexture: MTLTexture!
	
	fileprivate let semaphore = DispatchSemaphore(value: 3)
	
	lazy var commandQueue: MTLCommandQueue =
		{
			[unowned self] in
			
			return self.device!.makeCommandQueue()
			}()!
	
	lazy var ciContext: CIContext =
		{
			[unowned self] in
			
			return CIContext(mtlDevice: self.device!)
			}()
	
	
	override init(frame frameRect: CGRect, device: MTLDevice?)
	{
		super.init(frame: frameRect,
				   device: device ?? MTLCreateSystemDefaultDevice())
		
		if super.device == nil
		{
			fatalError("Device doesn't support Metal")
		}
		
		var textCache: CVMetalTextureCache?
		if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device!, nil, &textCache) != kCVReturnSuccess {
			fatalError("Unable to allocate texture cache.")
		}
		else {
			self.textureCache = textCache
		}
		
		framebufferOnly = false
		
		enableSetNeedsDisplay = true
		
		isPaused = true
		
		preferredFramesPerSecond = 30
		
	}
	
	required init(coder: NSCoder)
	{
		fatalError("init(coder:) has not been implemented")
	}
	
	
	/// The image to display
	var image: CIImage?
	{
		didSet
		{
			setNeedsDisplay()
		}
	}
	
	override func draw(_ rect: CGRect)
	{
		autoreleasepool {
			
			_ = semaphore.wait(timeout: DispatchTime.distantFuture)
			
			guard
				var image = image,
				let commandBuffer:MTLCommandBuffer = commandQueue.makeCommandBuffer(),
				let targetTexture:MTLTexture = currentDrawable?.texture else
			{
				
				return
			}
			
			let customDrawableSize:CGSize = drawableSize
			
			let bounds = CGRect(origin: CGPoint.zero, size: customDrawableSize)
			
			if debug_applyLiveFilterInDraw && debug_applyLiveFilter {
				let orientation = UIImage.Orientation.right
		
				if let img = MTLDelegate?.applyFilterAndReturnImage(ciImage: image, orientation: orientation, currentCameraRes:currentCameraRes!){
					image = img
					semaphore.signal()
				}else{
					return
				}

			}
			
			if !debug_useNewMetalViewMode {
				
				let originX = image.extent.origin.x
				let originY = image.extent.origin.y


				let scaleX = customDrawableSize.width / image.extent.width
				let scaleY = customDrawableSize.height / image.extent.height

				let scale = min(scaleX*IVScaleFactor, scaleY*IVScaleFactor)

				image = image
					.transformed(by: CGAffineTransform(translationX: -originX, y: -originY))
					.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
				
			}

			
			ciContext.render(image,
							 to: targetTexture,
							 commandBuffer: commandBuffer,
							 bounds: bounds,
							 colorSpace: colorSpace)
			
			
			commandBuffer.addCompletedHandler { [weak self] (buffer) in
				guard let unwrappedSelf = self else { return }
				readyForNewImage = true
				unwrappedSelf.semaphore.signal()
			}
			

			commandBuffer.present(currentDrawable!)
			
			commandBuffer.commit()

		}
		
	}
	
}
