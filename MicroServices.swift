//
//  MicroServices.swift
//  iflink-stdims_coestation
//
//  Created by 滑空モモンガ on 2022/06/22.
//  Copyright © 2022 TOSHIBA DIGITAL SOLUTIONS. All rights reserved.
//

import Foundation
import UIKit
import iflink_epaapi
import iflink_imsif

// IMSを登録する
public class MicroServices {
    private static var isLoaded = false
    public static func load() {
        if MicroServices.isLoaded {
            // 二重初期化防止
            return
        }
        MicroServices.isLoaded = true

        // コエステーション IMS
        ImsPackages.append(ImsPackage(CoestationIms.NAME,
                                      packageName: CoestationIms.PACKAGE,
                                      type: CoestationIms.self,
                                      icon: "ic_stdims_round",
                                      table: PREF_TABLE,
                                      key: "config_name",
                                      bundle: PREF_BUNDLE,
                                      storyboard: PREF_STORYBOARD,
                                      viewController: PREF_VIEW_CONTROLLER,
                                      viewControllerType: PrefCoestationImsViewController.self))

    }
}
