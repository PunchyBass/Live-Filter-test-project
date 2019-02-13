//
//  CaptureUIInitialization.swift
//
//  Created by Erik Jackson on 12/6/18.
//  Copyright © 2018. All rights reserved.
//

import Foundation
import UIKit

extension CaptureVC {

	
	func addBottomBlackBar(){
		if SCVO > 0 {
			let bottomBlackBar = UIView()
			bottomBlackBar.frame = CGRect(x:0, y:bounds.height - SCVO, width:bounds.width, height:SCVO)
			bottomBlackBar.backgroundColor = UIColor.black // .clear
			view.addSubview(bottomBlackBar)
		}
	}
}
