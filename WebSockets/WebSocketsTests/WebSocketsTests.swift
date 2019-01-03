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
    
    let maxSize : Int = ((1024*64)+16)

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
        let buffer = CircularBuffer<UInt8>(capacity: maxSize)
        _ = buffer.put(data: 0x81 )
        _ = buffer.put(data: UInt8(expectedMessage.count))
        let data : [UInt8] = [UInt8](expectedMessage.utf8)
        _ = buffer.write(data: data)
        
        let webSocketFrameParser = WebSocketFrameParser()
        webSocketFrameParser.webSockStateUtils = webSockUtils
        let processed = webSocketFrameParser.parse(buffer: buffer)
        XCTAssertEqual(processed, 8)
        XCTAssertEqual(receivedMessage, expectedMessage)
        XCTAssertEqual(0, buffer.availableToRead())
    }
    
    func testMultipleSimpleTextFrames() {
        
        let webSockUtils = WebSocketStateUtils()
        let expected1 = "Hello!"
        let expected2 = "How are you?"
        let buffer = CircularBuffer<UInt8>(capacity: maxSize)

        _ = buffer.put(data: 0x81 )
        _ = buffer.put(data: UInt8(expected1.count))
        
        let data1 = [UInt8](expected1.utf8)
        _ = buffer.write(data: data1)
        
        _ = buffer.put(data: 0x81 )
        _ = buffer.put(data: UInt8(expected2.count))
        
        let data2 = [UInt8](expected2.utf8)
        _ = buffer.write(data: data2)
        
        let expectedProcessed1 = expected1.count + 2
        let expectedProcessed2 = expected2.count + 2
        let webSocketFrameParser = WebSocketFrameParser()
        webSocketFrameParser.webSockStateUtils = webSockUtils
        var processed = webSocketFrameParser.parse(buffer: buffer)
        XCTAssertEqual(processed, expectedProcessed1)
        XCTAssertEqual(expected2.count + 2, buffer.availableToRead())

        
        var receivedMessage = ""
        webSockUtils.didReceiveMessage = {
            (message) in
            receivedMessage = message
        }
        
        processed = webSocketFrameParser.parse(buffer: buffer)
        XCTAssertEqual(processed, expectedProcessed2)
        XCTAssertEqual(receivedMessage, expected2)
        XCTAssertEqual(0, buffer.availableToRead())

    }
    
    func testUnderflowSimpleTextFrame() {
        let webSockUtils = WebSocketStateUtils()
        let expectedMessage = "Hello!"
        let buffer = CircularBuffer<UInt8>(capacity: maxSize)

        _ = buffer.put(data: 0x81 )
        _ = buffer.put(data: UInt8(42))
        _ = buffer.write(data: [UInt8](expectedMessage.utf8))
        
        
        let webSocketFrameParser = WebSocketFrameParser()
        webSocketFrameParser.webSockStateUtils = webSockUtils
        let processed = webSocketFrameParser.parse(buffer: buffer)
        XCTAssertEqual(processed, 0)
    }
    
    func testLargeTextFrame() {
        let expected = "in hac habitasse platea dictumst vestibulum rhoncus est pellentesque elit ullamcorper dignissim cras tincidunt lobortis feugiat vivamus at augue eget arcu dictum varius duis at consectetur lorem donec massa sapien faucibus et molestie ac feugiat sed lectus vestibulum mattis ullamcorper velit sed ullamcorper morbi tincidunt ornare massa eget egestas purus viverra accumsan in nisl"
        
        let webSockUtils = WebSocketStateUtils()
        let buffer = CircularBuffer<UInt8>(capacity: maxSize)
        _ = buffer.put(data: 0x81 )
        _ = buffer.put(data: UInt8(126) )

        let count = UInt16(expected.count)
        let size : [UInt8] = [
            UInt8((count & 0xff00) >> 8),
            UInt8(count & 0x00ff)
        ]
        _ = buffer.write(data: size)
        
        let data : [UInt8] = [UInt8](expected.utf8)
        _ = buffer.write(data: data)
        let expectedProcess = data.count + 4
        let webSocketFrameParser = WebSocketFrameParser()
        webSocketFrameParser.webSockStateUtils = webSockUtils
        let processed = webSocketFrameParser.parse(buffer: buffer)
        XCTAssertEqual(processed, expectedProcess)
    }
    
    func testCreateRingBuffer() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 1024)
        XCTAssertEqual(circularBuffer.availableToWrite(), 1024)
    }
    
    func testBumpRingBuffer() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 1024)
        guard let pptr = circularBuffer.getWritePtr() else {
            XCTAssertTrue(false, "fail")
            return
        }
        
        for val in 0...4 {
            pptr[val] = UInt8(val)
        }
        
        let bumped = circularBuffer.bump(count: 4)
        XCTAssertEqual(bumped, 4)
        XCTAssertEqual(circularBuffer.availableToWrite(), 1020)
        
    }
    
    func testConsumeBuffer() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 1024)
        guard let pptr = circularBuffer.getWritePtr() else {
            XCTAssertTrue(false, "fail")
            return
        }
        
        for val in 0...4 {
            pptr[val] = UInt8(val)
        }
        
        _ = circularBuffer.bump(count: 4)
        XCTAssertEqual(circularBuffer.availableToRead(), 4)
        guard let gptr = circularBuffer.getReadPtr() else {
            XCTAssertTrue(false, "fail")
            return
        }
        
        for i in 0...4 {
            XCTAssertEqual(UInt8(i), gptr[i])
        }
        
        let consumed = circularBuffer.consume(count: 4)
        XCTAssertEqual(consumed, 4)
        XCTAssertEqual(0, circularBuffer.availableToRead())
        XCTAssertEqual(circularBuffer.availableToWrite(), 1020)

    }
    
    func testGetDataRingBuffer() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 4)
        let wptr = circularBuffer.getWritePtr()
        guard let pptr = wptr else {
            return
        }
        
        for val in 0..<4 {
            pptr[val] = UInt8(val) + 1
        }
        _ = circularBuffer.bump(count: 4)

        XCTAssertEqual(4, circularBuffer.availableToRead())
        let data = circularBuffer.getData(count: 2)
        for v in 0..<data.count {
            XCTAssertEqual(UInt8(v+1), data[v])
        }
        
        XCTAssertEqual(2, circularBuffer.availableToRead())

    }
    
    func testOverFlow() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 4)
        let wptr = circularBuffer.getWritePtr()
        guard let pptr = wptr else {
            return
        }
        
        for val in 0...3 {
            pptr[val] = UInt8(val) + 1
        }
        
        _ = circularBuffer.bump(count: 2)
        _ = circularBuffer.consume(count: 2)
        XCTAssertEqual(0, circularBuffer.availableToRead())
        
        let bumped = circularBuffer.bump(count: 3)
        XCTAssertEqual(2, bumped)
        XCTAssertEqual(1, circularBuffer.availableToWrite())
        XCTAssertEqual(2, circularBuffer.availableToRead())
        
        let wptrAfter = circularBuffer.getWritePtr()
        guard let pptrAfter = wptrAfter else {
            return
        }
        
        pptrAfter[0] = 9
        _ = circularBuffer.bump(count: 1)
        XCTAssertEqual(3, circularBuffer.availableToRead())
        XCTAssertEqual(0, circularBuffer.availableToWrite())

        var data = circularBuffer.getData(count: 3)
        XCTAssertEqual(3, data.count)
        XCTAssertEqual(3, data[0])
        XCTAssertEqual(4, data[1])
        XCTAssertEqual(9, data[2])

        XCTAssertEqual(0, circularBuffer.availableToRead())

    }

    func testWriteRingBuffer() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 4)
        let written = circularBuffer.write(data: [1,2,3,4])
        XCTAssertEqual(4, written)
        XCTAssertEqual(0, circularBuffer.availableToWrite())
        XCTAssertEqual(4, circularBuffer.availableToRead())

        let testData = circularBuffer.getData(count: 4)
        XCTAssertEqual(4, testData.count)
        for i in 0..<testData.count {
            XCTAssertEqual(UInt8(i+1), testData[i])
        }
    }
    
    func testOverflowWriteRingBuffer() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 4)
        _ = circularBuffer.bump(count: 2)
        _ = circularBuffer.consume(count: 2)
        let written = circularBuffer.write(data: [1,2,3])
        XCTAssertEqual(3, written)
        XCTAssertEqual(0, circularBuffer.availableToWrite())
        XCTAssertEqual(3, circularBuffer.availableToRead())
        
        let testData = circularBuffer.getData(count: 4)
        XCTAssertEqual(3, testData.count)
        for i in 0..<testData.count {
            XCTAssertEqual(UInt8(i+1), testData[i])
        }
    }
    
    func testOverflowOverwriteWriteRingBuffer() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 4)
        _ = circularBuffer.bump(count: 2)
        _ = circularBuffer.consume(count: 2)
        let written = circularBuffer.write(data: [1,2,3, 4])
        XCTAssertEqual(3, written)
        XCTAssertEqual(0, circularBuffer.availableToWrite())
        XCTAssertEqual(3, circularBuffer.availableToRead())
        
        let testData = circularBuffer.getData(count: 4)
        XCTAssertEqual(3, testData.count)
        for i in 0..<testData.count {
            XCTAssertEqual(UInt8(i+1), testData[i])
        }
    }
    
    func testPeekRingBuffer() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 8)
        _ = circularBuffer.write(data: [1,2,3,4,5,6,7,8])
        for val in 0..<8 {
            let b = circularBuffer.peek(at: val)
            XCTAssertEqual(8, circularBuffer.availableToRead())
            XCTAssertEqual(UInt8(val+1), b)
        }
    }
    
    func testPeekRingBufferUnderflow() {
        let circularBuffer = CircularBuffer<UInt8>(capacity: 8)
        _ = circularBuffer.write(data: [1,2,3,4])
        let b = circularBuffer.peek(at: 5)
        XCTAssertNil(b)
        XCTAssertEqual(4, circularBuffer.availableToRead())
    }
}
