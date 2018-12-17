import Flutter
import UIKit
import iOSDFULibrary

public class DFUStreamHandler: NSObject, FlutterStreamHandler, DFUProgressDelegate {
    
    public func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        self.eventSink!("part: \(part), outOf: \(totalParts), to: \(progress), speed: \(currentSpeedBytesPerSecond)")
    }
    
    
    static var shared = DFUStreamHandler()
    
    
    var foundDevice:PeripherialWithRSSI?
    var dfuController: DFUServiceController?
    
    var eventSink: FlutterEventSink?
    
    func start(_ url: String){
        
        do {
            let pathUrl = URL(string: url)!
            let zipfileData = try Data(contentsOf: pathUrl)
            
            let selectedFirmware = DFUFirmware(zipFile: zipfileData)
            let initiator = DFUServiceInitiator(centralManager: NRFManager.sharedInstance.bluetoothManager!, target: self.foundDevice!.peripherial)
            initiator.progressDelegate = self
            initiator.enableUnsafeExperimentalButtonlessServiceInSecureDfu = true
            self.dfuController = initiator.with(firmware: selectedFirmware!).start()
            
        } catch {
            print(error.localizedDescription)
        }

    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    @objc func afterAwhile(){
        self.eventSink!("half way there")
    }
    
}

public class SwiftBleDfuPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        
        let eventChannel = FlutterEventChannel(name: "ble_dfu_event", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(DFUStreamHandler.shared)
        
        let channel = FlutterMethodChannel(name: "ble_dfu", binaryMessenger: registrar.messenger())
        let instance = SwiftBleDfuPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
   
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        if call.method == "scanForDfuDevice"{
            NRFManager.sharedInstance.foundDeviceCallback = {
                (peri: PeripherialWithRSSI) in
                
                if peri.peripherial.name == nil {
                    return
                }
                DFUStreamHandler.shared.foundDevice = peri
                
                result("found \(peri.peripherial.name!)")
            }
            NRFManager.sharedInstance.disconnect()
            NRFManager.sharedInstance.scanAndChooseFirst = false
            NRFManager.sharedInstance.connect()
            
        }
        
        if call.method == "startDfu" {
            if DFUStreamHandler.shared.foundDevice == nil {
                result("no device")
                return
            }
            let params = call.arguments as? Dictionary<String,String>
            DFUStreamHandler.shared.start(params!["url"]!)
            result("started")
        }
        
    }
}
