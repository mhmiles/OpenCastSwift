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

public class YoutubeChannel: CastChannel {
  
  private static let YOUTUBE_BASE_URL = "https://www.youtube.com/"
  private static let BIND_URL = URL(string: "\(YOUTUBE_BASE_URL)api/lounge/bc/bind")!
  private static let LOUNGE_TOKEN_URL = URL(string: "\(YOUTUBE_BASE_URL)api/lounge/pairing/get_lounge_token_batch")!
  
  private let CURRENT_INDEX = "_currentIndex"
  private let CURRENT_TIME = "_currentTime"
  private let AUDIO_ONLY = "_audioOnly"
  private let VIDEO_ID = "_videoId"
  private let LIST_ID = "_listId"
  private let ACTION = "__sc"
  private let COUNT = "count"

  private let LOUNGE_ID_HEADER = "X-YouTube-LoungeId-Token"
  
  private let GSESSIONID = "gsessionid"
  private let CVER = "CVER"
  private let RID = "RID"
  private let SID = "SID"
  private let VER = "VER"

  /// Current request id
  private var rid: Int = 0
  
  /// Current number of requests performed
  private var reqCount: Int = 0
  
  private var sid: Int = 0
  
  // TODO: How to set the screenid without the initializer?
  private var screenID: String? = nil
  
  private var gsessionID: String = ""
  
  private var loungeToken: String = ""

  public init() {
    super.init(namespace: CastNamespace.youtube)
  }

  public func playVideo(for app: CastApp, videoID: String, playlistID: String? = nil) {
    fetchScreenIDIfNecessary(for: app) { result in
      switch result {
      case .success:
        self.startSession() {
          self.initializeQueue(videoID: videoID, playlistID: playlistID)
        }
      case .failure(let error):
        print(error)
      }
    }
  }

  public func addToQueue(for app: CastApp, videoID: String) {
    fetchScreenIDIfNecessary(for: app) { result in
      switch result {
      case .success:
        self.queueAction(.add, videoID: videoID)
      case .failure(let error):
        print(error)
      }
    }
  }

  public func playNext(for app: CastApp, videoID: String) {
    fetchScreenIDIfNecessary(for: app) { result in
      switch result {
      case .success:
        self.queueAction(.insert, videoID: videoID)
      case .failure(let error):
        print(error)
      }
    }
  }

  public func removeVideo(for app: CastApp,videoID: String) {
    fetchScreenIDIfNecessary(for: app) { result in
      switch result {
      case .success:
        self.queueAction(.remove, videoID: videoID)
      case .failure(let error):
        print(error)
      }
    }
  }

  public func clearPlaylist(for app: CastApp) {
    fetchScreenIDIfNecessary(for: app) { result in
      switch result {
      case .success:
        self.queueAction(.clear)
      case .failure(let error):
        print(error)
      }
    }
  }

  private func startSession(_ completion: @escaping () -> Void) {
    getLoungeID() {
      self.bind() {
        completion()
      }
    }
  }

  /**
    Get the loungeToken

    The token is used as a header in all session requests
  */
  private func getLoungeID(_ completion: @escaping () -> Void) {
    guard let screenID = screenID else { return }
    postRequest(YoutubeChannel.LOUNGE_TOKEN_URL, data: ["screen_ids": screenID]) {
      result in
      switch result {
      case .success(let response):
        // TODO: Traverse json response
//        self.loungeToken = response.json()["screens"][0]["loungeToken"]
        completion()
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
  private func bind(_ completion: @escaping () -> Void) {
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

    let headers: [String: String] = [ LOUNGE_ID_HEADER: loungeToken ]
    let urlParams: [String: String] = [ RID: "\(rid)", VER: "8", CVER: "1" ]

    postRequest(YoutubeChannel.BIND_URL, data: data, headers: headers, params: urlParams) { result in
      switch result {
      case .success(let response):
        // TODO: Implement the regex
//        var content = str(response.content)
//        self.sid = re.search(SID_REGEX, content)
//        self.gsessionID = re.search(GSESSION_ID_REGEX, content)
        completion()
      case .failure(let error):
        // TODO: Handle error
        print(error)
      }
    }
  }

  /**
    Initialize a queue with a video and start playing that video.
  */
  private func initializeQueue(videoID: String, playlistID: String?) {
    let data = formatSessionParams([
      LIST_ID: playlistID ?? "",
      ACTION: YoutubeAction.set.rawValue,
      CURRENT_TIME: "0",
      CURRENT_INDEX: -1,
      AUDIO_ONLY: "false",
      VIDEO_ID: videoID,
      COUNT: 1,
    ])
    
    let headers: [String: String] = [ LOUNGE_ID_HEADER: loungeToken ]

    let params: [String: String] = [
      SID: "\(sid)",
      GSESSIONID: gsessionID,
      RID: "\(rid)",
      VER: "8",
      CVER: "1"
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
  private func queueAction(_ action: YoutubeAction, videoID: String = "") {
    let performAction = {
      let requestData = self.formatSessionParams([
        self.ACTION: action,
        self.VIDEO_ID: videoID,
        self.COUNT: 1,
      ])
      
      let urlParams: [String: String] = [
        self.SID: "\(self.sid)",
        self.GSESSIONID: self.gsessionID,
        self.RID: "\(self.rid)",
        self.VER: "8",
        self.CVER: "1",
      ]
      
      let headers = [
        self.LOUNGE_ID_HEADER: self.loungeToken
      ]
      
      self.postRequest(
        YoutubeChannel.BIND_URL,
        data: requestData,
        headers: headers,
        params: urlParams,
        sessionRequest: true
      )
    }

    // If nothing is playing actions will work but won"t affect the queue.
    // This is for binding existing sessions
    if inSession == false {
      startSession() {
        performAction()
      }
    } else {
      // There is a bug that causes session to get out of sync after about 30 seconds. Binding again works.
      // Binding for each session request has a pretty big performance impact
      bind() {
        performAction()
      }
    }
  }
  
  private func postRequest(
    _ url: URL,
    data: [String: Any],
    headers: [String: String]? = nil,
    params: [String: String]? = nil,
    sessionRequest: Bool = false,
    completion: ((Result<Any, NSError>) -> Void)? = nil
  ) {
    var request: URLRequest

    if let params = params {
      let queryItems = params.map { (args) -> URLQueryItem in
        let (key, value) = args
        return URLQueryItem(name: key, value: value)
      }
      var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
      urlComponents?.queryItems = queryItems
      if let paramURL = urlComponents?.url {
        request = URLRequest(url: paramURL)
      } else {
        return
      }
    } else {
      request = URLRequest(url: url)
    }

    request.httpMethod = "POST"
    request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Origin")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    if let headers = headers {
      for (k, v) in headers {
        request.setValue(v, forHTTPHeaderField: k)
      }
    }
    
    let dataParts = data.map { (arg) -> String in
      let (key, value) = arg
      return "\(key)=\(self.percentEscapeString(value))"
    }
    request.httpBody = dataParts.joined(separator: "&").data(using: String.Encoding.utf8)
    
    let session = URLSession.shared
    session.dataTask(with: request) { (data, response, error) in
      guard error == nil && data != nil else {
        completion?(.failure(error! as NSError))
        return
      }

      guard let data = data else {
        return
      }

      do {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        print(json)
      } catch {
        print(error)
      }
    }.resume()
  }
  
  private var inSession: Bool {
    return (gsessionID != "" && loungeToken != "")
  }
  
  private func percentEscapeString(_ string: Any) -> String {
    var characterSet = CharacterSet.alphanumerics
    characterSet.insert(charactersIn: "-._* ")
    
    return "\(string)"
      .addingPercentEncoding(withAllowedCharacters: characterSet)!
      .replacingOccurrences(of: " ", with: "+")
      .replacingOccurrences(of: " ", with: "+", options: [], range: nil)
  }

  private func formatSessionParams(_ params: [String: Any]) -> [String: Any] {
    let reqCount = "req\(self.reqCount)"
    var ret = [String: Any]()
    for (key, value) in params {
      if (key.starts(with: "_")) {
        ret["\(reqCount)\(key)"] = value
      } else {
        ret[key] = value
      }
    }
    return ret
  }

  private func fetchScreenIDIfNecessary(for app: CastApp, completion: @escaping (Result<String, CastError>) -> Void) {
    if let screenID = screenID {
      completion(.success(screenID))
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
        print(json)
//        guard let screenID = json["data"]?["screenId"] else { return }
//        self.screenID = screenID
//        completion(Result(success: screenID))
      case .failure(let error):
        completion(Result(error: CastError.load(error.localizedDescription)))
      }
    }
  }
}
