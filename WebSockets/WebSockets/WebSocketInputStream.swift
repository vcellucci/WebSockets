//
//  WebSocketInputStream.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/25/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
public class WebSocketInputStream {
    public var didReceiveFragment : ((ArraySlice<UInt8>)->())?
    public var didClose : (()->())?
    public var isBinary = false
}
