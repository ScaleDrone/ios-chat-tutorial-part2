//
//  ChatService.swift
//  ScaledroneChatTest
//
//  Created by Marin Benčević on 08/09/2018.
//  Copyright © 2018 Scaledrone. All rights reserved.
//

import Foundation
import Scaledrone

extension Notification.Name {
  static let MembersChanged = Notification.Name("MembersChanged")
}

extension Member {
  init?(scaledroneMember: ScaledroneMember) {
    guard let data = scaledroneMember.clientData else {
      return nil
    }
    self.init(fromJSON: data)
  }
}

class ChatService {
  
  private let scaledrone: Scaledrone
  private let messageCallback: (Message)-> Void
  private let typingCallback: (Member, _ isTyping: Bool)-> Void
  
  private(set) var members: [Member] = [] {
    didSet {
      NotificationCenter.default.post(name: .MembersChanged, object: members)
    }
  }
  
  private var room: ScaledroneRoom?
  
  init(
    member: Member,
    onRecievedMessage: @escaping (Message)-> Void,
    onMemberTypingStatusChanged: @escaping (Member, _ isTyping: Bool)-> Void) {
    
    self.messageCallback = onRecievedMessage
    self.typingCallback = onMemberTypingStatusChanged
    self.scaledrone = Scaledrone(
      channelID: "YOUR-CHANNEL-ID",
      data: member.toJSON)
    scaledrone.delegate = self
  }
  
  func connect() {
    scaledrone.connect()
  }
  
  func sendMessage(_ message: String) {
    room?.publish(message: message)
  }
  
  func startTyping() {
    room?.publish(message: ["typing": true])
  }
  
  func stopTyping() {
    room?.publish(message: ["typing": false])
  }
  
}

extension ChatService: ScaledroneDelegate {
  
  func scaledroneDidConnect(scaledrone: Scaledrone, error: NSError?) {
    print("Connected to Scaledrone")
    room = scaledrone.subscribe(roomName: "observable-room")
    room?.delegate = self
    room?.observableDelegate = self
  }
  
  func scaledroneDidReceiveError(scaledrone: Scaledrone, error: NSError?) {
    print("Scaledrone error", error ?? "")
  }
  
  func scaledroneDidDisconnect(scaledrone: Scaledrone, error: NSError?) {
    print("Scaledrone disconnected", error ?? "")
  }
  
}

extension ChatService: ScaledroneRoomDelegate {
  
  func scaledroneRoomDidConnect(room: ScaledroneRoom, error: NSError?) {
    print("Connected to room!")
  }
  
  func scaledroneRoomDidReceiveMessage(
    room: ScaledroneRoom,
    message: Any,
    member: ScaledroneMember?) {
    
    guard
      let memberData = member?.clientData,
      let member = Member(fromJSON: memberData)
      else {
        print("Could not parse data.")
        return
    }
    
    if let typingData = message as? [String: Bool],
      let isTyping = typingData["typing"] {
      
      typingCallback(member, isTyping)
      
    } else if let text = message as? String {
      
      let message = Message(
        member: member,
        text: text,
        messageId: UUID().uuidString)
      messageCallback(message)
    }
  }
}

extension ChatService: ScaledroneObservableRoomDelegate {
  func scaledroneObservableRoomDidConnect(
    room: ScaledroneRoom,
    members: [ScaledroneMember]) {
    
    self.members = members.compactMap(Member.init)
  }
  
  func scaledroneObservableRoomMemberDidJoin(
    room: ScaledroneRoom,
    member: ScaledroneMember) {
    
    guard let newMember = Member(scaledroneMember: member) else {
      return
    }
    members.append(newMember)
  }
  
  func scaledroneObservableRoomMemberDidLeave(
    room: ScaledroneRoom,
    member: ScaledroneMember) {
    
    guard let leftMember = Member(scaledroneMember: member) else {
      return
    }
    
    if let index = members
      .firstIndex(where: { $0.name == leftMember.name }) {
      members.remove(at: index)
    }
  }
}


