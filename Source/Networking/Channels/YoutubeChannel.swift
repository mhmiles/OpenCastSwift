//
//  YoutubeChannel.swift
//  OpenCastSwift
//
//  Created by Levi McCallum on 3/22/19
//  Copyright © 2018 Miles Hollingsworth. All rights reserved.
//

import Foundation
import Result
import SwiftyJSON

enum YoutubeAction: String {
  case add = "addVideo"
  case insert = "insertVideo"
  case remove = "removeVideo"
  case set = "setPlaylist"
  case clear = "clearPlaylist"
}

class YoutubeChannel: CastChannel {
  
  static let BIND_URL = URL(string: "https://www.youtube.com/api/lounge/bc/bind")!
  
  static let LOUNGE_TOKEN_URL = URL(string: "https://www.youtube.com/api/lounge/pairing/get_lounge_token_batch")!

  private var rid: Int = 0
  
  private var reqCount: Int = 0
  
  private var sid: Int = 0
  
  private var screenID: String = ""
  
  private var gsessionID: Int? = nil
  
  private var loungeToken: String? = nil

  init() {
    super.init(namespace: CastNamespace.youtube)
  }

  public func playVideo(_ videoID: String, playlistID: String? = nil) {
    fetchScreenIDIfNecessary { result in
      switch result {
      case .success:
        self.startSession()
        self.initializeQueue(videoID: videoID, playlistID: playlistID)
      case .failure(let error):
        print(error)
      }
    }
  }

  public func addToQueue(_ videoID: String) {
    fetchScreenIDIfNecessary { result in
      switch result {
      case .success:
        self.queueAction(.add, videoID)
      case .failure(let error):
        print(error)
      }
    }
  }

  public func playNext(_ videoID: String) {
    fetchScreenIDIfNecessary { result in
      switch result {
      case .success:
        self.queueAction(.insert, videoID)
      case .failure(let error):
        print(error)
      }
    }
  }

  public func removeVideo(_ videoID: String) {
    fetchScreenIDIfNecessary { result in
      switch result {
      case .success:
        self.queueAction(.remove, videoID)
      case .failure(let error):
        print(error)
      }
    }
  }

  public func clearPlaylist() {
    fetchScreenIDIfNecessary { result in
      switch result {
      case .success:
        self.queueAction(.clear)
      case .failure(let error):
        print(error)
      }
    }
  }

  private func startSession() {
    getLoungeID()
    bind()
  }

  /**
    Get the loungeToken

    The token is used as a header in all session requests
  */
  private func getLoungeID() {
    postRequest(YoutubeChannel.LOUNGE_TOKEN_URL, data: ["screen_ids": screenID]) { result in
      switch result {
      case .success(let response):
        // TODO: Traverse json response
        self.loungeToken = response.json()["screens"][0]["loungeToken"]
      case .failure(let error):
        // TODO: Handle error
        print(error)
      }
    }
  }

  /**
    Bind to the app and get SID, gsessionid session identifiers.

    If the chromecast is already in another YouTube session you should get
    the SID, gsessionid for that session.

    SID, gsessionid are used as url params in all further session requests.
   */
  private func bind() {
    rid = 0
    reqCount = 0

    let data: [String: Any] = [
      "device": "REMOTE_CONTROL",
      "id": "aaaaaaaaaaaaaaaaaaaaaaaaaa",
      "name": "OpenCastSwift",
      "mdx-version": 3,
      "pairing_type": "cast",
      "app": "android-phone-13.14.55"
    ]
    let headers: [String: Any] = [ "X-YouTube-LoungeId-Token": loungeToken ]
    let urlParams: [String: Any] = ["RID": rid, "VER": 8, "CVER": 1]
    postRequest(YoutubeChannel.BIND_URL, data: data, headers: headers, params: urlParams) {
      result in
      switch result {
      case .success(let response):
        var content = str(response.content)
        self.sid = re.search(SID_REGEX, content)
        self.gsessionID = re.search(GSESSION_ID_REGEX, content)
      case .failure(let error):
        // TODO: Handle error
        print(error)
      }
    }
  }

  /**
    Initialize a queue with a video and start playing that video.
  */
  private func initializeQueue(videoID: String, listID: String = "") {
    let data = formatSessionParams([
      "LIST_ID": listID,
      "ACTION": YoutubeAction.set.rawValue,
      "CURRENT_TIME": "0",
      "CURRENT_INDEX": -1,
      "AUDIO_ONLY": "false",
      "VIDEO_ID": videoID,
      "COUNT": 1,
    ])
    
    let headers: [String: Any] = [ "X-YouTube-LoungeId-Token": loungeToken ]

    let params = [
      "SID": sid,
      "GSESSIONID": gsessionID,
      "RID": rid,
      "VER": 8,
      "CVER": 1
    ]

    postRequest(
      YoutubeChannel.BIND_URL,
      data: data,
      headers: headers,
      params: params,
      sessionRequest: true
    )
  }

  /**
    Sends actions for an established queue.
  */
  private func queueAction(action: YoutubeAction, videoID: String = "") {
    // If nothing is playing actions will work but won"t affect the queue.
    // This is for binding existing sessions
    if inSession == false {
      startSession()
    } else {
      // There is a bug that causes session to get out of sync after about 30 seconds. Binding again works.
      // Binding for each session request has a pretty big performance impact
      bind()
    }

    let requestData = formatSessionParams([
      "ACTION": action,
      "VIDEO_ID": videoID,
      "COUNT": 1,
    ])

    let urlParams: [String: Any] = [
      "SID": sid,
      "GSESSIONID": gsessionID,
      "RID": rid,
      "VER": 8,
      "CVER": 1,
    ]
    
    let headers = [
      "X-YouTube-LoungeId-Token": loungeToken
    ]

    postRequest(BIND_URL, data: requestData, params: urlParams, headers: headers, sessionRequest: true)
  }
  
  private func postRequest(
    _ url: URL,
    data: [String: String],
    headers: [String: String]? = nil,
    params: [String: String]? = nil,
    sessionRequest: Bool = false
  ) {
    var request = MutableRequest(url: url)
    request.HTTPMethod = "POST"
    request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Origin")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    if let headers = headers {
      for (k, v) in headers {
        request.setValue(v, forHTTPHeaderField: k)
      }
    }
    
    let dataParts = data.map { (key, value) -> String in
      return "\(key)=\(self.percentEscapeString(value))"
    }

    request.httpBody = dataParts.joined(separator: "&").data(using: String.Encoding.utf8)
    
    let session = URLSession.shared
    session.dataTask(with: request) { (data, response, error) in
      // TODO: Handle error
      if let data = data {
        do {
          let json = try JSONSerialization.jsonObject(with: data, options: [])
          print(json)
        } catch {
          print(error)
        }
      }
    }.resume()
  }
  
  private var inSession: Bool {
    return (gsessionID != nil && loungeToken != nil)
  }
  
  private func percentEscapeString(string: String) -> String {
    var characterSet = CharacterSet.alphanumerics
    characterSet.insert(charactersIn: "-._* ")
    
    return string
      .addingPercentEncoding(withAllowedCharacters: characterSet)!
      .replacingOccurrences(of: " ", with: "+")
      .replacingOccurrences(of: " ", with: "+", options: [], range: nil)
  }

  private func formatSessionParams(_ params: [String: Any]) -> [String: Any] {
    var reqCount = "req\(self.reqCount)"
//    return {req_count + k if k.startswith("_") else k: v for k, v in param_dict.items()}
  }

  private func fetchScreenIDIfNecessary(for app: CastApp, completion: @escaping (Result<String, CastError>) -> Void) {
    if let screenID = screenID {
      completion(Result(success: screenID))
      return
    }

    let payload: [String: Any] = [
      CastJSONPayloadKeys.type: CastMessageType.getScreenID.rawValue,
      CastJSONPayloadKeys.sessionId: app.sessionId
    ]
    
    let request = requestDispatcher.request(
      withNamespace: namespace,
      destinationId: app.transportId,
      payload: payload
    )

    send(request) { result in
      switch result {
      case .success(let json):
        guard let screenId = json["data"]?["screenId"] else { return }
        self.screenID = screenId
        completion(Result(success: screenId))
      case .failure(let error):
        completion(Result(error: CastError.load(error.localizedDescription)))
      }
    }
  }
}
