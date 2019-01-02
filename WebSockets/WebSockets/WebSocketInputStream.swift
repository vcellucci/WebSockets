//
//  WebSocketInputStream.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/25/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
public class WebSocketInputStream {
    public var didReceiveFragment : ((Array<UInt8>)->())?
    public var didClose : ((Array<UInt8>)->())?
    public var isBinary = false
}
