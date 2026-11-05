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
    
    // The native Mac target keeps its own bundle ID, while reusing the iOS
    // redirect URIs already registered in Microsoft Entra.
#if os(macOS) && DEBUG
    static let redirectUri = "msauth.com.fulu.FourQuadrants.dev://auth"
#elseif os(macOS)
    static let redirectUri = "msauth.com.fulu.FourQuadrants://auth"
#else
    static let redirectUri = "msauth.\(bundleID)://auth"
#endif
    
    // Microsoft Graph Scopes
    static let scopes = ["User.Read", "Tasks.ReadWrite"]
    
    // Interaction settings
    static let authority = "https://login.microsoftonline.com/consumers"
}
