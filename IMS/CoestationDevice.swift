//
//  Project : ifLink
//
//  v4.0 : 2022/05 TDSL 新規作成
//  Copyright 2022 TOSHIBA DIGITAL SOLUTIONS. All rights reserved.
//

import Foundation
import AVFoundation

import iflink_imsif
import iflink_epaapi
import iflink_common

class CoestationDevice: DeviceConnector {

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // 定数定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////

    /* Log出力用タグ */
    private static var TAG: String { "COESTATION-DEV" }
    private var TAG: String { type(of: self).TAG }
    
     
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // プロパティ定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    private var mDevice: Delegate!
    private var isRunning = false
    private var executionFlag = false
    
    let codec : String = "audio/mpeg"

    // 対象サービスUUIDリスト
    //private var mServiceUUIDList: [CBUUID] = []
    /* ログ出力切替フラグ */
    private var bDBG = false
    
    struct Body : Codable {
        var plain_text: String
        var lang: String
        var coe_id: String
        let systemlexicon_id: String = "latest"
        let userlexicon_ids : Array<String> = []
        let txtproc_read_digit: Int = 0
        let txtproc_jajp_read_digit : Int = 0
        let txtproc_jajp_read_symbol : Int = 0
        let txtproc_jajp_read_alphabet : Int = 0
        let tag_mode : Int = 0
        var speed : Int = 0
        var pitch : Int = 0
        var happy : Int = 0
        var angry : Int = 0
        var sad : Int = 0
        let voiceelements : Array<Int> = [
          0
        ]
        var depth : Int = 0
        var volume : Int = 0
        let codec : String = "audio/mpeg"
        let kbitrate : Int = 64
        let freq : Int = 22050
        let sound_effect : String = "none"
        let firequalizer : [Firequalizer] = [ Firequalizer()
        ]
        let profanity_words_filter : BooleanLiteralType = false
    }
    struct Firequalizer : Codable {
        let freq : Int = 0
        let gain : Int = 0
    }
    
    let defaultAPIKey = "MjChVwNzAA34pQZn1Y4kW2HxRpW8P2Vm19Ey86og"
    var apiKey : String

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // イニシャライザ定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////

    public init (ims: IfLinkConnector) {
        let monitorLevel = DeviceConnector.MONITORING_LEVEL0
        let deviceName = "iflink.Coestation"
        let deviceSerial = "epa"
        let schemaName = deviceName
        let schemaXml = IfLinkXMLElement(name: "schema", attributes: ["name": "\(schemaName)"])
        let devicename = IfLinkXMLElement(name: "property",
                                          attributes: ["name": "devicename", "type": "string"])
        let deviceserial = IfLinkXMLElement(name: "property",
                                            attributes: ["name": "deviceserial", "type": "string"])
        let timestamp = IfLinkXMLElement(name: "property",
                                         attributes: ["name": "timestamp", "type": "timestamp"])
        _ = schemaXml.addChildren([devicename, deviceserial, timestamp])
        let schema: String = schemaXml.xml
        let assetName = "Coestation"
        let cookie = DeviceConnector.generateCookie(deviceName: deviceName, job: true, config: false, alert: false)
        self.apiKey = defaultAPIKey

        super.init(ims: ims,
                   monitorLevel: monitorLevel,
                   deviceName: deviceName,
                   deviceSerial: deviceSerial,
                   schemaName: schemaName,
                   schema: schema,
                   assetName: assetName,
                   cookie: cookie)

        notifyConnectDevice()
        
    }
    
    override public func takeDelegate() -> DeviceConnectorImpl {
        mDevice = Delegate(self)
        return mDevice
    }

    
    
    struct Record : Codable {
        var coe_id : String = ""
        var text : String = ""
        var happy : Int = 0
        var sad : Int = 0
        var angry : Int = 0
        var volume : Int = 0
        var speed : Int = 0
        var pitch : Int = 0
        var depth : Int = 0
        var fileName : String
        
        func equal(coe_id : String, text : String, happy : Int, sad : Int, angry : Int,
                   volume : Int, speed : Int, pitch : Int, depth : Int) -> (Bool, URL) {
            if self.coe_id == coe_id && self.text == text && self.happy == happy &&
                self.sad == sad && self.angry == angry && self.volume == volume &&
                self.speed == speed && self.pitch == pitch && self.depth == depth {
                let url : URL = makeURL()
                return (true, url)
            } else {
                return (false, URL(string: "nodata")!)
            }
        }
        /*
         iOS シュミレーターではパスの名前が変わるので（ファイルは変わらない）URLを再生成する必要がある
         実機の場合は未調査
         */
        func makeURL() -> URL {
            guard let fileURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(self.fileName) else { return URL(string: "filemanager_error")! }
            return fileURL
        }
        
        init(coe_id : String, text : String, happy : Int, sad : Int, angry : Int,
             volume : Int, speed : Int, pitch : Int, depth : Int, fileURL : String) {
            self.coe_id = coe_id
            self.text = text
            self.happy = happy
            self.sad = sad
            self.angry = angry
            self.volume = volume
            self.speed = speed
            self.pitch = pitch
            self.depth = depth
            self.fileName = fileURL
        }
    }



    
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // デリゲートクラス定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    private class Delegate: NSObject, DeviceConnectorImpl {
        var apiKey = "MjChVwNzAA34pQZn1Y4kW2HxRpW8P2Vm19Ey86og"
        unowned let this: CoestationDevice
        var audio : AVAudioPlayer?
        var records : [Record] = []

        init (_ this: CoestationDevice) {
            self.this = this
        }

        public func onActivationResult(success: Bool) -> Bool {
            return true
        }

        public func onStartDevice() -> Bool {
            this.startDeviceMonitoring()
            return true
        }

        public func onStopDevice() -> Bool {
            return true
        }

        public func onJob(map: [String: Any]) -> Bool {
            /* 謎ロジック */
            if let control = map[DeviceConnector.JOB_PARAM_CONTROL_KEY] as? String {
                if this.bDBG {
                    Log.d(TAG, "Not supported JOB:control = \(control)")
                }
            }
            /* コエステーションロジック */
            if (map.keys.contains(COESTATION_COE_KEY) == false ||
                map.keys.contains(COESTATION_TXT_KEY) == false) {
                Log.i(TAG, "onjob no parameter received");
                return false;
            }
            Log.i(TAG, "onjob process start");
            guard let sentence = map[COESTATION_TXT_KEY] as? String else {
                Log.i(TAG, "onjob noCOESTATION_TXT_KEY");
                return false;
            }
            guard let coe = map[COESTATION_COE_KEY] as? String else {
                Log.i(TAG, "onjob COESTATION_COE_KEY");
                return false;
            }
            guard let lang = map[COESTATION_LANG] as? String else {
                Log.i(TAG, "onjob COESTATION_LANG");
                return false;
            }
            guard let speed : Int = Int(map[COESTATION_SPEED] as? String ?? "0") else {
                Log.i(TAG, "onjob COESTATION_SPEED");
                return false;
            }
            guard let pitch : Int = Int(map[COESTATION_PITCH] as? String ?? "0") else {
                Log.i(TAG, "onjob COESTATION_PITCH");
                return false;
            }
            guard let range : Int = Int(map[COESTATION_RANGE] as? String ?? "0") else {
                Log.i(TAG, "onjob COESTATION_RANGE");
                return false;
            }
            guard let happy : Int = Int(map[COESTATION_HAPPY]  as? String ?? "0") else {
                Log.i(TAG, "onjob COESTATION_HAPPY");
                return false;
            }
            guard let angry : Int = Int(map[COESTATION_ANGRY] as? String ?? "0") else {
                Log.i(TAG, "onjob COESTATION_ANGRY");
                return false;
            }
            guard let sad : Int = Int(map[COESTATION_SAD] as? String ?? "0") else {
                Log.i(TAG, "onjob COESTATION_SAD");
                return false;
            }
            guard let volume : Int = Int(map[COESTATION_VOLUME] as? String ?? "0") else {
                Log.i(TAG, "onjob COESTATION_VOLUME");
                return false;
            }
           if  sentence == "" {
                return false;
            }
            let encoder = JSONEncoder()

            var bodyData : Body = Body(plain_text: sentence, lang: lang, coe_id: coe, speed: speed, pitch: pitch, happy: happy, angry: angry, sad: sad, depth: range, volume: volume)
            let encoded = try! encoder.encode(bodyData)

            let httpBody = try! JSONSerialization.jsonObject(with: encoded)
            print(httpBody)
            
            let url = URL(string: "https://web-api.coestation.jp/v1/plaintext2speechwave")
            var request = URLRequest(url: url!)
            request.httpMethod="POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(self.apiKey, forHTTPHeaderField: "X-Api-Key")
            request.httpBody = encoded
            
            let task = URLSession.shared
            task.dataTask(with: request) { [self] data, response, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                  }
            do {
                if error == nil, let data = data, let response = response as? HTTPURLResponse {
                    // HTTPヘッダの取得
                    print("Content-Type: \(response.allHeaderFields["Content-Type"] ?? "")")
                    // HTTPステータスコード
                    print("statusCode: \(response.statusCode)")
                    let today = Date();
                    let sec = today.timeIntervalSince1970
                    let millisec = UInt64(sec * 1000) // intだとあふれるので注意
                    let smil = String(millisec)

                    if response.statusCode == 200 {
                        if UserDefaults.standard.object(forKey: CONST_RECORDS) == nil {
                            let (flag, fn) : (Bool, String) = playMusic(data: data, d : smil)
                            if flag == true {
                                let a : Record = Record(coe_id: coe, text: sentence, happy: happy, sad: sad, angry: angry, volume: volume, speed: speed, pitch: pitch, depth: range, fileURL: fn)
                                records = [a]
                                let encoded = try! encoder.encode(records)
                                UserDefaults.standard.set(encoded, forKey: CONST_RECORDS)
                            }
                        } else {
                            // [Record]を更新する必要がある
                            let count : Int = records.count
                            DispatchQueue.main.sync {
                                let (flag, fn) : (Bool, String) = playMusic(data: data, d : smil)
                                if flag == true {
                                    let a : Record = Record(coe_id: coe, text: sentence, happy: happy, sad: sad, angry: angry, volume: volume, speed: speed, pitch: pitch, depth: range, fileURL: fn)
                                    if count == 5 {
                                        // ファイル保存のMAXになっている
                                        let url : URL = records[0].makeURL()
                                        let fileManager = FileManager.default
                                        if !fileManager.fileExists(atPath: url.path) {
                                            print("指定されたファイルまたはフォルダが存在しない("+url.path+")")
                                        } else {
                                            do {
                                                try fileManager.removeItem(at: url)
                                            } catch {
                                                return
                                            }
                                        }
                                        // records[0]が一番古い
                                        records.remove(at: 0)
                                        records.append(a)
                                    } else {
                                        records.append(a)
                                    }
                                    let encoded = try! encoder.encode(records)
                                    UserDefaults.standard.set(encoded, forKey: CONST_RECORDS)
                                }
                                
                            }
                        }

                    } else {
                    }
                    

                }
            } catch {
                print("JSONSerialization error:", error)
            }
        }.resume()


            return true
        }

        public func checkPathConnection() -> Bool { return true }

        public func checkDeviceConnection() -> Bool { return true }

        public func checkDeviceAlive() -> Bool { return true }

        public func reconnectPath() -> Bool { return true }

        public func reconnectDevice() -> Bool { return true }

        public func resendDevice() -> Bool { return true }
        
        func onTimeout(id: Int) {
            this.notifyRecvDataTimeout()
        }
        
        func onUpdateConfig(config: IfLinkSettings) throws {
            try this.updateConfig(config: config)
        }
        
        func enableLogLocal(on: Bool) {
            this.bDBG = on
            this.enableLogLocal(on: on)
        }
        
        func getDefaultAssetNameAlias() -> String? {
            //let a = L10n.stdims_coestation.pref_apikey_dialogTitle.string
            //return L10n.stdims_coestation.default_devicename_display.string
            return "コエステーション"
        }
        /*
         .WAV?.MP3?再生
         */
        func playMusic(data : Data, d : String) -> (Bool, String) {

            let fn = "data" + d + ".mp3"
            guard let fileURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(fn) else { return (false, "") }
            print("fileURL : " + fileURL.path)
            do {
                try data.write(to: fileURL, options : .atomic)
                let resources = try fileURL.resourceValues(forKeys:[.fileSizeKey])
                let fileSize = resources.fileSize!
                print ("\(fileSize)")

            } catch {
                print(error)
                return (false, "")
            }
            self.playVoiceRecord(url: fileURL)
            return (true, fn)
        }
        func playMusicFile(fileURL : URL) {

            do {
                audio = try AVAudioPlayer(contentsOf : fileURL)
                audio!.delegate = self as? AVAudioPlayerDelegate
                audio!.volume = 10
                audio!.prepareToPlay()
                audio!.play()
            } catch {
                print(error)
            }
        }
        private func playVoiceRecord( url: URL) {
                do {
                    try AVAudioSession.sharedInstance().setCategory(
                        AVAudioSession.Category.playback
                    )

                    try AVAudioSession.sharedInstance().setActive(true)

                    // Play a sound
                    audio = try AVAudioPlayer(
                        contentsOf: url
                    )

                    audio!.play()
                } catch let error {
                    print(error)
                }
        }

        

    }

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // メソッド定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    
    func sendData() {
        if executionFlag { return } else { executionFlag = true }
        defer { executionFlag = false }
        
        clearData()
        
      
    }


    func startDeviceMonitoring() {
	    // 実行中に設定
        isRunning = true
    }
    

    func updateConfig(config: IfLinkSettings) throws {
        // ログ出力切替フラグの取得・更新
        bDBG = try config.getBooleanValue(key: pref_logging_key, defaultValue: false)
        
        
    }
    
    func enableLogLocal(on: Bool) {
        bDBG = on
    }
}

