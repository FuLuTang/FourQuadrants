import Foundation

struct MSALConfig {
    static let clientID = "e39c7bc1-88ee-4a9f-9e02-b41078368e03"
    
    // 你的 Bundle ID
#if os(macOS) && DEBUG
    static let bundleID = "com.fulu.FourQuadrants.macOS.dev"
#elseif os(macOS)
    static let bundleID = "com.fulu.FourQuadrants.macOS"
#elseif DEBUG
    static let bundleID = "com.fulu.FourQuadrants.dev"
#else
    static let bundleID = "com.fulu.FourQuadrants"
    #endif
    
    // Redirect URI Scheme: msauth.$(PRODUCT_BUNDLE_IDENTIFIER)://auth
    static let redirectUri = "msauth.\(bundleID)://auth"
    
    // Microsoft Graph Scopes
    static let scopes = ["User.Read", "Tasks.ReadWrite"]
    
    // Interaction settings
    static let authority = "https://login.microsoftonline.com/consumers"
}
