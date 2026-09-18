//
//  DeviceHardware.swift
//  AppUtils
//

import Foundation

/// Hardware identity of the device, shared by the apps instead of a private copy in each.
public enum DeviceHardware {

    /// Hardware identifier (`iPhone14,2`, `arm64` on the simulator), not the marketing name.
    ///
    /// Analytics and support correlate failures and prices with the exact model, which
    /// `UIDevice.model` ("iPhone") cannot tell apart.
    public static var identifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return Mirror(reflecting: systemInfo.machine).children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}
