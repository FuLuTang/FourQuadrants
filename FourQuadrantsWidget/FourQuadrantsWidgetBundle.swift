//
//  FourQuadrantsWidgetBundle.swift
//  FourQuadrantsWidget
//
//  Created by 唐颢宸 on 28/01/2026.
//

import WidgetKit
import SwiftUI

@main
struct FourQuadrantsWidgetBundle: WidgetBundle {
    var body: some Widget {
        FourQuadrantsWidget()
        FourQuadrantsWidgetControl()
        FourQuadrantsWidgetLiveActivity()
    }
}
