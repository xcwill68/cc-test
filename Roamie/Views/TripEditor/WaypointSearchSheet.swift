import SwiftUI
import MapKit

struct WaypointSearchSheet: View {
    let nextOrder: Int
    let onSelect: (Waypoint) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = WaypointSearchViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Use my location
                Section {
                    Button {
                        viewModel.locateAndAdd(nextOrder: nextOrder) { waypoint in
                            onSelect(waypoint)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundStyle(.blue)
                            Text("使用当前位置")
                            Spacer()
                            if viewModel.isLocating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isLocating)
                }

                // Search results
                if !viewModel.searchService.results.isEmpty {
                    Section("搜索结果") {
                        ForEach(viewModel.searchService.results, id: \.self) { item in
                            Button {
                                let waypoint = viewModel.searchService.makeWaypoint(
                                    from: item, order: nextOrder
                                )
                                onSelect(waypoint)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "未知")
                                        .foregroundStyle(.primary)
                                        .font(.body)
                                    Text([item.placemark.locality,
                                          item.placemark.country]
                                        .compactMap { $0 }
                                        .joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else if viewModel.searchService.isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if !viewModel.queryText.isEmpty {
                    ContentUnavailableView.search(text: viewModel.queryText)
                }

                if let err = viewModel.errorMessage {
                    ErrorBanner(message: err)
                }
            }
            .navigationTitle("添加城市")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.queryText, prompt: "搜索城市或地点")
            .onChange(of: viewModel.queryText) { _, _ in viewModel.search() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
