//
//  UARTPeripheral.swift
//  nRF8001-Swift
//
//  Created by Danny Shmueli on 8/13/15.
//  Copyright (c) 2015 Michael Teeuw. All rights reserved.
//

import UIKit
import CoreBluetooth

/*!
*  @class UARTPeripheral
*
*  @discussion The peripheral object used by NRFManager.
*
*/
// MARK: UARTPeripheralDelegate Definition
protocol UARTPeripheralDelegate {
    func didReceiveData(_ newData:Data)
    func didReadHardwareRevisionString(_ string:String)
    func uartDidEncounterError(_ error:String)
}


class UARTPeripheral: NSObject , CBPeripheralDelegate{
    var peripheral:CBPeripheral
    fileprivate var uartService:CBService?
    fileprivate var rxCharacteristic:CBCharacteristic?
    fileprivate var txCharacteristic:CBCharacteristic?
    
    var delegate:UARTPeripheralDelegate
    var verbose = false
    
    init(peripheral:CBPeripheral, delegate:UARTPeripheralDelegate)
    {
        
        self.peripheral = peripheral
        self.delegate = delegate
        
        super.init()
        
        self.peripheral.delegate = self
    }
    
    fileprivate func compareID(_ firstID:CBUUID, toID secondID:CBUUID)->Bool {
        return firstID.uuidString == secondID.uuidString
        
    }
    
    fileprivate func setupPeripheralForUse(_ peripheral:CBPeripheral)
    {
        log("Set up peripheral for use");
        for s:CBService in peripheral.services as [CBService]! {
            for c:CBCharacteristic in s.characteristics as [CBCharacteristic]! {
                if compareID(c.uuid, toID: UARTPeripheral.rxCharacteristicsUUID()) {
                    log("Found RX Characteristics")
                    rxCharacteristic = c
                    peripheral.setNotifyValue(true, for: rxCharacteristic!)
                } else if compareID(c.uuid, toID: UARTPeripheral.txCharacteristicsUUID()) {
                    log("Found TX Characteristics")
                    txCharacteristic = c
                } else if compareID(c.uuid, toID: UARTPeripheral.hardwareRevisionStringUUID()) {
                    log("Found Hardware Revision String characteristic")
                    peripheral.readValue(for: c)
                }
            }
        }
        delegate.didReadHardwareRevisionString("i'm so cool i do not need a hardware revision string")
    }
    
    func prepareForDisconnect(){
        if rxCharacteristic == nil{
            return
        }
        self.peripheral.setNotifyValue(false, for: rxCharacteristic!)
    }
    
    fileprivate func log(_ logMessage: String) {
        if (verbose) {
            print("UARTPeripheral: \(logMessage)")
        }
    }
    
    func didConnect()
    {
        log("Did connect")
        if peripheral.services != nil {
            log("Skipping service discovery for: \(peripheral.name)")
            peripheral(peripheral, didDiscoverServices: nil)
            return
        }
        
        log("Start service discovery: \(peripheral.name)")
        peripheral.delegate = self
        peripheral.discoverServices([UARTPeripheral.uartServiceUUID()])
//        delegate.didReadHardwareRevisionString("i'm so cool i do not need a hardware revision string")
    }
    
    func writeString(_ string:String)
    {
        log("Write string: \(string)")
        let data = Data(bytes: UnsafePointer<UInt8>(string), count:string.count)
        writeRawData(data)
    }
    
    func writeRawData(_ data:Data)
    {
        log("Write data: \(data)")
        
        if let txCharacteristic = self.txCharacteristic {
            if txCharacteristic.properties.contains( CBCharacteristicProperties.write) {
                peripheral.writeValue(data, for: txCharacteristic, type: .withResponse)
            } else if txCharacteristic.properties.contains(CBCharacteristicProperties.writeWithoutResponse) {
                peripheral.writeValue(data, for: txCharacteristic, type: .withoutResponse)
            } else {
                log("No write property on TX characteristics: \(txCharacteristic.properties)")
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error:Error?) {
        if error == nil {
            for s:CBService in peripheral.services as [CBService]! {
                if s.characteristics != nil {
                    //peripheral(peripheral, didDiscoverCharacteristicsForService: s, error: e)
                } else if compareID(s.uuid, toID: UARTPeripheral.uartServiceUUID()) {
                    log("Found correct service")
                    uartService = s
                    peripheral.discoverCharacteristics([UARTPeripheral.txCharacteristicsUUID(),UARTPeripheral.rxCharacteristicsUUID()], for: uartService!)
                } else if compareID(s.uuid, toID: UARTPeripheral.deviceInformationServiceUUID()) {
                    peripheral.discoverCharacteristics([UARTPeripheral.hardwareRevisionStringUUID()], for: s)
                }
            }
        } else {
            log("Error discovering characteristics: \(error)")
            delegate.uartDidEncounterError("Error discovering services")
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    {
        if error  == nil {
            log("Did Discover Characteristics For Service: \(service.description)")
            let services:[CBService] = peripheral.services as [CBService]!
            let s = services[services.count - 1]
            if compareID(service.uuid, toID: s.uuid) {
                setupPeripheralForUse(peripheral)
            }
        } else {
            log("Error discovering characteristics: \(error)")
            delegate.uartDidEncounterError("Error discovering characteristics")
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
        log("Did Update Value For Characteristic")
        if error == nil {
            if characteristic == rxCharacteristic {
                log("Recieved: \(characteristic.value)")
                delegate.didReceiveData(characteristic.value!)
            } else if compareID(characteristic.uuid, toID: UARTPeripheral.hardwareRevisionStringUUID()){
                log("Did read hardware revision string")
                // FIX ME: This is not how the original thing worked.
                delegate.didReadHardwareRevisionString(NSString(cString:characteristic.description, encoding: String.Encoding.utf8.rawValue)! as String)
                
            }
        } else {
            log("Error receiving notification for characteristic: \(error)")
            delegate.uartDidEncounterError("Error receiving notification for characteristic")
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
    }
}


// MARK: Class Methods
extension UARTPeripheral {
    class func uartServiceUUID() -> CBUUID {
        return CBUUID(string: "FE59")
//        return CBUUID(string:"6e400001-521D-4CC7-9E02-998F7C95E710") //new uuid
    }
    
    class func txCharacteristicsUUID() -> CBUUID {
//        return CBUUID(string: CommonSettingManager.getTxCharacteristicsUUID())
        return CBUUID(string:"6e400002-521D-4CC7-9E02-998F7C95E710") //new uuid
    }
    
    class func rxCharacteristicsUUID() -> CBUUID {
//        return CBUUID(string:CommonSettingManager.getRxCharacteristicsUUID())
        return CBUUID(string:"6e400003-521D-4CC7-9E02-998F7C95E710") //new uuid
    }
    
    class func deviceInformationServiceUUID() -> CBUUID{
        return CBUUID(string:"180A")
    }
    
    class func hardwareRevisionStringUUID() -> CBUUID{
        return CBUUID(string:"2A27")
    }
}
