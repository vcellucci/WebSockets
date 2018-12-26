//
//  WebSocketsTests.swift
//  WebSocketsTests
//
//  Created by Vittorio Cellucci on 12/19/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import XCTest
@testable import WebSockets

class WebSocketsTests: XCTestCase {
    
    static let maxSize : Int = ((1024*64)+16)
    var webSocketFrame = UnsafeMutablePointer<UInt8>.allocate(capacity: maxSize)

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSimpleTextFrameParse() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // simple frame
        
        let webSockUtils = WebSocketStateUtils()
        var receivedMessage = ""
        webSockUtils.didReceiveMessage = {
            (message) in
            receivedMessage = message
        }
        
        let expectedMessage = "Hello!"
        webSocketFrame[0] = 0x81
        webSocketFrame[1] = UInt8(expectedMessage.count)
        let data : [UInt8] = [UInt8](expectedMessage.utf8)
        for index in 0...data.count-1 {
            webSocketFrame[2+index] = data[index]
        }
        
        let webSocketFrameParser = WebSocketFrameParser()
        webSocketFrameParser.webSockStateUtils = webSockUtils
        let processed = webSocketFrameParser.parse(buffer: webSocketFrame, size: 8)
        XCTAssertEqual(processed, 8)
        XCTAssertEqual(receivedMessage, expectedMessage)
    }
    
    func testMultipleSimpleTextFrames() {
        
        let webSockUtils = WebSocketStateUtils()
        let expected1 = "Hello!"
        let expected2 = "How are you?"
        
        webSocketFrame[0] = 0x81
        webSocketFrame[1] = UInt8(expected1.count)
        
        let data1 = [UInt8](expected1.utf8)
        for index in 0...data1.count-1 {
            webSocketFrame[2+index] = data1[index]
        }
        
        webSocketFrame[8] = 0x81
        webSocketFrame[9] = UInt8(expected2.count)
        
        let data2 = [UInt8](expected2.utf8)
        for index in 0...data2.count-1 {
            webSocketFrame[10+index] = data2[index]
        }
        
        let expectedProcessed1 = expected1.count + 2
        let expectedProcessed2 = expected2.count + 2
        let webSocketFrameParser = WebSocketFrameParser()
        webSocketFrameParser.webSockStateUtils = webSockUtils
        var processed = webSocketFrameParser.parse(buffer: webSocketFrame, size: expectedProcessed1 + expectedProcessed2)
        XCTAssertEqual(processed, expectedProcessed1)
        
        var receivedMessage = ""
        webSockUtils.didReceiveMessage = {
            (message) in
            receivedMessage = message
        }
        
        let nextBuffer = webSocketFrame.advanced(by: expectedProcessed1)
        processed = webSocketFrameParser.parse(buffer: nextBuffer, size: expectedProcessed2)
        XCTAssertEqual(processed, expectedProcessed2)
        XCTAssertEqual(receivedMessage, expected2)
    }
    
    func testUnderflowSimpleTextFrame() {
        let webSockUtils = WebSocketStateUtils()
        let expectedMessage = "Hello!"
        
        webSocketFrame[0] = 0x81
        webSocketFrame[1] = UInt8(expectedMessage.count)
        let data : [UInt8] = [UInt8](expectedMessage.utf8)
        for index in 0...data.count-1 {
            webSocketFrame[2+index] = data[index]
        }
        
        let webSocketFrameParser = WebSocketFrameParser()
        webSocketFrameParser.webSockStateUtils = webSockUtils
        let processed = webSocketFrameParser.parse(buffer: webSocketFrame, size: 4)
        XCTAssertEqual(processed, 0)
    }
}
