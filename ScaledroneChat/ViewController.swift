//
//  ViewController.swift
//  ScaledroneChatTest
//
//  Created by Marin Benčević on 08/09/2018.
//  Copyright © 2018 Scaledrone. All rights reserved.
//

import UIKit
import MessageKit

class ViewController: MessagesViewController {

  var chatService: ChatService!
  var messages: [Message] = []
  var member: Member!
  var members: [Member] = []
  
  var typingMembers: [Member] = [] {
    didSet {
      let otherMembers = typingMembers.filter { $0.name != member.name }
      switch otherMembers.count {
      case 0:
        hideTypingLabel()
      case 1:
        typingLabel.text = "\(otherMembers[0].name) is typing"
        showTypingLabel()
      default:
        let names = otherMembers.map { $0.name }.joined(separator: ", ")
        typingLabel.text = "\(names) are typing"
        showTypingLabel()
      }
    }
  }
  
  lazy var typingLabel: UILabel = {
    let label = UILabel()
    label.text = ""
    label.textAlignment = .center
    label.backgroundColor = messageInputBar.backgroundView.backgroundColor!
    return label
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    messageInputBar.topStackView.addArrangedSubview(typingLabel)
    
    let item = UIBarButtonItem(
      title: "0",
      style: .plain,
      target: self,
      action: #selector(didTapMembersButton))
    navigationItem.setRightBarButton(item, animated: false)
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(membersChanged),
      name: .MembersChanged,
      object: nil)
    
    member = Member(name: .randomName, color: .random)
    messagesCollectionView.messagesDataSource = self
    messagesCollectionView.messagesLayoutDelegate = self
    messageInputBar.delegate = self
    messagesCollectionView.messagesDisplayDelegate = self
    
    chatService = ChatService(
      member: member,
      onRecievedMessage: {
        [weak self] message in
        self?.messages.append(message)
        self?.messagesCollectionView.reloadData()
        self?.messagesCollectionView.scrollToBottom(animated: true)
      },
      onMemberTypingStatusChanged: { [weak self] (member, isTyping) in
        guard let `self` = self else { return }
        if isTyping {
          if !self.typingMembers.contains { $0.name == member.name } {
            self.typingMembers.append(member)
          }
        } else {
          if let index = self.typingMembers
            .firstIndex(where: { $0.name == member.name }) {
            self.typingMembers.remove(at: index)
          }
        }
    })

    
    chatService.connect()
  }
  
  func showTypingLabel() {
    UIView.animate(withDuration: 0.3) {
      self.typingLabel.isHidden = false
    }
  }
  
  func hideTypingLabel() {
    UIView.animate(withDuration: 0.3) {
      self.typingLabel.isHidden = true
    }
  }
  
  @objc func didTapMembersButton() {
    let vc = MembersViewController()
    vc.members = self.members
    navigationController?.pushViewController(vc, animated: true)
  }
  
  @objc func membersChanged(notification: Notification) {
    guard let newMembers = notification.object as? [Member] else {
      return
    }
    
    self.members = newMembers
    navigationItem.rightBarButtonItem?.title = "\(newMembers.count)"
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }


}

extension ViewController: MessagesDataSource {
  func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
    return messages.count
  }
  
  func currentSender() -> Sender {
    return Sender(id: member.name, displayName: member.name)
  }
  
  func messageForItem(at indexPath: IndexPath,
                      in messagesCollectionView: MessagesCollectionView) -> MessageType {
    
    return messages[indexPath.section]
  }
  
  func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    return 12
  }
  
  func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
    return NSAttributedString(
      string: message.sender.displayName,
      attributes: [.font: UIFont.systemFont(ofSize: 12)])
  }
}

extension ViewController: MessagesLayoutDelegate {
  func heightForLocation(message: MessageType,
                         at indexPath: IndexPath,
                         with maxWidth: CGFloat,
                         in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    return 0
  }
}

extension ViewController: MessagesDisplayDelegate {
  func configureAvatarView(
    _ avatarView: AvatarView,
    for message: MessageType,
    at indexPath: IndexPath,
    in messagesCollectionView: MessagesCollectionView) {
    
    let message = messages[indexPath.section]
    let color = message.member.color
    avatarView.backgroundColor = color
  }
}

extension ViewController: MessageInputBarDelegate {
  func messageInputBar(
    _ inputBar: MessageInputBar,
    didPressSendButtonWith text: String) {
    
    chatService.sendMessage(text)
    inputBar.inputTextView.text = ""
    chatService.stopTyping()
  }
  
  func messageInputBar(_ inputBar: MessageInputBar, textViewTextDidChangeTo text: String) {
    if text.isEmpty {
      chatService.stopTyping()
    } else {
      chatService.startTyping()
    }
  }
}

