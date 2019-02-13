//
//  DeviceType.swift
//
//  Created by Erik Jackson on 12/6/18.
//  Copyright © 2018. All rights reserved.
//

import Foundation
import UIKit

extension CaptureVC {
	// list appears wrong (starting with Xr, the boundsNative.height value is wrong)
	// but so far, it only checks to see if the device type is greater than iPhone6SP_7P_8P
	func setDeviceType() {
		// set device type
		if UIDevice().userInterfaceIdiom == .phone {
			switch boundsNative.height {
			case 1334:
				deviceType = .iPhone6_6S_7_8
				print("device: iPhone6_6S_7_8")
			case 1920, 2208:
				deviceType = .iPhone6SP_7P_8P
				print("device: iPhone6SP_7P_8P")
			case 2436:
				deviceType = .iPhone_Xr
				print("device: iPhone_Xr")
				statusBarShouldBeHidden = false
			case 2688:
				deviceType = .iPhoneX_Xs
				print("device: iPhoneX_Xs")
				statusBarShouldBeHidden = false
			case 1792:
				deviceType = .iPhoneXs_Max
				print("device: iPhoneXs_Max")
				statusBarShouldBeHidden = false
			default:
				deviceType = .unknown
				print("device: unknown")
			}
		}
	}
}
