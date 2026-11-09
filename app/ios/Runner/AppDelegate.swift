import CoreBluetooth
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var flyby: FlybyRadio?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FlybyRadio") {
      flyby = FlybyRadio(messenger: registrar.messenger())
    }
  }
}

/// Layer B fly-by radio (Prompts/01-GPS.md). iOS cannot put service data in
/// an advertisement, so the current rolling identifier (RPI) is served from a
/// read-only GATT characteristic; the scanner reads Android peers' RPI from
/// their scan response and iOS peers' RPI by a short GATT read.
/// No location is used. Foreground only for now (no background modes).
final class FlybyRadio: NSObject, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate {
  private var central: CBCentralManager?
  private var peripheralManager: CBPeripheralManager?
  private var serviceUUID: CBUUID?
  private var characteristicUUID: CBUUID?
  private var rpi = Data()
  private var sink: FlutterEventSink?
  private var startResult: FlutterResult?
  private var pending: [UUID: CBPeripheral] = [:]
  private var known: [UUID: (rpi: Data, at: Date)] = [:]
  private var lastRead: [UUID: Date] = [:]
  private var lastRssi: [UUID: Int] = [:]

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "alienmatch/flyby", binaryMessenger: messenger).setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
    FlutterEventChannel(name: "alienmatch/flyby/sightings", binaryMessenger: messenger).setStreamHandler(self)
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "start":
      guard let r = (args?["rpi"] as? FlutterStandardTypedData)?.data,
            let s = args?["service"] as? String,
            let c = args?["characteristic"] as? String else {
        result(false)
        return
      }
      rpi = r
      serviceUUID = CBUUID(string: s)
      characteristicUUID = CBUUID(string: c)
      startResult = result
      central = CBCentralManager(delegate: self, queue: nil)
      peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    case "updateRpi":
      if let r = (args?["rpi"] as? FlutterStandardTypedData)?.data { rpi = r }
      result(nil)
    case "stop":
      central?.stopScan()
      for p in pending.values { central?.cancelPeripheralConnection(p) }
      pending.removeAll()
      peripheralManager?.stopAdvertising()
      peripheralManager?.removeAllServices()
      central = nil
      peripheralManager = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func finishStart(_ ok: Bool) {
    startResult?(ok)
    startResult = nil
  }

  // MARK: Central (scanner)

  func centralManagerDidUpdateState(_ c: CBCentralManager) {
    switch c.state {
    case .poweredOn:
      if let s = serviceUUID {
        c.scanForPeripherals(withServices: [s], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
      }
      finishStart(true)
    case .poweredOff, .unauthorized, .unsupported:
      finishStart(false)
    default:
      break
    }
  }

  func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData ad: [String: Any], rssi RSSI: NSNumber) {
    let rssi = RSSI.intValue
    if rssi == 127 { return }
    lastRssi[p.identifier] = rssi
    if let s = serviceUUID, let data = (ad[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data])?[s], data.count == rpi.count {
      emit(data, rssi) // Android peer
      return
    }
    let now = Date()
    if let k = known[p.identifier], now.timeIntervalSince(k.at) < 300 {
      emit(k.rpi, rssi)
      return
    }
    if pending[p.identifier] != nil { return }
    if let at = lastRead[p.identifier], now.timeIntervalSince(at) < 30 { return }
    lastRead[p.identifier] = now
    pending[p.identifier] = p
    p.delegate = self
    c.connect(p, options: nil)
  }

  func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
    p.discoverServices(serviceUUID.map { [$0] })
  }

  func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
    pending[p.identifier] = nil
  }

  func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
    pending[p.identifier] = nil
  }

  func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
    guard let svc = p.services?.first(where: { $0.uuid == serviceUUID }) else {
      central?.cancelPeripheralConnection(p)
      return
    }
    p.discoverCharacteristics(characteristicUUID.map { [$0] }, for: svc)
  }

  func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
    guard let ch = s.characteristics?.first(where: { $0.uuid == characteristicUUID }) else {
      central?.cancelPeripheralConnection(p)
      return
    }
    p.readValue(for: ch)
  }

  func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
    if let v = ch.value, v.count == rpi.count {
      known[p.identifier] = (v, Date())
      emit(v, lastRssi[p.identifier] ?? -70)
    }
    central?.cancelPeripheralConnection(p)
  }

  // MARK: Peripheral (advertiser)

  func peripheralManagerDidUpdateState(_ pm: CBPeripheralManager) {
    guard pm.state == .poweredOn, let s = serviceUUID, let c = characteristicUUID else { return }
    let ch = CBMutableCharacteristic(type: c, properties: [.read], value: nil, permissions: [.readable])
    let svc = CBMutableService(type: s, primary: true)
    svc.characteristics = [ch]
    pm.removeAllServices()
    pm.add(svc)
    pm.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [s]])
  }

  func peripheralManager(_ pm: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    guard request.offset <= rpi.count else {
      pm.respond(to: request, withResult: .invalidOffset)
      return
    }
    request.value = rpi.subdata(in: request.offset..<rpi.count)
    pm.respond(to: request, withResult: .success)
  }

  private func emit(_ value: Data, _ rssi: Int) {
    sink?(["rpi": FlutterStandardTypedData(bytes: value), "rssi": rssi])
  }
}
