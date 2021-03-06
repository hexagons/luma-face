//
//  Peer.swift
//  Pixel Nodes
//
//  Created by Hexagons on 2018-01-03.
//  Copyright © 2018 Hexagons. All rights reserved.
//

import UIKit
import MultipeerConnectivity

enum PeerState {
    case dissconnected
    case connecting
    case connected
}

class Peer: NSObject, MCSessionDelegate, MCBrowserViewControllerDelegate {
    
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcAdvertiserAssistant: MCAdvertiserAssistant!
    
    var sendCallback: (() -> ())?
    
    let gotMsg: ((String) -> ())?
    let gotImg: ((UIImage) -> ())?
    let peer: (PeerState, String) -> ()
    let disconnect: (() -> ())?
    
    init(gotMsg: ((String) -> ())? = nil, gotImg: ((UIImage) -> ())? = nil, peer: @escaping (PeerState, String) -> (), disconnect: (() -> ())? = nil) {
        
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        
        self.gotMsg = gotMsg
        self.gotImg = gotImg
        self.peer = peer
        self.disconnect = disconnect
        
        super.init()

        self.mcSession.delegate = self
        
    }
    
    func startHosting() {
        self.mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "peer-io", discoveryInfo: nil, session: mcSession)
        self.mcAdvertiserAssistant.start()
    }
    
    func joinSession() {
        let mcBrowser = MCBrowserViewController(serviceType: "peer-io", session: mcSession)
        mcBrowser.delegate = self
        guard let vc = UIApplication.shared.keyWindow?.rootViewController else {
            print("Can't join stream session. No View Controller found.")
            return
        }
        vc.present(mcBrowser, animated: true)
    }
    
    func sendImg(img: UIImage, quality: CGFloat) {
        if !self.mcSession.connectedPeers.isEmpty {
            if let imageData = img.jpegData(compressionQuality: quality) {
                do {
                    try self.mcSession.send(imageData, toPeers: self.mcSession.connectedPeers, with: .reliable)
                } catch let error as NSError {
                    print("StreamPeer: Send Img.", error)
                }
            }
        }
    }
    
    func sendMsg(_ message: String) {
        if !mcSession.connectedPeers.isEmpty {
            do {
                try mcSession.send("msg:\(message)".data(using: .utf8)!, toPeers: mcSession.connectedPeers, with: .reliable)
            } catch let error as NSError {
                print("StreamPeer: Send Msg.", error)
            }
        }
    }
    
    func sendDisconnect() {
        do {
            try mcSession.send("disconnect".data(using: .utf8)!, toPeers: mcSession.connectedPeers, with: .reliable)
        } catch let error as NSError {
            print("StreamPeer: Send dissconnect.", error)
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.peer(.connected, peerID.displayName)
            case .connecting:
                self.peer(.connecting, peerID.displayName)
            case .notConnected:
                self.peer(.dissconnected, peerID.displayName)
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let image = UIImage(data: data) {
            if self.gotImg != nil {
                DispatchQueue.main.async {
                    self.gotImg!(image)
                }
            }
        } else if let msg = String(data: data, encoding: .utf8) {
            if msg.starts(with: "msg:") {
                let message = msg.replacingOccurrences(of: "msg:", with: "")
                DispatchQueue.main.async {
                    self.gotMsg!(message)
                }
            } else if msg == "checked" {
                self.sendCallback?()
                self.sendCallback = nil
            } else if msg == "disconnect" {
                if self.disconnect != nil {
                    DispatchQueue.main.async {
                        self.disconnect!()
                    }
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true, completion: nil)
    }
    
}
