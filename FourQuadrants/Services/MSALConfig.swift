import Foundation

struct MSALConfig {
    // ⚠️ 必填：请在 Azure Portal 注册后替换此 ID
    // Register here: https://portal.azure.com/#blade/Microsoft_AAD_PCM/AppRegistrationBlade
    static let clientID = "ENTER_YOUR_CLIENT_ID_HERE"
    
    // 你的 Bundle ID
    #if DEBUG
    static let bundleID = "com.fulu.FourQuadrants.dev"
    #else
    static let bundleID = "com.fulu.FourQuadrants"
    #endif
    
    // Redirect URI Scheme: msauth.$(PRODUCT_BUNDLE_IDENTIFIER)://auth
    static let redirectUri = "msauth.\(bundleID)://auth"
    
    // Microsoft Graph Scopes
    static let scopes = ["User.Read", "Tasks.ReadWrite"]
    
    // Interaction settings
    static let authority = "https://login.microsoftonline.com/common"
}
