import ExpoModulesCore
import HealthKit
import OpenWearablesHealthSDK

public class OpenWearablesModule: Module {
    private let healthStore = HKHealthStore()

    public func definition() -> ModuleDefinition {
        Name("OpenWearablesHealthSDK")
        
        // MARK: - Callbacks (Events)        
        Events("onLog", "onAuthError")
        
        // MARK: - Lifecycle        
        OnCreate {
            OpenWearablesHealthSDK.shared.onLog = { message in
                self.sendEvent("onLog", [
                    "message": message
                ])
            }
            
            OpenWearablesHealthSDK.shared.onAuthError = { statusCode, message in
                self.sendEvent("onAuthError", [
                    "statusCode": statusCode,
                    "message": message
                ])
            }
        }
        
        // MARK: - Configure        
        Function("configure") { (host: String, customSyncURL: String?) in
            OpenWearablesHealthSDK.shared.configure(host: host)
        }
        
        // MARK: - Auth        
        AsyncFunction("signIn") { (
            userId: String,
            accessToken: String?,
            refreshToken: String?,
            apiKey: String?,
            promise: Promise
        ) in
            OpenWearablesHealthSDK.shared.signIn(
                userId: userId,
                accessToken: accessToken,
                refreshToken: refreshToken,
                apiKey: apiKey
            )
            promise.resolve()
        }
        
        AsyncFunction("signOut") { (promise: Promise) in
            OpenWearablesHealthSDK.shared.signOut()
            promise.resolve()
        }
        
        Function("updateTokens") { (accessToken: String, refreshToken: String) in
            OpenWearablesHealthSDK.shared.updateTokens(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        }
        
        Function("restoreSession") {
            return OpenWearablesHealthSDK.shared.restoreSession()
        }
        
        Function("isSessionValid") {
            return OpenWearablesHealthSDK.shared.isSessionValid
        }
        
        // MARK: - HealthKit Authorization        
        AsyncFunction("requestAuthorization") { (types: [String], promise: Promise) in
            let healthTypes = types.compactMap { HealthDataType(rawValue: $0) }
            OpenWearablesHealthSDK.shared.requestAuthorization(types: healthTypes) { success in
                promise.resolve(success)
            }
        }
        

        AsyncFunction("getDailyStepTotals") { (daysBack: Int, promise: Promise) in
            let requestedDays = min(max(daysBack, 1), 90)
            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)

            guard
                let stepType = HKObjectType.quantityType(
                    forIdentifier: .stepCount
                ),
                let startDate = calendar.date(
                    byAdding: .day,
                    value: -(requestedDays - 1),
                    to: todayStart
                ),
                let endDate = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: todayStart
                )
            else {
                promise.resolve([])
                return
            }

            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate
            )

            var interval = DateComponents()
            interval.day = 1

            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: todayStart,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    promise.reject(error)
                    return
                }

                guard let collection else {
                    promise.resolve([])
                    return
                }

                let formatter = DateFormatter()
                formatter.calendar = calendar
                formatter.locale = Locale(
                    identifier: "en_US_POSIX"
                )
                formatter.timeZone = calendar.timeZone
                formatter.dateFormat = "yyyy-MM-dd"

                var totals: [[String: Any]] = []

                collection.enumerateStatistics(
                    from: startDate,
                    to: endDate
                ) { statistics, _ in
                    guard
                        statistics.startDate <= now,
                        let quantity =
                            statistics.sumQuantity()
                    else {
                        return
                    }

                    let secondsFromGMT =
                        calendar.timeZone.secondsFromGMT(
                            for: statistics.startDate
                        )

                    let sign =
                        secondsFromGMT >= 0
                            ? "+"
                            : "-"

                    let absoluteSeconds =
                        abs(secondsFromGMT)

                    let hours =
                        absoluteSeconds / 3600

                    let minutes =
                        (
                            absoluteSeconds % 3600
                        ) / 60

                    let zoneOffset = String(
                        format: "%@%02d:%02d",
                        sign,
                        hours,
                        minutes
                    )

                    totals.append([
                        "localDate":
                            formatter.string(
                                from: statistics.startDate
                            ),
                        "value":
                            quantity.doubleValue(
                                for: HKUnit.count()
                            ),
                        "zoneOffset":
                            zoneOffset
                    ])
                }

                promise.resolve(totals)
            }

            self.healthStore.execute(query)
        }

        // MARK: - Sync    
        Function("setSyncInterval") { (minutes: Double) in } // (not implemented in iOS SDK)
            
        AsyncFunction("startBackgroundSync") { (syncDaysBack: Int?, promise: Promise) in
            OpenWearablesHealthSDK.shared.startBackgroundSync(syncDaysBack: syncDaysBack) { started in
                promise.resolve(started)
            }
        }
        
        AsyncFunction("stopBackgroundSync") { (promise: Promise) in
            OpenWearablesHealthSDK.shared.stopBackgroundSync()
            promise.resolve()
        }
        
        AsyncFunction("syncNow") { (promise: Promise) in
            OpenWearablesHealthSDK.shared.syncNow {
                promise.resolve()
            }
        }
        
        AsyncFunction("resumeSync") { (promise: Promise) in
            OpenWearablesHealthSDK.shared.resumeSync { resumed in
                promise.resolve(resumed)
            }
        }
        
        Function("isSyncActive") {
            return OpenWearablesHealthSDK.shared.isSyncActive
        }
        
        Function("getSyncStatus") {
            return OpenWearablesHealthSDK.shared.getSyncStatus()
        }
        
        Function("resetAnchors") {
            OpenWearablesHealthSDK.shared.resetAnchors()
        }
        
        Function("getStoredCredentials") {
            return OpenWearablesHealthSDK.shared.getStoredCredentials()
        }

        // MARK: - Providers (not implemented in iOS SDK)        
        Function("getAvailableProviders") { return [] }
        
        Function("setProvider") { }

        // MARK: - Logs
        Function("setLogLevel") { (levelId: Int) in
            let level = OWLogLevel(rawValue: levelId) ?? .debug
            OpenWearablesHealthSDK.shared.setLogLevel(level)
        }

        Function("getLogLevel") {
            return OpenWearablesHealthSDK.shared.logLevel.rawValue
        }
    }
}