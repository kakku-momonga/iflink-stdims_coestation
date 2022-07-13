//
//  Project : ifLink
//
//  v4.0 : 2022/05 TDSL 新規作成
//  Copyright 2022 TOSHIBA DIGITAL SOLUTIONS. All rights reserved.
//

import Foundation
import XCGLogger
import iflink_imsif
import iflink_epaapi
import iflink_common

public class CoestationIms: IfLinkConnector {

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // 定数定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    public static let NAME = "CoestationIms"
    public static let PACKAGE = "jp.co.toshiba.iflink.stdims_coestation.CoestationIms"
    private static let PREF_LOG_LEVEL_KEY = "loglevel_ibeacon"
    
    private static var TAG: String { "COESTATION-IMS" }
    private var TAG: String { type(of: self).TAG }
    
    /** ログ出力レベル：CustomDevice */
    private static let LOG_LEVEL_CUSTOM_DEV = "COESTATION_CUSTOM-DEV"
    /** ログ出力レベル：CustomDevice */
    private static let LOG_LEVEL_CUSTOM_IMS = "COESTATION_CUSTOM-IMS"

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // プロパティ定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    //
    /** デバイス */
    private var mDevice: CoestationDevice?

    
    /* ログ出力切替フラグ */
    var bDBG = false

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // イニシャライザ定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////

    required init() {
        super.init(name: CoestationIms.NAME)
    }

    override public func takeDelegate() -> IfLinkConnectorImpl {
        return Delegate(self)
    }

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // デリゲートクラス定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    private class Delegate: IfLinkConnectorImpl {
        unowned let this: CoestationIms

        init (_ this: CoestationIms) {
            self.this = this
        }

        public func onActivationResult(result: Bool, epaDevice: EPADevice) {
            do {
                // デバイス追加
                this.mDevice = CoestationDevice(ims: this)
                try this.addDevice(device: this.mDevice!)
                
            } catch {
                Log.e(TAG, "", error.localizedDescription)
            }
        }

        public func updateLogLevelSettings(settings: Set<String>) {            
            var isEnabledLog = false
            if settings.contains(CoestationIms.LOG_LEVEL_CUSTOM_IMS) {
                isEnabledLog = true
                Log.d(TAG, "LogLevel settings=\(settings)")
            }
            this.bDBG = isEnabledLog
            
            isEnabledLog = false
            if settings.contains(CoestationIms.LOG_LEVEL_CUSTOM_DEV) {
                isEnabledLog = true
            }
            
            for device in this.mDeviceList {
                device.takeDelegate().enableLogLocal(on: isEnabledLog)
            }
        }
        
        func updateConfigForIms() throws {
            
        }
        
        func getLogLevelKey() -> String {
            return CoestationIms.PREF_LOG_LEVEL_KEY
        }
        
        func getSettingDisplayClassName() -> String {
            return PREF_VIEW_CONTROLLER
        }
    }
}
