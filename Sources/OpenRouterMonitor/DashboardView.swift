import Charts
import SwiftUI
import OpenRouterMonitorCore

struct DashboardView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    let snapshot = store.latestSnapshot
                    let activitySummary = store.activityUsageSummary

                    BalanceCard(snapshot: snapshot, formatter: store.moneyFormatter)
                    UsageSummaryGrid(
                        snapshot: snapshot,
                        activitySummary: activitySummary,
                        formatter: store.moneyFormatter
                    )
                    SpendTrendView(
                        summary: activitySummary,
                        warning: store.state.configuration.lastRefreshError,
                        formatter: store.moneyFormatter
                    )

                    HStack(alignment: .top, spacing: 12) {
                        BYOKUsageView(
                            summary: activitySummary,
                            warning: store.state.configuration.lastRefreshError,
                            formatter: store.moneyFormatter
                        )
                        BurnDownView(summary: store.burnDownSummary, formatter: store.moneyFormatter)
                    }

                    APIKeysOverviewView(
                        keys: store.sortedAPIKeys,
                        warning: store.state.configuration.lastRefreshError,
                        formatter: store.moneyFormatter
                    )
                    ModelBreakdownView(
                        models: store.topModelSummaries,
                        usesManagementKey: store.state.profile.isManagementKey,
                        warning: store.state.configuration.lastRefreshError,
                        formatter: store.moneyFormatter
                    )
                }
                .padding(18)
            }

            Divider()
                .overlay(Color.white.opacity(0.06))

            actionRow
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
        }
        .frame(width: 408, height: 760)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.10),
                    Color(red: 0.10, green: 0.12, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .tint(Brand.accent)
        .onAppear {
            store.startAutoRefresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                BrandIcon(size: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text("OpenRouter Monitor")
                        .font(.headline)
                    Text(store.state.profile.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(store.state.configuration.lastRefreshStatus)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(store.state.configuration.lastRefreshStatus == "Connected" ? Brand.accentSecondary.opacity(0.18) : Color.secondary.opacity(0.14))
                    )
                    .foregroundStyle(store.state.configuration.lastRefreshStatus == "Connected" ? Brand.accentSecondary : .secondary)
            }

            if let capturedAt = store.latestSnapshot?.capturedAt {
                Text("Last updated \(capturedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let error = store.state.configuration.lastRefreshError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Add an API key in Settings, then refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)

            Button {
                NSWorkspace.shared.open(URL(string: "https://openrouter.ai/activity")!)
            } label: {
                Label("Dashboard", systemImage: "safari")
            }

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Spacer()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .buttonStyle(.bordered)
    }
}

private struct BalanceCard: View {
    let snapshot: UsageSnapshot?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Balance")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "creditcard")
                    .foregroundStyle(Brand.accent)
            }

            if let snapshot, let total = snapshot.totalCredits, let used = snapshot.accountTotalUsage {
                let remaining = snapshot.accountRemainingCredits ?? 0
                HStack(alignment: .firstTextBaseline) {
                    Text(formatter.string(fromUSDCredits: remaining))
                        .font(.title2.weight(.semibold))
                    Text("remaining")
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ProgressView(value: max(0, remaining), total: max(total, 0.01))
                    .tint(Brand.accentSecondary)

                HStack {
                    Text("\(formatter.string(fromUSDCredits: used)) used")
                    Spacer()
                    Text("\(formatter.string(fromUSDCredits: total)) credits")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let snapshot, let remaining = snapshot.keyLimitRemaining {
                Text(formatter.string(fromUSDCredits: remaining))
                    .font(.title2.weight(.semibold))
                Text("remaining for this API key limit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Account credit balance needs a management-capable key.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .brandedPanel()
    }
}

private struct UsageSummaryGrid: View {
    let snapshot: UsageSnapshot?
    let activitySummary: ActivityUsageSummary?
    let formatter: MoneyFormatter

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                MetricTile(title: firstTitle, value: firstValue)
                MetricTile(title: secondTitle, value: secondValue)
            }
            GridRow {
                MetricTile(title: thirdTitle, value: thirdValue)
                MetricTile(title: fourthTitle, value: fourthValue)
            }
        }
    }

    private var firstTitle: String {
        activitySummary == nil ? "Today" : "Latest Day"
    }

    private var firstValue: String {
        if let activitySummary {
            return money(activitySummary.latestDayUsage)
        }
        return money(snapshot?.usageDailyIncludingBYOK)
    }

    private var secondTitle: String {
        activitySummary == nil ? "This Week" : "Last 7 Days"
    }

    private var secondValue: String {
        if let activitySummary {
            return money(activitySummary.last7DaysUsage)
        }
        return money(snapshot?.usageWeeklyIncludingBYOK)
    }

    private var thirdTitle: String {
        activitySummary == nil ? "This Month" : "Last 30 Days"
    }

    private var thirdValue: String {
        if let activitySummary {
            return money(activitySummary.last30DaysUsage)
        }
        return money(snapshot?.usageMonthlyIncludingBYOK)
    }

    private var fourthTitle: String {
        activitySummary == nil ? "All Time" : "30d Requests"
    }

    private var fourthValue: String {
        if let activitySummary {
            return activitySummary.last30DaysRequests.formatted()
        }
        return money(snapshot?.usageAllTimeIncludingBYOK)
    }

    private func money(_ value: Double?) -> String {
        guard let value else { return "-" }
        return formatter.string(fromUSDCredits: value)
    }
}

private struct SpendTrendView: View {
    let summary: ActivityUsageSummary?
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Spend Trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let summary {
                    Text("\(summary.trend.count)d")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let summary, !summary.trend.isEmpty {
                Chart(summary.trend) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Spend", point.totalUsage)
                    )
                    .foregroundStyle(Brand.accent.opacity(0.55))
                    .cornerRadius(3)

                    if point.byokUsage > 0 {
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("BYOK", point.byokUsage)
                        )
                        .foregroundStyle(Brand.accentSecondary.opacity(0.85))
                        .cornerRadius(3)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatter.string(fromUSDCredits: amount))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 118)

                HStack {
                    Text("Latest \(formatter.string(fromUSDCredits: summary.latestDayUsage))")
                    Spacer()
                    Text("\(summary.last30DaysTokens.formatted(.number.notation(.compactName))) tokens / 30d")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                EmptyPanelMessage(emptyMessage)
            }
        }
        .padding(14)
        .brandedPanel()
    }

    private var emptyMessage: String {
        if let warning, warning.contains("Model activity unavailable") {
            return warning
        }
        return "Activity data is required for the spend trend widget."
    }
}

private struct BYOKUsageView: View {
    let summary: ActivityUsageSummary?
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BYOK Usage")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "person.crop.rectangle.stack")
                    .foregroundStyle(Brand.accent)
            }

            if let summary, summary.last30DaysUsage > 0 {
                SmallMetric(label: "30d BYOK", value: formatter.string(fromUSDCredits: summary.last30DaysByokUsage))
                SmallMetric(label: "30d OpenRouter", value: formatter.string(fromUSDCredits: summary.last30DaysOpenRouterUsage))
                SmallMetric(label: "BYOK Share", value: shareString(summary: summary))
                SmallMetric(label: "Latest BYOK", value: formatter.string(fromUSDCredits: summary.latestDayByokUsage))
            } else {
                EmptyPanelMessage(emptyMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .brandedPanel()
    }

    private func shareString(summary: ActivityUsageSummary) -> String {
        let share = summary.last30DaysByokUsage / max(summary.last30DaysUsage, 0.000_001)
        return "\((share * 100).formatted(.number.precision(.fractionLength(0))))%"
    }

    private var emptyMessage: String {
        if let warning, warning.contains("Model activity unavailable") {
            return warning
        }
        return "No recent BYOK activity returned."
    }
}

private struct BurnDownView: View {
    let summary: CreditBurnDownSummary?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Credit Burn-Down")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "hourglass.bottomhalf.filled")
                    .foregroundStyle(Brand.accent)
            }

            if let summary {
                Text("\(summary.estimatedDaysRemaining.formatted(.number.precision(.fractionLength(1)))) days")
                    .font(.title3.weight(.semibold))
                SmallMetric(label: "Avg / day", value: formatter.string(fromUSDCredits: summary.averageDailySpend))
                SmallMetric(label: "Remaining", value: formatter.string(fromUSDCredits: summary.remainingCredits))
                SmallMetric(label: "Exhaustion", value: summary.exhaustionDate.formatted(date: .abbreviated, time: .omitted))
            } else {
                EmptyPanelMessage("Burn-down appears when credits and recent activity are both available.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .brandedPanel()
    }
}

private struct APIKeysOverviewView: View {
    let keys: [OpenRouterAPIKey]
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Per-Key Spend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(keys.count) keys")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if keys.isEmpty {
                EmptyPanelMessage(emptyMessage)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(keys.prefix(4))) { key in
                        APIKeyRow(key: key, formatter: formatter)
                    }
                }
            }
        }
        .padding(14)
        .brandedPanel()
    }

    private var emptyMessage: String {
        if let warning, warning.contains("API key list unavailable") {
            return warning
        }
        return "Management key access is required to list API keys."
    }
}

private struct APIKeyRow: View {
    let key: OpenRouterAPIKey
    let formatter: MoneyFormatter

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(key.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    if let statusText {
                        Text(statusText)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(statusColor.opacity(0.18)))
                            .foregroundStyle(statusColor)
                    }
                }

                Text("Day \(formatter.string(fromUSDCredits: key.totalUsageDaily)) · Month \(formatter.string(fromUSDCredits: key.totalUsageMonthly))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(limitRemainingText)
                    .font(.caption.weight(.semibold))
                Text("remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String? {
        if key.disabled {
            return "Disabled"
        }
        if let expirationDate = key.expirationDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            if days >= 0 && days <= 14 {
                return "\(days)d left"
            }
        }
        return nil
    }

    private var statusColor: Color {
        if key.disabled {
            return .red
        }
        return .orange
    }

    private var limitRemainingText: String {
        guard let limitRemaining = key.limitRemaining else { return "-" }
        return formatter.string(fromUSDCredits: limitRemaining)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .brandedPanel()
    }
}

private struct SmallMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct EmptyPanelMessage: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ModelBreakdownView: View {
    let models: [ModelUsageSummary]
    let usesManagementKey: Bool
    let warning: String?
    let formatter: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Model Breakdown")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chart.pie")
                    .foregroundStyle(Brand.accent)
            }

            if models.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(models) { model in
                        ModelUsageRow(model: model, formatter: formatter)
                    }
                }
            }
        }
        .padding(14)
        .brandedPanel()
    }

    private var emptyMessage: String {
        if let warning, warning.contains("Model activity unavailable") {
            return warning
        }
        if usesManagementKey {
            return "No model activity returned for the last 30 completed UTC days."
        }
        return "Enable a management-capable key in Settings to fetch OpenRouter activity grouped by model."
    }
}

private struct ModelUsageRow: View {
    let model: ModelUsageSummary
    let formatter: MoneyFormatter

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(model.requests) requests · \(formattedTokens)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(formatter.string(fromUSDCredits: model.usage))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var displayName: String {
        model.providerName.isEmpty ? model.model : "\(model.providerName) · \(model.model)"
    }

    private var formattedTokens: String {
        model.totalTokens.formatted(.number.notation(.compactName))
    }
}
