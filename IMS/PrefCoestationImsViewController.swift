//
//  Project : ifLink
//
//  v4.0 : 2022/05 TDSL 新規作成
//  Copyright 2022 TOSHIBA DIGITAL SOLUTIONS. All rights reserved.
//

import UIKit
import iflink_app
import iflink_common
import iflink_epaapi
import iflink_imsif
import iflink_ui

class PrefCoestationImsViewController: IfLinkBaseViewController {
    private static var TAG: String { PREF_VIEW_CONTROLLER }
    private var TAG: String { type(of: self).TAG }
    
    @IBOutlet weak var tableView: UITableView!
    //@IBOutlet weak var tableView: UITableView!
    
    var configSection = ConfigSection()
    
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // イニシャライザ定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////

    override func takeDelegate() -> IfLinkBaseViewControllerImpl {
        return Delegate(self)
    }

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    // デリゲートクラス定義
    // //////////////////////////////////////////////////////////////////////////////////////////////////
    private class Delegate: IfLinkBaseViewControllerImpl {
        unowned let this: PrefCoestationImsViewController

        init (_ this: PrefCoestationImsViewController) {
            self.this = this
        }
        
        func tag() -> String { return this.TAG }
        
        func getImsServiceIntent() -> Intent {
            let intent = Intent(CoestationIms.PACKAGE)
                .setPackage(IApplicationConstants.IFLINK_EPACORE_PACKAGE)
            return intent
        }
        
        func createConfigSection(configMap: [String: Any]) -> ConfigSection {
            var configSection: ConfigSection = ConfigSection()

            // ログ出力切替フラグ
            do {
                let key = pref_logging_key
                let value = this.getConfigData(configMap, key, false)
                configSection.appendItem(ConfigSwitchItem(key: key,
                                              title: L10n.stdims_coestation.pref_logging_title.string,
                                              summary: L10n.stdims_coestation.pref_logging_summary.string,
                                              status: value))
            }
            
            return configSection
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: "ConfigurationTableViewCell", bundle: nil), forCellReuseIdentifier: "cell")
        tableView.register(UINib(nibName: "SwitchTableViewCell", bundle: nil), forCellReuseIdentifier: "switch")
        
        // タイトルの設定
        self.navigationItem.title = L10n.stdims_coestation.config_name.string
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let _configSection = getConfigSection() else {
            return
        }
        
        configSection = _configSection
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        applySettings()
    }

}

extension PrefCoestationImsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return configSection.configItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        let configItem = configSection.configItems[indexPath.row]
        
        if let item = configItem as? ConfigSwitchItem {
            // スイッチ選択項目の場合
            cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: indexPath)
            if let switchCell = cell as? ITwoStateTableViewCell {
                switchCell.configure(item: item)
                switchCell.setOnChange {(key,value) in
                    // 設定情報を更新
                    self.setConfig(configSection: self.configSection,
                                                key: key,
                                                value: value)
                    //self.tableView.reloadData()
                }
            }
        } else
        if let item = configItem as? ConfigTextViewItem {
            // 複数行入力項目の場合
            cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            if let configCell = cell as? ITableViewCell {
                configCell.configure(title: item.title, summary: createSummary(key: item.key, value: item.value))
            }
        } else
        if let item = configItem as? ConfigTextFieldItem {
            // 単一入力項目の場合
            cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            if let configCell = cell as? ITableViewCell {
                configCell.configure(title: item.title, summary: item.value)
            }
        } else {
            fatalError("configItem is invalid type: \(configItem.self)")
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // セルの選択を解除
        tableView.deselectRow(at: indexPath, animated: true)
        
        let configItem = configSection.configItems[indexPath.row]
        
        if let _ = configItem as? ConfigSwitchItem {
            // スイッチ選択項目の場合、何もしない
        } else
        if let item = configItem as? ConfigTextViewItem {
            // 複数行入力項目の場合
            let storyboard: UIStoryboard = UIStoryboard(.UIComponent, bundle: nil)
            let controller =
                (storyboard.instantiateViewController(identifier: "TextViewDialogViewController"))
            if let dialog = controller as? IDialogViewController {
                dialog.configure(item: item)
                dialog.setCompletion { [weak self] (result) in
                    guard let self = self else {
                        return
                    }
                    guard let configCell = tableView.cellForRow(at: indexPath) as? ITableViewCell else { return }
                    // 設定値とサマリーを更新
                    self.configSection.configItems[indexPath.row].value = result.value
                    configCell.setSummary(self.createSummary(key: item.key, value: item.value))
                    // 設定情報を更新
                    if item.key == pref_apikey_key {
                        // UUIDリストの場合
                        //let valueArray = result.value.components(separatedBy: "\n")
                        self.setConfig(configSection: self.configSection,
                                                   key: item.key,
                                                   value: result.value)
                    } else {
                        self.setConfig(configSection: self.configSection,
                                                   key: item.key,
                                                   value: result.value)
                    }
                    self.tableView.reloadData()
                }
            }
            
            self.present(controller, animated: true, completion: nil)
        
        } else
        if let item = configItem as? ConfigTextFieldItem {
            // 単一入力項目の場合
            let storyboard: UIStoryboard = UIStoryboard(.UIComponent, bundle: nil)
            let controller =
                (storyboard.instantiateViewController(identifier: "TextFieldDialogViewController"))
            if let dialog = controller as? IDialogViewController {
                dialog.configure(item: item)
                dialog.setCompletion { [weak self] (result) in
                    guard let self = self else {
                        return
                    }
                    guard let configCell = tableView.cellForRow(at: indexPath) as? ITableViewCell else { return }
                    // 設定値とサマリーを更新
                    self.configSection.configItems[indexPath.row].value = result.value
                    configCell.setSummary(result.value)
                    // 設定情報を更新
                    self.setConfig(configSection: self.configSection,
                                               key: item.key,
                                               value: result.value)
                    self.tableView.reloadData()
                }
            }
            
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    func createSummary(key: String, value: String) -> String {
        let summary: String
        summary = ""
        return summary
    }
}

extension PrefCoestationImsViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return CustomPresentationView(presentedViewController: presented, presenting: presenting)
    }
}
