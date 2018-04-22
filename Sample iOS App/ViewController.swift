//
//  RootViewController.swift
//  Sample iOS App
//
//  Created by Miles Hollingsworth on 4/22/18
//  Copyright © 2018 Miles Hollingsworth. All rights reserved.
//

import UIKit
import OpenCastSwift

class RootViewController: UITableViewController {
  let scanner = CastDeviceScanner()
  
  var clients = [CastClient]() {
    didSet {
      if clients.count == 0 {
        tableView.reloadData()
      } else {
        tableView.insertRows(at: [IndexPath(row: clients.count-1, section: 0)], with: .none)
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    scanner.delegate = self
    scanner.startScanning()
    
    let refresh = UIRefreshControl()
    refresh.addTarget(self,
                      action: #selector(handleRefresh),
                      for: .valueChanged)
    
    tableView.refreshControl = refresh
  }
  
  @objc func handleRefresh() {
    tableView.refreshControl?.endRefreshing()
    clients.removeAll()
    scanner.reset()
    scanner.startScanning()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard let cell = sender as? UITableViewCell,
      let index = tableView.indexPath(for: cell)?.row,
      let detailsViewController = segue.destination as? DetailsViewController else { return }
    
    let client = clients[index]
    detailsViewController.client = client
    detailsViewController.navigationItem.title = client.device.name
  }
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return clients.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell") as? DeviceCell else { abort() }
    
    cell.nameLabel.text = clients[indexPath.row].device.name
    
    return cell
  }
}

extension RootViewController: CastDeviceScannerDelegate {
  func deviceDidComeOnline(_ device: CastDevice) {
    clients.append(CastClient(device: device))
  }
  
  func deviceDidChange(_ device: CastDevice) {}
  
  func deviceDidGoOffline(_ device: CastDevice) {}
}
