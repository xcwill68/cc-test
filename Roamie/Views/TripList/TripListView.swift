import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var appEnv
    @Query(sort: \Trip.modifiedAt, order: .reverse) private var trips: [Trip]
    @State private var viewModel = TripListViewModel()
    @State private var editingTrip: Trip?

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .navigationTitle("我的旅程")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let trip = Trip()
                        context.insert(trip)
                        editingTrip = trip
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(item: $editingTrip) { trip in
                TripEditorView(trip: trip)
            }
        }
        .tint(.orange)
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("🗺️")
                .font(.system(size: 64))
            Text("还没有旅程")
                .font(.title2.bold())
            Text("点击右上角 + 开始记录你的第一段旅途")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("创建第一段旅程") {
                let trip = Trip()
                context.insert(trip)
                editingTrip = trip
            }
                .buttonStyle(.borderedProminent)
        }
    }

    private var tripList: some View {
        List {
            ForEach(trips) { trip in
                NavigationLink {
                    TripEditorView(trip: trip)
                } label: {
                    TripCardView(trip: trip)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.delete(trip, from: context)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        viewModel.duplicate(trip, into: context)
                    } label: {
                        Label("复制行程", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        viewModel.delete(trip, from: context)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
