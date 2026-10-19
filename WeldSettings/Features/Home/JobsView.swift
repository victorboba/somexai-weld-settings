import SwiftUI
import SwiftData
import UIKit

/// What was welded, on what, at what settings, and a photo of the bead.
///
/// A chart tells you where to start. The log tells you where you ended up — which is the thing
/// you actually want six months later when the same bracket comes back through the door.
struct JobsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JobEntry.date, order: .reverse) private var jobs: [JobEntry]

    @State private var showingSettings = false
    @State private var editingJob: JobEntry?
    @State private var newJobSelection: WeldSelection?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var grouped: [(day: Date, jobs: [JobEntry])] {
        let groups = Dictionary(grouping: jobs, by: \.day)
        return groups.keys.sorted(by: >).map { (day: $0, jobs: groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if jobs.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing logged yet", systemImage: "book.closed")
                    } description: {
                        Text("Set the bench up, weld it, then come back and record what you actually ran. A photo of the bead is worth more than the numbers.")
                    } actions: {
                        Button("Log a weld") { newJobSelection = WeldSelection() }
                            .buttonStyle(.borderedProminent)
                            .tint(.weldArc)
                    }
                } else {
                    List {
                        Section {
                            SummaryStrip(jobs: jobs)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                        ForEach(grouped, id: \.day) { group in
                            Section(group.day.formatted(date: .abbreviated, time: .omitted)) {
                                ForEach(group.jobs) { job in
                                    Button { editingJob = job } label: { JobRow(job: job) }
                                        .buttonStyle(.plain)
                                }
                                .onDelete { offsets in delete(offsets.map { group.jobs[$0] }) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Job log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BenchToolbar(showingSettings: $showingSettings)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { export(.pdf) } label: { Label("Weld record (PDF)", systemImage: "doc.richtext") }
                        Button { export(.csv) } label: { Label("Every weld as CSV", systemImage: "tablecells") }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(jobs.isEmpty)

                    Button { newJobSelection = WeldSelection() } label: {
                        Label("Log a weld", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingJob) { JobEditorView(job: $0, selection: $0.selection) }
            .sheet(item: Binding(get: { newJobSelection.map(SelectionBox.init) },
                                 set: { newJobSelection = $0?.selection })) { box in
                JobEditorView(job: nil, selection: box.selection)
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private enum ExportKind { case pdf, csv }

    private func export(_ kind: ExportKind) {
        do {
            let url = kind == .pdf ? try PDFExporter.exportWeldRecord(jobs) : try CSVExporter.exportJobs(jobs)
            exportFile = ExportFile(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func delete(_ toDelete: [JobEntry]) {
        for job in toDelete { context.delete(job) }
        try? context.save()
    }
}

/// A `WeldSelection` is a value, and `.sheet(item:)` wants an identity, so it gets one.
private struct SelectionBox: Identifiable {
    let selection: WeldSelection
    var id: String { selection.headline }
}

/// The header a job log earns: how much has been welded and how often it came out right first
/// time, which is the number that tells a welder whether their presets are any good.
private struct SummaryStrip: View {
    let jobs: [JobEntry]

    private var firstTry: Int { jobs.filter { $0.outcome == .firstTry }.count }

    var body: some View {
        HStack(spacing: 0) {
            stat("\(jobs.count)", "welds logged")
            Divider().frame(height: 34)
            stat("\(firstTry)", "right first try")
            Divider().frame(height: 34)
            stat("\(Set(jobs.map(\.processRaw)).count)", jobs.count == 0 ? "processes" : "processes used")
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.weldSteel, in: RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, 6)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.weldArc)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct JobRow: View {
    let job: JobEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let data = job.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: job.outcome.symbol)
                        .font(.caption)
                        .foregroundStyle(job.outcome == .firstTry ? Color.green : Color.weldArc)
                    Text(job.displayTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("\(job.process.shortName) · \(job.jobSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(job.settingsSummary)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.weldArc)
                    .fixedSize(horizontal: false, vertical: true)
                if !job.machineName.isEmpty {
                    Text(job.machineName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
