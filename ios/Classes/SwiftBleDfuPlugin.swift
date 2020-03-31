import Flutter
import UIKit
import iOSDFULibrary

public class DFUStreamHandler: NSObject {
    
    
    static var shared = DFUStreamHandler()
    
    
    var foundDevice:PeripherialWithRSSI?
    var dfuController: DFUServiceController?
    
    var eventSink: FlutterEventSink?
    
    func start(_ url: String, identifier: UUID){
        
        do {
            let pathUrl = URL(string: url)!
            let zipfileData = try Data(contentsOf: pathUrl)
            
            let selectedFirmware = DFUFirmware(zipFile: zipfileData)
            let initiator = DFUServiceInitiator()
            initiator.progressDelegate = self
            initiator.delegate = self
            initiator.enableUnsafeExperimentalButtonlessServiceInSecureDfu = true
            self.dfuController = initiator.with(firmware: selectedFirmware!).start(targetWithIdentifier: identifier)
            
        } catch {
            print(error.localizedDescription)
        }

    }
    
}

extension DFUStreamHandler: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

extension DFUStreamHandler: DFUProgressDelegate {
    public func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        self.eventSink!("part: \(part), outOf: \(totalParts), to: \(progress), speed: \(currentSpeedBytesPerSecond)")
    }
}

extension DFUStreamHandler: DFUServiceDelegate {
    public func dfuStateDidChange(to state: DFUState) {
        switch state {
        case .aborted:
            eventSink?(FlutterError(code: "\(state.rawValue)", message: "DFU Aborted", details: nil))
        default:
            print("dfuStateDidChange to: \(state.description())")
        }
    }
    
    public func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        eventSink?(FlutterError(code: "\(error.rawValue)", message: message, details: nil))
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
            NRFManager.sharedInstance.disconnectWithEnd {
                NRFManager.sharedInstance.scanAndChooseFirst = false
                NRFManager.sharedInstance.connect()
            }
            
            
        }
        
        if call.method == "startDfu" {
            let params = call.arguments as? Dictionary<String,String>
            DFUStreamHandler.shared.start(params!["url"]!, identifier: UUID(uuidString: params!["deviceAddress"]!)!)
            result("started")
        }
        
    }
}
