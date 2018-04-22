//
//  StatusItemController.swift
//  CastSync
//
//  Created by Miles Hollingsworth on 4/22/18
//  Copyright © 2018 Miles Hollingsworth. All rights reserved.
//

import Cocoa
import OpenCastSwift
import SwiftyJSON

class StatusItemController: NSObject {
  let statusItem = NSStatusBar.system.statusItem(withLength: 36)
  
  let scanner = CastDeviceScanner()
  var clients = [String: CastClient]()
  
  override init() {
    super.init()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(devicesChanged),
                                           name: CastDeviceScanner.deviceListDidChange,
                                           object: scanner)
    
    
    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu
    setMenus()
    statusItem.title = ""
    statusItem.image = NSImage(named: NSImage.Name(rawValue: "Cast"))
    
    statusItem.highlightMode = true
  }
  
  func handleClick(_ event: NSEvent) {
    
  }
  
  @objc func devicesChanged() {
    setMenus(devices: scanner.devices)
  }
  
  func setMenus(devices: [CastDevice] = []) {
    guard let menu = statusItem.menu else { return }
    
    if menu.items.count > 0 {
      menu.removeAllItems()
    }
    
    if devices.count > 0 {
      let items = devices.map { NSMenuItem(title: $0.name, action: #selector(handleSelection(item:)), keyEquivalent: "") }
      
      for item in items {
        item.target = self
        menu.addItem(item)
      }
    } else {
      let item = NSMenuItem(title: "Scanning", action: #selector(handleSelection(item:)), keyEquivalent: "")
      menu.addItem(item)
    }
  }
  
  @objc func handleSelection(item: NSMenuItem) {
    guard let index = statusItem.menu?.items.index(of: item) else { return }
    
    let device = scanner.devices[index]
    
    let client = CastClient(device: device)
    self.clients[device.id] = client
    client.delegate = self
    client.connect()
  }
  
  @objc func handleRefresh() {
    scanner.reset()
  }
  
  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    return true
  }
}

extension StatusItemController: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    scanner.startScanning()
  }
  
  func menuDidClose(_ menu: NSMenu) {
    scanner.stopScanning()
  }
}

extension StatusItemController: CastClientDelegate {
  func castClient(_ client: CastClient, didConnectTo device: CastDevice) {
//    client.requestStatus()
  }
  
  func castClient(_ client: CastClient, deviceStatusDidChange status: CastStatus) {
    guard status.apps.count > 0, client.connectedApp == nil else { return }

    client.setMuted(false)
    
    return
    client.join() { result in
      switch result {
      case .success(let app):
        client.requestMediaStatus(for: app)
        
      case .failure(let error):
        print(error)
      }
    }
  }
  
  func castClient(_ client: CastClient, mediaStatusDidChange status: CastMediaStatus) {
//    print(status.metadata)
//    client.stopCurrentApp()
  }
  
  func castClient(_ client: CastClient, connectionTo device: CastDevice, didFailWith error: Error?) {
    print(error)
  }
}
