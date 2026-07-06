#if os(iOS)
import UIKit
import CloudKit

/// AppDelegate - Ekran yönelimi ve CloudKit paylaşım daveti kabulü
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // CloudKit sessiz push'ları için kayıt (arkadaş bildirimleri)
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // OrientationManager'dan izin verilen yönelimleri al
        return OrientationManager.shared.allowedOrientations
    }

    /// Paylaşılan veritabanı değiştiğinde gelen sessiz push:
    /// arkadaş verilerini tazele, yeni seans başlamışsa bildir
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        Task {
            await FriendSyncManager.shared.handleRemoteChange()
            completionHandler(.newData)
        }
    }

    /// SwiftUI yaşam döngüsünde CloudKit paylaşım davetini yakalayabilmek için
    /// scene delegate sınıfını elle belirtiyoruz (Apple'ın önerdiği yöntem)
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/// Arkadaş davet linkine tıklanınca paylaşımı kabul eder
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        FriendSyncManager.shared.acceptShare(metadata: cloudKitShareMetadata)
    }
}
#elseif os(macOS)
import AppKit
import CloudKit

/// AppDelegate - macOS: CloudKit paylaşım daveti kabulü ve sessiz push
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // CloudKit sessiz push'ları için kayıt (arkadaş bildirimleri)
        NSApplication.shared.registerForRemoteNotifications()
    }

    func application(
        _ application: NSApplication,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        FriendSyncManager.shared.acceptShare(metadata: metadata)
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else { return }
        Task {
            await FriendSyncManager.shared.handleRemoteChange()
        }
    }
}
#endif
