<div align="center">

  <h1>SonosRemote</h1>
  
  <p>
    This Swift/SwiftUI (MacOS) demo receives keypresses from a bluetooth remote connected to a Raspberry Pi server and forwards those commands, using unsupported (i.e. unofficial) Sonos API requests, to a Sonos controller (i.e. Sonos speakers). 

  </p>
  
<p>
  
  ![Static Badge](https://img.shields.io/badge/macOS-14%2B-greeen)
  ![Static Badge](https://img.shields.io/badge/Xcode-15%2B-blue)

</p>
</div>

## About the Project

This demo:

- Connects to a specific Sonos controller on the local network.
- Sends the following commands to the Sonos controller: Play/Pause, Previous Track, Next Track, Volume Up, Volume Down.
- Those commands are received from a bluetooth remote connected to a Raspberry Pi running a Socket IO server (Python application).
- Displays a MacOS menu bar application that let you play/pause the Sonos controller. The menu bar application also displays current play/pause status as well as current Sonos volume level (see MenuBarApp.jpeg).
- Subscribes to Sonos events (e.g. monitors play/pause state, volume level).

### Prerequisites

- Before building/running this application:
 - Install the latest release of the SonosAPI package: https://github.com/denisblondeau/SonosAPI
 - Install the Socket.IO-Client-Swift package: https://github.com/socketio/socket.io-client-swift
 - Install and run the Python keypress-server on a Raspberry Pi: https://github.com/denisblondeau/keypress-server

- In SonosModel.swift, you need to:
 - Set the callback URL. The callback URL is used by the Sonos coordinator to notify this demo of specific events.
 - Set the coodinator's name. This is the name of the Sonos Room you wish to control. You can find that name in the Sonos application.
 - Set the server URL. This is the Pi server hosting the SocketIO application that is receiving then forwarding the bluetooth remote's keypress to this application.

```bash
    private var callbackURL = URL(string: "http://192.168.0.1:1337")
    private var coordinatorName = "Living Room"
    private var serverURL = URL(string: "http://piserver.local:8080")
```

### Testing

Once you have launched this application:

    1) Select a Sonos group in the demo.
    2) Launch the Sonos application on your mobile device and select the same group that you selected in the demo.
    3) Changing the volume in the Sonos application on your mobile device will automatically adjust the volume in the demo application.


