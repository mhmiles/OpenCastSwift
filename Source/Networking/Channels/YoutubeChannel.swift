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

class YoutubeChannel: CastChannel {
  private var delegate: YoutubeChannelDelegate? {
    return requestDispatcher as? YoutubeChannelDelegate
  }
  
  init() {
    super.init(namespace: CastNamespace.youtube)
  }

  public func playVideo(_ videoID: String, playlistID: String? = nil) {
    startSession()
    initializeQueue(videoID, playlistID)
  }

  public func addToQueue(_ videoID: String) {
    queueAction(videoID, "addVideo")
  }

  public func playNext(_ videoID: String) {
    queueAction(videoID, "insertVideo")
  }

  public func removeVideo(_ videoID: String) {
    queueAction(videoID, "removeVideo")
  }

  public func clearPlaylist() {
    queueAction("", "clearPlaylist")
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
    let url = NSURL(string: "https://www.youtube.com/api/lounge/pairing/get_lounge_token_batch")!

    let parameterDictionary = ["screen_ids": screenID]

    var request = MutableRequest(url: url)
    request.HTTPMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    guard let httpBody = try? JSONSerialization.data(withJSONObject: params, options: []) else {
      return
    }
    request.httpBody = httpBody

    let session = URLSession.shared
    session.dataTask(with: request) { (data, response, error) in
      if let response = response {
        print(response)
      }
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

  /**
    Bind to the app and get SID, gsessionid session identifiers.

    If the chromecast is already in another YouTube session you should get
    the SID, gsessionid for that session.

    SID, gsessionid are used as url params in all further session requests.
   */
  private func bind() {
    rid = 0
    reqCount = 0

    url_params = {RID: self._rid, VER: 8, CVER: 1}
    headers = {LOUNGE_ID_HEADER: self._lounge_token}
    response = self._do_post(BIND_URL, data=BIND_DATA, headers=headers,
                              params=url_params)
    content = str(response.content)
    sid = re.search(SID_REGEX, content)
    gsessionid = re.search(GSESSION_ID_REGEX, content)
    self._sid = sid.group(1)
    self._gsession_id = gsessionid.group(1)
  }

  /**
    Initialize a queue with a video and start playing that video.
  */
  private func initializeQueue(_ videoID: String, listId: String = "") {
    request_data = {LIST_ID: list_id,
                ACTION: ACTION_SET_PLAYLIST,
                CURRENT_TIME: "0",
                CURRENT_INDEX: -1,
                AUDIO_ONLY: "false",
                VIDEO_ID: video_id,
                COUNT: 1, }

    request_data = self._format_session_params(request_data)
    url_params = {SID: self._sid, GSESSIONID: self._gsession_id,
                  RID: self._rid, VER: 8, CVER: 1}
    self._do_post(BIND_URL, data=request_data, headers={LOUNGE_ID_HEADER: self._lounge_token},
                  session_request=True, params=url_params)
  }

  /**
    Sends actions for an established queue.
  */
  private func queueAction(videoID: String, action: String) {
        # If nothing is playing actions will work but won"t affect the queue.
        # This is for binding existing sessions
        if not self.in_session:
            self._start_session()
        else:
            # There is a bug that causes session to get out of sync after about 30 seconds. Binding again works.
            # Binding for each session request has a pretty big performance impact
            self._bind()

        request_data = {ACTION: action,
                        VIDEO_ID: video_id,
                        COUNT: 1}

        request_data = self._format_session_params(request_data)
        url_params = {SID: self._sid, GSESSIONID: self._gsession_id, RID: self._rid, VER: 8, CVER: 1}
        self._do_post(BIND_URL, data=request_data, headers={LOUNGE_ID_HEADER: self._lounge_token},
                      session_request=True, params=url_params)
  }
  
  override func handleResponse(_ json: JSON, sourceId: String) {
    guard let rawType = json["type"].string else { return }
    
    guard let type = CastMessageType(rawValue: rawType) else {
      print("Unknown type: \(rawType)")
      print(json)
      return
    }
    
    switch type {
    case .mdxSessionStatus:
      // TODO: Check that this is getting the screenId from the response payload
      guard let screenId = json["data"]?["screenId"] else { return }
      delegate?.channel(self, didRecieve: )
    default:
      print(rawType)
    }
  }
  
  public func requestMediaStatus(for app: CastApp, completion: ((Result<CastMediaStatus, CastError>) -> Void)? = nil) {
    let payload: [String: Any] = [
      CastJSONPayloadKeys.type: CastMessageType.statusRequest.rawValue,
      CastJSONPayloadKeys.sessionId: app.sessionId
    ]
    
    let request = requestDispatcher.request(withNamespace: namespace,
                                       destinationId: app.transportId,
                                       payload: payload)
    
    if let completion = completion {
      send(request) { result in
        switch result {
        case .success(let json):
          completion(Result(value: CastMediaStatus(json: json)))
          
        case .failure(let error):
          completion(Result(error: error))
        }
      }
    } else {
      send(request)
    }
  }
  
  public func sendPause(for app: CastApp, mediaSessionId: Int) {
    send(.pause, for: app, mediaSessionId: mediaSessionId)
  }
  
  public func sendPlay(for app: CastApp, mediaSessionId: Int) {
    send(.play, for: app, mediaSessionId: mediaSessionId)
  }
  
  public func sendStop(for app: CastApp, mediaSessionId: Int) {
    send(.stop, for: app, mediaSessionId: mediaSessionId)
  }
  
  public func sendSeek(to currentTime: Float, for app: CastApp, mediaSessionId: Int) {
    let payload: [String: Any] = [
      CastJSONPayloadKeys.type: CastMessageType.seek.rawValue,
      CastJSONPayloadKeys.sessionId: app.sessionId,
      CastJSONPayloadKeys.currentTime: currentTime,
      CastJSONPayloadKeys.mediaSessionId: mediaSessionId
    ]
    
    let request = requestDispatcher.request(withNamespace: namespace,
                                 destinationId: app.transportId,
                                 payload: payload)
    
    send(request)
  }
  
  private func send(_ message: CastMessageType, for app: CastApp, mediaSessionId: Int) {
    let payload: [String: Any] = [
      CastJSONPayloadKeys.type: message.rawValue,
      CastJSONPayloadKeys.mediaSessionId: mediaSessionId
    ]
    
    let request = requestDispatcher.request(withNamespace: namespace,
                                 destinationId: app.transportId,
                                 payload: payload)
    
    send(request)
  }
  
  public func load(media: CastMedia, with app: CastApp, completion: @escaping (Result<CastMediaStatus, CastError>) -> Void) {
    var payload = media.dict
    payload[CastJSONPayloadKeys.type] = CastMessageType.load.rawValue
    payload[CastJSONPayloadKeys.sessionId] = app.sessionId
    
    let request = requestDispatcher.request(withNamespace: namespace,
                                       destinationId: app.transportId,
                                       payload: payload)

    send(request) { result in
      switch result {
      case .success(let json):
        guard let status = json["status"].array?.first else { return }
        
        completion(Result(value: CastMediaStatus(json: status)))
        
      case .failure(let error):
        completion(Result(error: CastError.load(error.localizedDescription)))
      }
    }
  }

  private func startSessionIfNecessary(for app: CastApp, completion: @escaping (Result<CastMediaStatus, CastError>) -> Void) {
    let payload: [String: Any] = [
      CastJSONPayloadKeys.type: CastMessageType.getScreenID.rawValue,
      CastJSONPayloadKeys.sessionId: app.sessionId
    ]
    
    let request = requestDispatcher.request(withNamespace: namespace,
                                 destinationId: app.transportId,
                                 payload: payload)

    send(request) { result in
      switch result {
      case .success(let json):
        guard let screenId = json["data"]?["screenId"] else { return }
      case .failure(let error):
        completion(Result(error: CastError.load(error.localizedDescription)))
      }
    }
  }
}

protocol YoutubeChannelDelegate: class {
  func channel(_ channel: YoutubeChannel, didReceive mediaStatus: CastMediaStatus)
}
