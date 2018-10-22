import Foundation

@objc(WMFReachabilityNotifier) public class ReachabilityNotifier: NSObject {
    private let host: String
    
    // `queue.sync {}` is used throughout to ensure `queue` never captures `self`
    // capturing `self` in a block on `queue` could cause a deadlock on deinit
    private let queue: DispatchQueue
    
    private let callback: (Bool, SCNetworkReachabilityFlags) -> Void

    private var reachability: SCNetworkReachability?
    private var _flags: SCNetworkReachabilityFlags = [.reachable]
    private var _isReachable: Bool = true
    
    @objc(initWithHost:callback:) public required init(_ host: String, _ callback: @escaping (Bool, SCNetworkReachabilityFlags) -> Void) {
        self.host = host
        self.queue = DispatchQueue(label: "\(host).reachability.\(UUID().uuidString)")
        self.callback = callback
    }
    
    deinit {
        queue.sync {
            _stop()
        }
    }
    
    @objc public var flags: SCNetworkReachabilityFlags {
        var currentFlags: SCNetworkReachabilityFlags = []
        queue.sync {
            currentFlags = _flags
        }
        return currentFlags
    }
    
    @objc public var isReachable: Bool {
        var currentReachable: Bool = false
        queue.sync {
            currentReachable = _isReachable
        }
        return currentReachable
    }
    
    @objc public func start() {
        queue.sync {
            _start()
        }
    }
    
    @objc public func stop() {
        queue.sync {
            _stop()
        }
    }
    
    private func _start() {
        guard self.reachability == nil else {
            return
        }
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, self.host) else {
            return
        }
        SCNetworkReachabilitySetDispatchQueue(reachability, self.queue)
        let info = Unmanaged.passUnretained(self).toOpaque()
        var context = SCNetworkReachabilityContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)
        SCNetworkReachabilitySetCallback(reachability, { (reachability, flags, info) in
            guard let info = info else {
                return
            }
            let reachabilityNotifier = Unmanaged<ReachabilityNotifier>.fromOpaque(info).takeUnretainedValue()
            reachabilityNotifier._flags = flags
            reachabilityNotifier.callback(flags.contains(.reachable), flags)
        }, &context)
        self.reachability = reachability
    }
    
    private func _stop() {
        guard let reachability = self.reachability else {
            return
        }
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        self.reachability = nil
    }
}