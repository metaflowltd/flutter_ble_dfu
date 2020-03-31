//
//  NRFManager.swift
//  nRF8001-Swift
//
//  Created by Michael Teeuw on 31-07-14.
//  Copyright (c) 2014 Michael Teeuw. All rights reserved.
//

import Foundation
import CoreBluetooth


public enum ConnectionMode {
    case none
    case pinIO
    case uart
}

public enum ConnectionStatus {
    case disconnected
    case scanning
    case connected
    
    var description : String {
        switch self {
        case .disconnected: return "Disconnected"
        case .scanning: return "Scanning"
        case .connected: return "Connected"
        }
    }
}

@objc public protocol NRFManagerDelegate {
    @objc optional func nrfDidConnect(_ nrfManager:NRFManager)
    @objc optional func nrfDidDisconnect(_ nrfManager:NRFManager)
    @objc optional func nrfReceivedData(_ nrfManager:NRFManager, data:Data?, string:String?)
}


/*!
*  @class NRFManager
*
*  @discussion The manager for nRF8001 connections.
*
*/

// Mark: NRFManager Initialization
let kNoDataReceivedNotification = "NoDataReceivedNotification"
let kDataReceivingResumedNotification = "DataReceivingResumedNotification"
let kDeviceDisconnectedNotification = "DeviceDisconnectedNotification"
let kDeviceConnectedNotification = "DeviceConnectedNotification"

public struct PeripherialWithRSSI{
    var peripherial: CBPeripheral
    var rssi: Float
}

extension PeripherialWithRSSI: Comparable {}
public func < (lhs: PeripherialWithRSSI, rhs: PeripherialWithRSSI) -> Bool {
    return lhs.rssi < rhs.rssi
}

public func == (lhs: PeripherialWithRSSI, rhs: PeripherialWithRSSI) -> Bool {
    return lhs.rssi == rhs.rssi
}

open class NRFManager:NSObject {
    

    //Private Properties
    var bluetoothManager:CBCentralManager?
    var currentPeripheral: UARTPeripheral? {
        didSet {
            if let p = currentPeripheral {
                p.verbose = self.verbose
            }
        }
    }
    
    //Public Properties
    open var verbose = false
    open var autoConnect = true
    open var delegate:NRFManagerDelegate?
    open var scanAndChooseFirst: Bool = false
    
    //callbacks
    open var initListenCallback:( ()->() )?
    open var disconnectEndCallback:( ()->() )?
    
    open var connectionCallback:(()->())?
    open var foundDeviceCallback:((PeripherialWithRSSI)->())?
    open var disconnectionCallback:(()->())?
    open var dataCallback:((_ data:Data?, _ string:String?)->())?
    
    open fileprivate(set) var connectionReceivingData:Bool = false
    open fileprivate(set) var batteryLevel:Int = 0
    open fileprivate(set) var fwVersion:String = ""
    
    open fileprivate(set) var connectionMode = ConnectionMode.none
    open fileprivate(set) var connectionStatus:ConnectionStatus = ConnectionStatus.disconnected {
        didSet {
            if connectionStatus != oldValue {
                switch connectionStatus {
                case .connected:
                    if (self.scanAndChooseFirst){
                        bluetoothManager!.stopScan()
                    }
                    connectionCallback?()
                    delegate?.nrfDidConnect?(self)
                    NotificationCenter.default.post(name: Notification.Name(rawValue: kDeviceConnectedNotification), object: nil)
                    
                case .disconnected:
                    disconnectionCallback?()
                    delegate?.nrfDidDisconnect?(self)
                    NotificationCenter.default.post(name: Notification.Name(rawValue: kDeviceDisconnectedNotification), object: nil)
                case .scanning:
                    delegate?.nrfDidDisconnect?(self)
                }
            }
        }
    }
    
    open var connectedDeviceName:String?
    
    
    open class var sharedInstance : NRFManager {
        struct Static {
            static let instance : NRFManager = NRFManager()
        }
        return Static.instance
    }
    
    public init(delegate:NRFManagerDelegate? = nil, onConnect connectionCallback:(()->())? = nil, onDisconnect disconnectionCallback:(()->())? = nil, onData dataCallback:((_ data:Data?, _ string:String?)->())? = nil, autoConnect:Bool = true)
    {
        super.init()
        self.delegate = delegate
        self.autoConnect = autoConnect
        bluetoothManager = CBCentralManager(delegate: self, queue: nil, options: [ CBCentralManagerOptionShowPowerAlertKey : true])
        self.connectionCallback = connectionCallback
        self.disconnectionCallback = disconnectionCallback
        self.dataCallback = dataCallback
    }
    
}


// MARK: - Private Methods
extension NRFManager {
    
    fileprivate func scanForPeripheral()
    {
        let connectedPeripherals = bluetoothManager!.retrieveConnectedPeripherals(withServices: [UARTPeripheral.uartServiceUUID()])
        
        if connectedPeripherals.count > 0 {
            log("Already connected ...")
            connectPeripheral(connectedPeripherals[0] )
        } else {
            log("Scan for Peripherials")
            bluetoothManager!.scanForPeripherals(withServices: [UARTPeripheral.uartServiceUUID()], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
            self.connectionStatus = ConnectionStatus.scanning
        }
    }
    
    public func connectPeripheral(_ peripheral:CBPeripheral) {
        log("Connect to Peripheral: \(peripheral)")
        self.connectedDeviceName = peripheral.name
        //        self.disconnect()
        bluetoothManager!.cancelPeripheralConnection(peripheral)
        
        currentPeripheral = UARTPeripheral(peripheral: peripheral, delegate: self)
        
        bluetoothManager!.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey:false])
    }
    
    fileprivate func alertBluetoothPowerOff() {
        log("Bluetooth disabled");
        disconnect()
    }
    
    fileprivate func alertFailedConnection() {
        log("Unable to connect");
    }
    
    fileprivate func log(_ logMessage: String) {
        if (verbose) {
            print("NRFManager: \(logMessage)")
        }
    }
}

// MARK: - Public Methods
extension NRFManager {
    
    public func stopScan(){
        bluetoothManager?.stopScan()
    }
    
    public func connect() {
        if currentPeripheral != nil && connectionStatus == .connected {
            log("Asked to connect, but already connected!")
            return
        }
        
        scanForPeripheral()
    }
    
    
    public func disconnectWithEnd(completion:@escaping ()->()){
        self.disconnectEndCallback = completion
        self.disconnect()
    }
    
    public func disconnect()
    {
        if currentPeripheral == nil {
            log("Asked to disconnect, but no current connection!")
            self.disconnectEndCallback?()
            return
        }
        
        log("Disconnect ...")
        if #available(iOS 9.0, *) {
           if self.currentPeripheral?.peripheral.state == CBPeripheralState.disconnecting && self.currentPeripheral?.peripheral.state == CBPeripheralState.connecting {
               return
           }
        }else{
        }
        self.currentPeripheral!.prepareForDisconnect()
        
        bluetoothManager!.cancelPeripheralConnection(currentPeripheral!.peripheral)
    }
    
    public func writeString(_ string:String) -> Bool
    {
        if let currentPeripheral = self.currentPeripheral {
            if connectionStatus == .connected {
                currentPeripheral.writeString(string)
                return true
            }
        }
        log("Can't send string. No connection!")
        return false
    }
    
    public func writeData(_ data:Data) -> Bool
    {
        if let currentPeripheral = self.currentPeripheral {
            if connectionStatus == .connected {
                currentPeripheral.writeRawData(data)
                return true
            }
        }
        log("Can't send data. No connection!")
        return false
    }
    
}

// MARK: - CBCentralManagerDelegate Methods
extension NRFManager: CBCentralManagerDelegate {
    
    @available(iOS 10.0, *)
    var btStatePoweredOn:Bool {
        return self.btState == .poweredOn
    }

    @available(iOS 10.0, *)
    var btState:CBManagerState {
        return self.bluetoothManager!.state
    }
    public func centralManagerDidUpdateState(_ central: CBCentralManager)
    {
        log("Central Manager Did UpdateState")
        if central.state == .poweredOn {
            //respond to powered on
            log("Powered on!")
            connectionMode = .uart
            if (autoConnect) {
                connect()
            }
            
        } else if central.state == .poweredOff {
            log("Powered off!")
            connectionStatus = ConnectionStatus.disconnected
            connectionMode = ConnectionMode.none
        }
        self.initListenCallback?()
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)
    {
        if (self.foundDeviceCallback != nil){
            self.foundDeviceCallback!(PeripherialWithRSSI(peripherial: peripheral, rssi: RSSI.floatValue))
        }
        
        log("Did discover peripheral: \(peripheral.name) ident: \(peripheral.identifier)")
        //            if (peripheral.identifier == NSUUID(UUIDString: "4BE30C76-094D-E267-9206-11D102E86D17")){
        if (self.scanAndChooseFirst){
            //                bluetoothManager!.stopScan()
            connectPeripheral(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    {
        log("Did Connect Peripheral")
        if currentPeripheral?.peripheral == peripheral {
            if (peripheral.services) != nil {
                log("Did connect to existing peripheral: \(peripheral.name)")
                currentPeripheral?.peripheral(peripheral, didDiscoverServices: nil)
            } else {
                log("Did connect peripheral: \(peripheral.name)")
                currentPeripheral?.didConnect()
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
    {
        log("Peripheral Disconnected: \(peripheral.name)")
        
        if currentPeripheral?.peripheral == peripheral {
            connectionStatus = ConnectionStatus.disconnected
            currentPeripheral = nil
        }
        
        self.disconnectEndCallback?()
        if self.disconnectEndCallback != nil{
            return
        }
        if autoConnect {
            connect()
        }
    }
    
    //optional func centralManager(central: CBCentralManager!, willRestoreState dict: [NSObject : AnyObject]!)
    //optional func centralManager(central: CBCentralManager!, didRetrievePeripherals peripherals: [AnyObject]!)
    //optional func centralManager(central: CBCentralManager!, didRetrieveConnectedPeripherals peripherals: [AnyObject]!)
    //optional func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!)
}

// MARK: - UARTPeripheralDelegate Methods
extension NRFManager: UARTPeripheralDelegate {
    
    func printIfHas(_ pre:String, str: NSString?){
        if (str != nil){
            let text = "\(pre): \(str!)"
            print(text)
        }
    }
    
    public func didReceiveData(_ newData:Data)
    {
        if (connectionStatus != .connected){
            connectionStatus = .connected
            
        }
        
        self.connectionReceivingData = true
        
        if connectionStatus == .connected || connectionStatus == .scanning {
            //            let string0 = NSString(data: newData, encoding:NSASCIIStringEncoding)
            let string0 = NSString(data: newData, encoding:String.Encoding.windowsCP1250.rawValue)
            
            //            log("String: \(string0!)")
            dataCallback?(newData, string0! as String)
            delegate?.nrfReceivedData?(self, data:newData, string: string0! as String)
            NotificationCenter.default.post(name: Notification.Name(rawValue: kDataReceivingResumedNotification), object: nil)
        }
    }
    
    public func didReadHardwareRevisionString(_ string:String)
    {
        log("HW Revision: \(string)")
        connectionStatus = .connected
    }
    
    public func uartDidEncounterError(_ error:String)
    {
        log("Error: error")
    }
    
}



