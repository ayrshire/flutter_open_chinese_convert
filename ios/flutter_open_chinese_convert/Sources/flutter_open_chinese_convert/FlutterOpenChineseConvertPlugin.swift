import Flutter
import OpenCC
import UIKit

public class FlutterOpenChineseConvertPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_open_chinese_convert", binaryMessenger: registrar.messenger())
        let instance = FlutterOpenChineseConvertPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    lazy var bundle: Bundle? = {
        let openCCBundle = Bundle(for: ChineseConverter.self)
        guard
            let resourceUrl = openCCBundle.url(
                forResource: "OpenCCDictionary", withExtension: "bundle")
        else {
            return nil
        }
        return Bundle(url: resourceUrl)
    }()

    func convertOption(from: String) -> ChineseConverter.Options {
        let map: [String: ChineseConverter.Options] = [
            "s2t": [.traditionalize],
            "t2s": [.simplify],
            "s2hk": [.traditionalize, .HKStandard],
            "hk2s": [.simplify, .HKStandard],
            "s2tw": [.traditionalize, .TWStandard],
            "tw2s": [.simplify, .TWStandard],
            "s2twp": [.traditionalize, .TWStandard, .TWIdiom],
            "tw2sp": [.simplify, .TWStandard, .TWIdiom],
        ]
        return map[from] ?? []
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        switch method {
        case "convert":
            guard let bundle = self.bundle else {
                let flutterError = FlutterError(
                    code: "NO_BUNDLE", message: "The bundle for the plugin does not exist.",
                    details: nil)
                result(flutterError)
                return
            }
            guard let list = call.arguments as? [Any],
                list.count >= 3,
                let text = list[0] as? String,
                let optionString = list[1] as? String,
                let inBackground = list[2] as? Bool
            else {
                let flutterError = FlutterError(
                    code: "MISSING_PARAMETER", message: "Required parameters are missing",
                    details: nil)
                result(flutterError)
                return
            }
            if inBackground {
                convertInBackground(
                    text: text, optionString: optionString, bundle: bundle, result: result)
            } else {
                convert(text: text, optionString: optionString, bundle: bundle, result: result)
            }

        default:
            let flutterError = FlutterError(code: "1", message: "Not supported", details: nil)
            result(flutterError)
        }
    }

    func convert(
        text: String, optionString: String, bundle: Bundle, result: @escaping FlutterResult
    ) {
        do {
            let option = convertOption(from: optionString)
            let converter = try ChineseConverter(bundle: bundle, option: option)
            let converted = converter.convert(text)
            result(converted)
        } catch {
            let flutterError = FlutterError(
                code: "0", message: error.localizedDescription, details: nil)
            result(flutterError)
        }
    }

    func convertInBackground(
        text: String, optionString: String, bundle: Bundle, result: @escaping FlutterResult
    ) {
        DispatchQueue.global().async {
            do {
                let option = self.convertOption(from: optionString)
                let converter = try ChineseConverter(bundle: bundle, option: option)
                let converted = converter.convert(text)
                DispatchQueue.main.async {
                    result(converted)
                }
            } catch {
                let flutterError = FlutterError(
                    code: "0", message: error.localizedDescription, details: nil)
                DispatchQueue.main.async {
                    result(flutterError)
                }
            }
        }
    }

}
