//
//  DetailsViewController.swift
//  Sample iOS App
//
//  Created by Miles Hollingsworth on 4/22/18
//  Copyright © 2018 Miles Hollingsworth. All rights reserved.
//

import UIKit
import OpenCastSwift

class DetailsViewController: UIViewController {
  @IBOutlet weak var modelNameLabel: UILabel!
  @IBOutlet weak var currentApplicationLabel: UILabel!
  @IBOutlet weak var currentApplicationIdLabel: UILabel!
  
  
  @IBOutlet weak var videoOutView: UIView!
  @IBOutlet weak var videoInView: UIView!
  @IBOutlet weak var audioOutView: UIView!
  @IBOutlet weak var audioInView: UIView!
  @IBOutlet weak var groupView: UIView!
  @IBOutlet weak var masterVolumeView: UIView!
  @IBOutlet weak var attenuationVolumeView: UIView!
  
  var client: CastClient! {
    didSet {
      client.delegate = self
      client.connect()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    modelNameLabel.text = client.device.modelName
    
    let capabilities = client.device.capabilities
    
    videoOutView.backgroundColor = capabilities.contains(.videoOut) ? .green : .red
    videoInView.backgroundColor = capabilities.contains(.videoIn) ? .green : .red
    audioOutView.backgroundColor = capabilities.contains(.audioOut) ? .green : .red
    audioInView.backgroundColor = capabilities.contains(.audioIn) ? .green : .red
    groupView.backgroundColor = capabilities.contains(.multizoneGroup) ? .green : .red
    masterVolumeView.backgroundColor = capabilities.contains(.masterVolume) ? .green : .red
    attenuationVolumeView.backgroundColor = capabilities.contains(.attenuationVolume) ? .green : .red
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    client.disconnect()
  }
  
  @IBAction func handleTestCast(_ sender: Any) {
    let youtube = YoutubeChannel()
    client.add(channel: youtube)

    client.launch(appId: CastAppIdentifier.youTube) { (result) in
      switch result {
      case .success(let app):
        youtube.playVideo(for: app, videoID: "oHg5SJYRHA0")
      case .failure(let error):
        print(error)
      }
    }
  }
}

extension DetailsViewController: CastClientDelegate {
  func castClient(_ client: CastClient, didConnectTo device: CastDevice) { }
  
  func castClient(_ client: CastClient, deviceStatusDidChange status: CastStatus) {
    currentApplicationLabel.text = status.apps.first?.displayName
    currentApplicationIdLabel.text = status.apps.first?.id
  }
}
