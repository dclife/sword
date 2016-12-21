import Foundation
import WebSockets

class Shard {

  let id: Int
  let shardCount: Int
  var sessionId: String?
  var heartbeat: Heartbeat?

  var session: WebSocket?
  let sword: Sword

  var lastSeq: Int?

  init(_ sword: Sword, _ id: Int, _ shardCount: Int) {
    self.sword = sword
    self.id = id
    self.shardCount = shardCount
  }

  func startWS(_ gatewayUrl: String) {
    try? WebSocket.connect(to: gatewayUrl) { ws in
      self.session = ws

      ws.onText = { ws, text in
        self.event(Payload(with: text))
      }

      ws.onClose = { ws, _, _, _ in
        print("WS Closed")
      }
    }
  }

  func send(_ text: String) {
    try? self.session!.send(text)
  }

  func identify() {
    #if os(macOS)
    let os = "macOS"
    #else
    let os = "Linux"
    #endif
    let identity = Payload(op: .identify, data: ["token": self.sword.token, "properties": ["$os": os, "$browser": "Sword", "$device": "Sword"], "compress": false, "large_threshold": 50, "shard": [self.id, self.shardCount]]).encode()

    try? self.session?.send(identity)
  }

  func event(_ payload: Payload) {
    if let sequenceNumber = payload.s {
      self.heartbeat?.sequence = sequenceNumber
      self.lastSeq = sequenceNumber
    }

    guard payload.t != nil else {
      self.handleGateway(payload)
      return
    }

    self.handleEvents(payload, payload.t!)
  }

}
