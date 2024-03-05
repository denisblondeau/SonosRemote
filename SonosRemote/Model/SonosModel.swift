//
//  SonosModel.swift
//  TestSocket
//
//  Created by Denis Blondeau on 2023-12-20.
//

import AppKit
import Combine
import Foundation
import SonosAPI


@Observable final class SonosModel {
    
    private(set) var playPauseState = AVTransportAction.pause
    private(set) var batterryPercentage = 0
    private(set) var currentVolume = 0
    
    // MARK: - Set the callback URL to the URL of the computer running this application. Default port is 1337 - or use another available port on your computer.
    private var callbackURL = URL(string: "http://192.168.0.1:1337")
    // MARK: - Set the coordinator's name to the name of the Sonos Room you wish to control.
    private var coordinatorName = "Living Room"
    // MARK: - Set the Server URL to the Pi server hosting the SocketIO application that is receiving then forwarding the bluetooth remote's keypress to this application.
    private var serverURL = URL(string: "http://piserver.local:8080")

    private var coordinatorURL: URL?
    private var subscriptions: Set<AnyCancellable> = []
    private var temporarySubscription: AnyCancellable?
    private var socketIOModel: SocketIOModel?
  
    
    init() {
        
        // Clean-up when app terminates.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            self.temporarySubscription?.cancel()
            self.subscriptions.removeAll()
        }
        
        getDevices()
    }
    
    /// Retrieve Sonos devices on the local network.
    private func getDevices() {
        
        let ssdp = SSDPSession()
        var sonosDevices = [SonosDevice]()
        
        temporarySubscription = ssdp.onDeviceFound.sink { completion in
            
            self.temporarySubscription?.cancel()
            
            switch completion {
                
            case .failure(let error):
                fatalError(error.description)
                
            case .finished:
                // Once we have the Sonos devices, find out the groups (zones) coordinators.
                self.retrieveHouseholdCoordinators(for: sonosDevices)
            }
        } receiveValue: { record in
            sonosDevices.append(record)
        }
        
        do {
            try ssdp.run()
        } catch {
            fatalError("Cannot run SSDP session: \(error.localizedDescription)")
        }
    }
    
    /// Retrieve  zone/household groups with their  corrdinator id.
    /// - Parameter sonosDevices: Sonos devices.
    private func retrieveHouseholdCoordinators(for sonosDevices: [SonosDevice]) {
        
        guard sonosDevices.count > 0 else { return }
        guard let url = sonosDevices[0].hostURL else { return }
        
        var groups = [SonosGroup]()
        
        let session = SOAPActionSession(service: .zoneGroupTopology(action: .getZoneGroupState, url: url))
        
        temporarySubscription = session.onDataReceived.sink { completion in
            
            self.temporarySubscription?.cancel()
            
            switch completion {
                
            case .finished:
                break
                
            case .failure(let error):
                fatalError(error.description)
            }
            
        } receiveValue: { json in
            
            parseJSONToObject(json: json) { (groupData: ZoneGroupTopology?) in
                
                guard let groupData else { return }
                
                for zoneGroup in groupData.zoneGroupState.zoneGroups.zoneGroup {
                    for zoneGroupMember in zoneGroup.zoneGroupMember {
                        
                        if zoneGroupMember.uuid == zoneGroup.coordinator {
                            var name: String
                            if zoneGroup.zoneGroupMember.count == 1 {
                                name = zoneGroupMember.zoneName
                            } else {
                                name = "\(zoneGroupMember.zoneName) + \(zoneGroup.zoneGroupMember.count - 1)"
                            }
                            
                            let  group = SonosGroup(id: zoneGroupMember.uuid, coordinatorURL: zoneGroupMember.hostURL!, name: name)
                            groups.append(group)
                        }
                    }
                }
                
                groups.sort { $0.name < $1.name }
                let group = groups.first (where: { $0.name == self.coordinatorName })
                if let group {
                    self.coordinatorURL = group.coordinatorURL
                    self.listenToAVTransportEvents()
                    self.processKeypress()
                    
                } else {
                    fatalError("Sonos Group \(self.coordinatorName) cannot be found.")
                }
            }
        }
        session.run()
    }
    
    /// Process keypress received from remote.
    private func processKeypress() {
        
        guard let serverURL else {
            fatalError("Invalid server URL.")
        }
        
        socketIOModel = SocketIOModel(serverURL: serverURL)
        
        // Receive notification that a key has been pressed on the Bluetooth remote.
        socketIOModel?.onDataReceived.sink { completion in
            
            switch completion {
                
            case .finished:
                break
            case .failure(let error):
                
                fatalError("Error in Socket IO: \(error.localizedDescription)")
            }
            
        } receiveValue: { keypress in
            
            self.sendKeypressToSonos(keypress: keypress)
            
        }
        .store(in: &subscriptions)
    }
    
    /// Send keypress received from remote to Sonos coordinator..
    /// - Parameters:
    ///   - keypress: Remote keypress.
    func sendKeypressToSonos(keypress: RemoteKey)   {
        
        guard let coordinatorURL else { fatalError("Coordinator URL is not set.") }
        
        var action: AVTransportAction!
        var session: SOAPActionSession!
        
        switch keypress {
            
        case .KEY_PLAYPAUSE:
            
            if playPauseState == .play {
                action = .pause
            } else {
                action = .play
            }
            
        case .KEY_VOLUMEDOWN:
            
            session = SOAPActionSession(service: .groupRenderingControl(action: .setRelativeGroupVolume, url: coordinatorURL, adjustment: -2))
            
        case .KEY_VOLUMEUP:
            
            session = SOAPActionSession(service: .groupRenderingControl(action: .setRelativeGroupVolume, url: coordinatorURL, adjustment: 2))
            
        case .KEY_PREVIOUSSONG:
            
            action = .previous
            
        case .KEY_NEXTSONG:
            
            action = .next
        }
        
        if session  == nil {
            session = SOAPActionSession(service: .avTransport(action: action, url: coordinatorURL))
        }
        
        temporarySubscription = session.onDataReceived.sink { completion in
            
            self.temporarySubscription?.cancel()
            
            switch completion {
                
            case .finished:
                break
            case .failure(let error):
                print("**** Error in \(#function) : \(error.description) *****")
            }
            
            // VolumeUp and VolumeDown are the two actions that can generate a value (new volume setting).
        } receiveValue: { jsonData in
            parseJSONToObject(json: jsonData) { (newVolume:  NewVolume?) in
                if let newVolume {
                    self.currentVolume = newVolume.volume
                }
            }
        }
        session.run()
    }
    
    /// Listen to Sonos AV Transport Events.
    private func listenToAVTransportEvents() {
        
        guard let coordinatorURL else { fatalError("Coordinator URL is not set.") }
        
        guard let callbackURL else {
            fatalError("Invalid callback URL.")
        }
        
        let eventSession = SOAPEventSession(callbackURL: callbackURL)
        
        eventSession.onDataReceived.sink { completion in
            
            switch completion {
                
            case .finished:
                print("\(#function): Finished?")
                break
            case .failure(let error):
                print("At \(Date().formatted())")
                print("**** Error in \(#function) : \(error.description) *****")
            }
            
        } receiveValue: { jsonData in
            
            switch jsonData.sonosService {
                
            case .avTransport:
                
                parseJSONToObject(json: jsonData.json) { (avTransport: AVTransport?) in
                    
                    guard let avTransport else { return }
                    
                    if avTransport.transportState == .playing {
                        
                        self.playPauseState = .play
                        
                    } else {
                        
                        if avTransport.transportState == .stopped || avTransport.transportState == .pausedPlayback {
                            
                            self.playPauseState = .pause
                        }
                        return
                    }
                
                }
                
            case .groupRenderingControl:
                parseJSONToObject(json: jsonData.json) { (groupRenderingControl: GroupRenderingControl?) in
                    
                    if let groupRenderingControl {
                        self.currentVolume = groupRenderingControl.groupVolume
                    }
                }
                
            default:
                break
            }
            
        }
        .store(in: &subscriptions)
        
        Task {
            await eventSession.subscribeToEvents(events: [.subscription(service: .avTransport), .subscription(service: .groupRenderingControl)], hostURL: coordinatorURL)
        }
        
    }
    
}

