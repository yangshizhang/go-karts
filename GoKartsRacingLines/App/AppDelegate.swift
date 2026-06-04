import UIKit

#if canImport(AMapFoundationKit)
import AMapFoundationKit
#endif

#if canImport(MAMapKit)
import MAMapKit
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if canImport(AMapFoundationKit)
        if let key = Bundle.main.object(forInfoDictionaryKey: "AMapApiKey") as? String, !key.isEmpty {
            AMapServices.shared().apiKey = key
        }
        #endif

        #if canImport(MAMapKit)
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        #endif
        return true
    }
}
