import WidgetKit
import SwiftUI

@main
struct CoincideWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoincideWidget()
    }
}

struct CoincideWidget: Widget {
    let kind = "CoincideWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZoneTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Coincide")
        .description("See the current time across the zones you track.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
