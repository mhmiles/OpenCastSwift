## OpenCastSwift: An open source implementation of the Google Cast SDK written in Swift

<!-- [![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) -->
![Swift 4.1](https://img.shields.io/badge/Swift-4.1-orange.svg) ![platforms](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey.svg)

This framework implements the Google Cast APIs so they can be used in macOS and iOS apps. Google provides an official SDK but it is only for iOS and closed source.

### OS support

I've tested this to work on macOS 10.12 and iOS 11. It may work on earlier versions, I just haven't tested it. Sample apps with some basic functionality are included for both macOS and iOS. The iOS app is more built-out with a working example of casting an audio stream.

This framework fails build for watchOS because watchOS does not support SSL over CFStream sockets. I've left the target in this project in hopes that support is added in a future version of watchOS 🤞🤞.

### Basic usage

### Finding Google Cast devices on the network

```swift
import OpenCastSwift

var scanner = CastDeviceScanner()

NotificationCenter.default.addObserver(forName: CastDeviceScanner.DeviceListDidChange, object: scanner, queue: nil) { [unowned self] _ in
	// self.scanner.devices contains the list of devices available
}

scanner.startScanning()
```

It's also possible to receive device list changes by setting the scanner's delegate.

### Connecting to a device

`CastClient` is the class used to establish a connection and sending requests to a specific device, you instantiate it with a `CastDevice` instance received from `CastDeviceScanner`.

```swift
import OpenCastSwift

var client = CastClient(device: scanner.devices.first!)
client.connect()
```

### Getting information about status changes

Implement the `CastClientDelegate` protocol to get information about the connection and the device's status:

```swift
protocol CastClientDelegate {    
    optional func castClient(_ client: CastClient, willConnectTo device: CastDevice)
    optional func castClient(_ client: CastClient, didConnectTo device: CastDevice)
    optional func castClient(_ client: CastClient, didDisconnectFrom device: CastDevice)
    optional func castClient(_ client: CastClient, connectionTo device: CastDevice, didFailWith error: NSError)

    optional func castClient(_ client: CastClient, deviceStatusDidChange status: CastStatus)
    optional func castClient(_ client: CastClient, mediaStatusDidChange status: CastMediaStatus)
}
```

### Launching an app

To launch an app on the device, you use the `launch` method on `CastClient`:

```swift
// appId is the unique identifier of the caster app to launch. The CastAppIdentifier struct contains the identifiers of the default generic media player, YouTube, and Google Assistant.

client.launch(appId: CastAppIdentifier.defaultMediaPlayer) { [weak self] result in
		switch result {
		case .success(let app):
	    // here you would probably call client.load() to load some media

		case .failure(let error):
			print(error)
		}

}
```

### Joining an app

To connect to an existing app session, you use the `join` method on `CastClient`:

// appId is the unique identifier of the caster app to join. A value of nil will cause the client to attempt to connect to the currently running app.

client.join() { [weak self] result in
		switch result {
		case .success(let app):
	    // here you would probably call client.load() to load some media

		case .failure(let error):
			print(error)
		}

}
```

### Loading media

After you have an instance of `CastApp`, you can tell the client to load some media with it using the `load` method:

```swift
let videoURL = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!
let posterURL = URL(string: "https://i.imgur.com/GPgh0AN.jpg")!

// create a CastMedia object to hold media information
let media = CastMedia(title: "Test Bars",
						url: videoURL,
						poster: posterURL,
						contentType: "application/vnd.apple.mpegurl",
						streamType: CastMediaStreamType.buffered,
						autoplay: true,
						currentTime: 0)

// app is the instance of the app you got from the client after calling launch, or from the status callbacks
client.load(media: media, with: app) { result in
          switch result {
          case .success(let status):
            print(status)

          case .failure(let error):
            print(error)
          }
    }

    // this media has been successfully loaded, status contains the initial status for this media
	// you can now call requestMediaStatus periodically to get updated media status
}
```

### Getting media status periodically

After you start streaming some media, you will probably want to get updated status every second, to update the UI. You should call the method `requestMediaStatus` on `CastClient`, this sends a request to the device to get the most recent media status.

```swift

func updateStatus() {
	// app is a CastApp instance you got after launching the app

	client.requestMediaStatus(for: app) { result in
      switch result {
      case .success(let status):
        print(status)

      case .failure(let error):
        print(error)
      }
	}
}

```

### Implemented features

* Discover cast devices on the local network
* Launch, join, leave, and quit cast applications
* Playback and volume controls for both devices and groups
* Custom channels via subclassing CastChannel
* Send and receive binary payloads

There is even some stubbed out functionality for undocumented features like device setup, certificate validation, and renaming. Contributions are always appreciated. 😄

### Apps that use OpenCastSwift

* [CastSync](https://itunes.apple.com/us/app/castsync/id1334278434?mt=12) - A macOS menu bar app for syncing playback from your Google Cast device to iTunes or VLC on your computer

### Thanks

* This project was originally forked from [ChromeCastCore](https://github.com/insidegui/ChromeCastCore)
* The name and some functionality were inspired by [OpenCast](https://github.com/acj/OpenCast)
* Additional thanks to [PyChromecast](https://github.com/balloob/pychromecast) and [node-castv2-client](https://github.com/thibauts/node-castv2-client) for helping me to work out the Cast protocol
