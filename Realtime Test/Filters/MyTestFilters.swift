//
//  filters.swift
//
//  Created by Erik Jackson on 2/9/18.
//  Copyright © 2018. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMedia
import Photos

struct Filter {
	let name:Int
	let nameStr:String
	let fps:Int
	let requiresPurchase:Bool
	let isDevFilter:Bool           // filter in development, and does not normally appear
	var pickerViewRowIndex:Int
	
	init(
		name:Int,
		nameStr:String,
		fps:Int,
		requiresPurchase:Bool,
		isDevFilter:Bool,
		pickerViewRowIndex:Int
	) {
		self.name = name
		self.nameStr = nameStr
		self.fps = fps
		self.requiresPurchase = requiresPurchase
		self.isDevFilter = isDevFilter
		self.pickerViewRowIndex = pickerViewRowIndex
	}
	
}

class MyTestFilters {
	
	enum filterNames: Int {
		case TestFilter
	}
	
	var filters = [
		Filter(
			name:filterNames.TestFilter.rawValue,
			nameStr:"TestFilter",
			fps:24,
			requiresPurchase:false,
			isDevFilter:false,
			pickerViewRowIndex:-1
		)
	]
	
	
	var selectedFilter: filterNames = filterNames.TestFilter
	
	
	
	func flipCameraOrientation(with ciImage:CIImage, imageOrientation:UIImage.Orientation?) -> CIImage {
		
		var ciImage = ciImage
		
		if(imageOrientation != nil){
			if imageOrientation == .right {
				ciImage = ciImage.oriented(.right)
			}else{
				ciImage = ciImage.oriented(.leftMirrored)
			}
		}
		
		return ciImage
	}
	
	func testFilter(with ciImage: CIImage,
							imageOrientation:UIImage.Orientation?) -> CIImage {
		
		var ciImage = ciImage
		
		
		let centerPoint = CGPoint(x:ciImage.extent.width/2,y:ciImage.extent.height/2)
		
		ciImage = ciImage
			.applyingFilter("CIGloom", parameters: [kCIInputImageKey: ciImage]).cropped(to: ciImage.extent)
		
		var imgTrans = CGAffineTransform.identity
		
		imgTrans = imgTrans.translatedBy(x: 0, y: 100)
		
		ciImage = ciImage
			.applyingFilter("CISourceAtopCompositing", parameters: [kCIInputImageKey: ciImage.transformed(by: imgTrans),
																	kCIInputBackgroundImageKey: ciImage])
			.cropped(to: ciImage.extent)
		
	
		imgTrans = imgTrans.translatedBy(x: 0, y: 300)
		
		ciImage = ciImage
			.applyingFilter("CISourceAtopCompositing", parameters: [kCIInputImageKey: ciImage.transformed(by: imgTrans),
																	kCIInputBackgroundImageKey: ciImage])
			.cropped(to: ciImage.extent)
		
		
		
		ciImage = ciImage
			.applyingFilter("CIBumpDistortion", parameters: [kCIInputImageKey: ciImage,
															 kCIInputCenterKey: CIVector(x:centerPoint.x,y:centerPoint.y)])
			.cropped(to: ciImage.extent)
		
		
		ciImage = flipCameraOrientation(with: ciImage, imageOrientation: imageOrientation)
		
		return ciImage
		
		
	}



}

