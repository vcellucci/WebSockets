//
//  CircularBuffer.swift
//  WebSockets
//
//  Created by Vittorio Cellucci on 12/28/18.
//  Copyright © 2018 Vittorio Cellucci. All rights reserved.
//

import Foundation
class CircularBuffer<T> {
    
    var baseBuffer : UnsafeMutablePointer<T>?
    var writePtr   : UnsafeMutablePointer<T>?
    var readPtr    : UnsafeMutablePointer<T>?
    var endPtr     : UnsafeMutablePointer<T>?
    
    var maxSize = 0
    var spaceAvailable = 0
    
    init(capacity _maxsize: Int) {
        maxSize = _maxsize
        baseBuffer = UnsafeMutablePointer<T>.allocate(capacity: maxSize)
        writePtr = baseBuffer?.advanced(by: 0)
        readPtr = baseBuffer?.advanced(by: 0)
        endPtr  = baseBuffer! + maxSize
        spaceAvailable = maxSize
    }
    
    func reset() {
        baseBuffer = UnsafeMutablePointer<T>.allocate(capacity: maxSize)
        writePtr = baseBuffer?.advanced(by: 0)
        readPtr = baseBuffer?.advanced(by: 0)
        endPtr  = baseBuffer! + maxSize
        spaceAvailable = maxSize
    }
    
    func availableToWrite() -> Int {
        guard let eptr = endPtr else {
            return 0
        }
        
        guard let gptr = readPtr else {
            return 0
        }
        
        guard let pptr = writePtr else {
            return 0
        }
        
        var val = 0
        if(pptr >= gptr){
            val = eptr - pptr
        }
        else {
            val = (gptr - 1) - pptr
        }
        
        return val
    }
    
    func availableToRead() -> Int {
        guard let pptr = writePtr else {
            return 0
        }
        
        guard let gptr = readPtr else {
            return 0
        }
        
        var val = 0
        if gptr <= pptr {
            val = pptr - gptr
        }
        else {
            guard let eptr = endPtr else {
                return 0
            }
            
            guard let bptr = baseBuffer else {
                return 0
            }
            
            val = (eptr - gptr) + (pptr - bptr)
        }
        
        return val
    }
    
    func  getWritePtr() -> UnsafeMutablePointer<T>? {
       return writePtr
    }
    
    func getReadPtr() -> UnsafeMutablePointer<T>? {
        return readPtr
    }
    
    func bump(count c : Int) -> Int {

        if( c > maxSize ) {
            return 0
        }

        guard var pptr = writePtr else {
            return 0
        }
        
        var tobump = c
        var needsWrap = false
        if availableToWrite() < c {
            tobump = availableToWrite() // wrapped around here
            needsWrap = true
        }
        if needsWrap {
            pptr = baseBuffer!
        }
        else {
            pptr += tobump
        }
        writePtr? = pptr
        return tobump
    }
    
    func consume(count c : Int) -> Int {
        if( c > maxSize ){
            return 0
        }

        guard var gptr = readPtr else {
            return 0
        }
        gptr += c
        readPtr? = gptr
        return c
    }
    
    func getData(count c : Int) -> [T] {
        var a = [T]()
        
        
        guard var gptr = readPtr else { return a }
        guard let pptr = writePtr else { return a }
        
        var currentCount = 0
        if gptr > pptr {
            guard let eptr = endPtr else { return a }
            guard let bptr = baseBuffer else { return a }
            
            currentCount = eptr - gptr
            if currentCount >= c {
                currentCount = c
                a = Array(UnsafeBufferPointer(start: gptr, count: currentCount))
                gptr += currentCount
            }
            else {
                a = Array(UnsafeBufferPointer(start: gptr, count: currentCount))
                gptr = bptr
            }
            
        }
        
        currentCount = (pptr - gptr)
        if c <= currentCount {
            currentCount = c
        }
        if currentCount < 0 {
            currentCount = 0
        }
        a.append(contentsOf: Array(UnsafeBufferPointer(start: gptr, count: currentCount)))
        gptr += currentCount
        readPtr = gptr
        return a
    }
    
    func put(data byte : T) -> Int{
        guard let pptr = writePtr else {
            return 0
        }
        pptr[0] = byte
        return bump(count: 1)
    }
    
    func write( data bytes : UnsafeMutablePointer<T>, size count : Int) -> Int {
        return write(data: Array<T>(UnsafeBufferPointer(start: bytes, count: count)))
    }

    func write(data bytes : Array<T>) -> Int {

        if( bytes.count > maxSize ){
            return 0
        }
        guard var pptr = writePtr else {
            return 0
        }
        
        guard let eptr = endPtr else {
            return 0
        }
        
        guard let gptr = readPtr else {
            return 0
        }
        
        var index = 0
        var bytesWritten = 0
        if availableToWrite() < bytes.count {
            guard let bptr = baseBuffer else { return 0 }
            while( (pptr < eptr) && (index < bytes.count) ){
                pptr.pointee = bytes[index]
                index += 1
                pptr += 1
                bytesWritten += 1
            }
            pptr = bptr
        }
        
        if gptr > pptr {
            while( (index < bytes.count) && (pptr < (gptr-1)) ) {
                pptr.pointee = bytes[index]
                pptr += 1
                bytesWritten += 1
                index += 1
            }
        }
        else {
            for val in bytes {
                pptr.pointee = val
                bytesWritten += 1
                pptr += 1
            }
        }
        writePtr = pptr
        return bytesWritten
    }
    
    func peek(at pos : Int) -> T? {
        guard var gptr = readPtr else {
            return nil
        }
        
        if pos > availableToRead() {
            return nil
        }
        gptr += pos
        return gptr.pointee
    }
    
}
