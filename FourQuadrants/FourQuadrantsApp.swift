//
//  FourQuadrantsApp.swift
//  FourQuadrants
//
//  Created by 唐颢宸 on 27/01/2026.
//

import SwiftUI

import SwiftData

@main
struct FourQuadrantsApp: App {
    init() {
        print("📁 数据库路径: \(URL.applicationSupportDirectory.path(percentEncoded: false))")
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
