//
//  StampingViewController.swift
//  BLETest
//
//  Created by Emplayee on 2022/05/24.
//  Copyright © 2022 Advanced Card Systems Ltd. All rights reserved.
//

import Foundation
import UIKit
import SmartCardIO
import ACSSmartCardIO



class StampingViewController: UIViewController {
    
    @IBOutlet weak var nameLabel: UILabel!
    
    @IBOutlet weak var attendanceButton: UIButton!
    
    @IBOutlet weak var leavingButton: UIButton!
    
    @IBOutlet weak var accountLabel: UILabel!
    
    @IBOutlet weak var accountTextField: UITextField!
    
    @IBOutlet weak var passwordLabel: UILabel!
    
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var loginButton: UIButton!
    
    @IBOutlet weak var cancelButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.attendanceButton.backgroundColor = UIColor.blue
        self.leavingButton.backgroundColor = UIColor.orange
        self.loginButton.backgroundColor = UIColor.green
        self.cancelButton.backgroundColor = UIColor.gray
        
        self.attendanceButton.setTitleColor(UIColor.white, for: .normal)
        self.leavingButton.setTitleColor(UIColor.white, for: .normal)
        self.loginButton.setTitleColor(UIColor.white, for: .normal)
        self.cancelButton.setTitleColor(UIColor.white, for: .normal)
        
        
        self.attendanceButton.titleLabel?.font = UIFont.systemFont(ofSize: 80)
        self.leavingButton.titleLabel?.font = UIFont.systemFont(ofSize: 80)
        self.loginButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        self.cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        
        nameLabel.text = "カードをかざしてください"

    }
    

}
