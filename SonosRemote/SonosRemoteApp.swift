//
//  SonosRemoteApp.swift
//  SonosRemote
//
//  Created by Denis Blondeau on 2024-03-04.
//

import SwiftUI

@main
struct SonosRemoteApp: App {
    
    @State private var model = SonosModel()
    
    var body: some Scene {
        
        MenuBarExtra {
            VStack {
                
                Label("Current volume: \(model.currentVolume)", systemImage: "speaker")
                    .labelStyle(.titleAndIcon)
                
                Button {
                    model.sendKeypressToSonos(keypress: .KEY_PLAYPAUSE)
                } label: {
                    if model.playPauseState == .play {
                        Text("Pause Sonos Speaker(s)")
                    } else if model.playPauseState == .pause {
                        Text("Play Sonos Speaker(s)")
                    }
                   }
                    
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit Sonos Controller", systemImage: "xmark.circle.fill")
                    
                }
                .keyboardShortcut("q")
                
            }
            .background(.ultraThickMaterial)
            
        } label: {
            
            if model.playPauseState == .play {
                Image(systemName: "play.circle")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "pause.circle")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.red)
                
            }
            
            
        }
        
    }
}
