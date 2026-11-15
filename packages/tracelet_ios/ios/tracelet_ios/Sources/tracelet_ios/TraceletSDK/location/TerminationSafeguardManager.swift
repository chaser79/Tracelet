import CoreLocation

public final class TerminationSafeguardManager: NSObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?

    public override init() {}

    public func start() {
        guard locationManager == nil else { return }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.startMonitoringSignificantLocationChanges()
        locationManager = manager
    }

    public func stop() {
        locationManager?.stopMonitoringSignificantLocationChanges()
        locationManager = nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
