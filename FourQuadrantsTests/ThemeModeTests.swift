import Testing
import SwiftUI
@testable import FourQuadrants

struct ThemeModeTests {
    @Test func testThemeModeCycle() async throws {
        #expect(ThemeMode.auto.next() == .light)
        #expect(ThemeMode.light.next() == .dark)
        #expect(ThemeMode.dark.next() == .auto)
    }
    
    @Test func testThemeModeColorSchemeMapping() async throws {
        #expect(ThemeMode.auto.colorSchemePreference == nil)
        #expect(ThemeMode.light.colorSchemePreference == .light)
        #expect(ThemeMode.dark.colorSchemePreference == .dark)
    }
}
