import SwiftUI

// MARK: - Main log view

struct APICallLogView: View {
    @ObservedObject var logger: APICallLogger
    @State private var selectedEntry: APILogEntry?

    private var providers: [(name: String, count: Int, hasRecentError: Bool)] {
        var seen: [String: (count: Int, hasError: Bool)] = [:]
        for entry in logger.entries {
            let existing = seen[entry.provider] ?? (count: 0, hasError: false)
            seen[entry.provider] = (
                count: existing.count + 1,
                hasError: existing.hasError || entry.isFailed
            )
        }
        return seen.map { (name: $0.key, count: $0.value.count, hasRecentError: $0.value.hasError) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            if !providers.isEmpty { providerSummary }
            logTable
        }
        .sheet(item: $selectedEntry) { APILogDetailView(entry: $0) }
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("API Log")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary.opacity(0.75))

            HStack(spacing: 3) {
                Text("\(logger.entries.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
                Text("newest first")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())

            Spacer()

            if logger.isPaused {
                Text("PAUSED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }

            Button { logger.isPaused.toggle() } label: {
                Label(logger.isPaused ? "Resume" : "Pause",
                      systemImage: logger.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(logger.isPaused ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Button { logger.clear() } label: {
                Label("Clear", systemImage: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear all entries")
        }
    }

    // MARK: Provider summary pills

    private var providerSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(providers, id: \.name) { p in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(p.hasRecentError ? Color.red : Color.green)
                            .frame(width: 5, height: 5)
                        Text(p.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.8))
                        Text("\(p.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: Table

    private var logTable: some View {
        VStack(spacing: 0) {
            columnHeader
            Divider().opacity(0.15)

            if logger.entries.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(logger.entries) { entry in
                            LogRowView(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedEntry = entry }
                            Divider().opacity(0.07)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            headerCell("Time",     width: 62)
            headerCell("Status",   width: 46)
            headerCell("Provider", width: 62)
            headerCell("Endpoint", width: nil)
            headerCell("ms",       width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.04))
    }

    @ViewBuilder
    private func headerCell(_ label: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        let text = Text(label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.secondary.opacity(0.6))
            .textCase(.uppercase)
            .tracking(0.4)
        if let width {
            text.frame(width: width, alignment: alignment)
        } else {
            text.frame(maxWidth: .infinity, alignment: alignment)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: logger.isPaused ? "pause.circle" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.4))
            Text(logger.isPaused ? "Paused — resume to capture calls" : "Waiting for API calls…")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
    }
}

// MARK: - Log row

private struct LogRowView: View {
    let entry: APILogEntry
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Time — HH:mm:ss
            Text(timeString(entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .frame(width: 62, alignment: .leading)

            // Status badge
            statusBadge
                .frame(width: 46, alignment: .leading)

            // Provider
            Text(entry.provider)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(1)
                .frame(width: 62, alignment: .leading)

            // Endpoint path
            Text(entry.urlPath)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Duration
            Text("\(entry.durationMs)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(durationColor)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(hovered ? Color.white.opacity(0.05) : Color.clear)
        .onHover { hovered = $0 }
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            Text(entry.statusLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(statusColor)
        }
    }

    private var statusColor: Color {
        guard let code = entry.statusCode else { return .red }
        switch code {
        case 200...299: return .green
        case 429:       return .orange
        default:        return .red
        }
    }

    private var durationColor: Color {
        switch entry.durationMs {
        case ..<200:    return .secondary.opacity(0.6)
        case ..<800:    return .yellow.opacity(0.8)
        default:        return .orange
        }
    }

    private func timeString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return String(format: "%02d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }
}

// MARK: - Detail sheet

struct APILogDetailView: View {
    let entry: APILogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        statusPill
                        Text(entry.provider)
                            .font(.system(size: 14, weight: .bold))
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(entry.method)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(entry.url)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding(16)

            Divider().opacity(0.15)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // Request / Response meta side by side
                    HStack(alignment: .top, spacing: 14) {
                        detailCard("Request") {
                            metaRow("Method",    value: entry.method)
                            metaRow("Time",      value: fullTimestamp(entry.timestamp))
                        }
                        detailCard("Response") {
                            metaRow("Status",   value: entry.statusLabel,
                                    color: statusColor)
                            metaRow("Duration", value: "\(entry.durationMs) ms",
                                    color: durationColor)
                            if let err = entry.error {
                                metaRow("Error", value: err, color: .red)
                            }
                        }
                    }

                    // Response body
                    if let preview = entry.responsePreview {
                        detailCard("Response Body") {
                            Text(preview)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.primary.opacity(0.85))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11))
    }

    // MARK: Helpers

    private var statusColor: Color {
        guard let code = entry.statusCode else { return .red }
        switch code {
        case 200...299: return .green
        case 429:       return .orange
        default:        return .red
        }
    }

    private var durationColor: Color {
        switch entry.durationMs {
        case ..<200: return .green
        case ..<800: return .yellow
        default:     return .orange
        }
    }

    private var statusPill: some View {
        Text(entry.statusLabel)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func detailCard<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func metaRow(_ label: String, value: String, color: Color = .primary) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(color.opacity(0.9))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fullTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm:ss a"
        return f.string(from: date)
    }
}
