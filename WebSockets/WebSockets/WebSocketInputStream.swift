//
//  WebSocketInputStream.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/25/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
public protocol WebSocketInputStream {
    var didReceiveFragment : ((ArraySlice<UInt8>)->())? { get set }
    var didClose : ((ArraySlice<UInt8>)->())? { get set }
    var isBinary : Bool { get }
}
