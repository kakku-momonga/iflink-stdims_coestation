//
//  Localization.swift
//  iflink-stdims_coestation
//
//  Created by 滑空モモンガ on 2022/07/06.
//  Copyright © 2022 TOSHIBA DIGITAL SOLUTIONS. All rights reserved.
//

import Foundation
import UIKit

private class Holder {
    static let shared = Holder()
    //static let bundle = Bundle(for: type(of: Holder()))
    lazy var url = Bundle.main.url(forResource: PREF_BUNDLE, withExtension: "bundle")!
    lazy var bundle = Bundle(url: url)!
    
    init(){
        print("url " + url.absoluteString)
    }
}

enum L10n {
    // stdims_coestation
    enum stdims_coestation: String {
        case config_name
        case pref_apikey_title
        case pref_apikey_summary
        case pref_apikey_dialogTitle
        case pref_logging_title
        case pref_logging_summary
        case default_devicename_display
        
        public var string: String {
            //return NSLocalizedString(self.rawValue, tableName: PREF_TABLE, comment: "")
            
            return NSLocalizedString(self.rawValue, tableName: PREF_TABLE, bundle: Holder.shared.bundle, comment: "")
             
        }
    }
}
