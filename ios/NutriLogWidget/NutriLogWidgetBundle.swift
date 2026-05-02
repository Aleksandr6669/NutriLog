//
//  NutriLogWidgetBundle.swift
//  NutriLogWidget
//
//  Created by Александр Рыженков on 02.05.2026.
//

import WidgetKit
import SwiftUI

@main
struct NutriLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        NutriLogWidget()
        NutriLogWidgetControl()
        NutriLogWidgetLiveActivity()
    }
}
