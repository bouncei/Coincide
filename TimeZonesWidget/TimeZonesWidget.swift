import WidgetKit
import SwiftUI

@main
struct TimeZonesWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimeZonesWidget()
    }
}

struct TimeZonesWidget: Widget {
    let kind = "TimeZonesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZoneTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Time Zones")
        .description("See the current time across the zones you track.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
