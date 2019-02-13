//
//  UIKitExtensions.swift
//
//  Created by Erik Jackson on 11/28/18.
//  Copyright © 2018. All rights reserved.
//

import UIKit


extension UIImagePickerController {
	override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .all
	}
	open override var childForStatusBarHidden: UIViewController? {
		return nil
	}
	open override var prefersStatusBarHidden: Bool {
		return statusBarShouldBeHidden
	}
}
