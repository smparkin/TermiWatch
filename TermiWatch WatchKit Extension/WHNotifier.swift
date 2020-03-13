import CoreLocation
import Foundation
import PMKCoreLocation
import PMKFoundation
import PromiseKit

func WHURL() -> URL {
  return URL(
    string: "https://thewhitehat.club/api/v1/status"
  )!
}

let disableCache: (URLSessionConfiguration) -> Void = {
  $0.requestCachePolicy = .reloadIgnoringLocalCacheData
  $0.urlCache = nil
}

struct WHResponse: Codable {
  struct MainResponse: Codable {
    let status: String
  }

  let data: MainResponse
}

func WHStatus()
  -> Promise<String> {
  return Promise { seal in
    let sessionConfig = URLSessionConfiguration.default
    disableCache(sessionConfig)

    URLSession(configuration: sessionConfig).dataTask(
      .promise,
      with: WHURL()
    ).compactMap {
        try JSONDecoder().decode(WHResponse.self, from: $0.data)
    }.done {
      let whstatus = $0.data.status

      seal.fulfill(whstatus)
    }.catch {
      print("Error:", $0)
    }
  }
}

public class WHNotifier {
  public static let StatusDidChangeNotification = Notification.Name(
    rawValue: "WHNotifier.StatusDidChangeNotification"
  )

  public static let shared = WHNotifier()
  private init() {}

  public private(set) var status: String?
  private var timer: Timer?

  public var isStarted: Bool {
    return timer != nil && timer!.isValid
  }

  public func start(withTimeInterval interval: TimeInterval = 600) {
    timer?.invalidate()

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in
        CLLocationManager.requestLocation().lastValue.then {_ in
        WHStatus()
      }.done { currentStatus in
        if currentStatus == self?.status {
          return
        }

        self?.status = currentStatus

        NotificationCenter.default.post(
          Notification(
            name: WHNotifier.StatusDidChangeNotification,
            object: self?.status,
            userInfo: nil
          )
        )
      }.catch {
        print("Error:", $0.localizedDescription)
      }
    }

    timer!.fire()
  }

  public func stop() {
    timer?.invalidate()
    timer = nil
  }
}
