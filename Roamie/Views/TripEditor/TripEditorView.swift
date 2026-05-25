import SwiftUI
import SwiftData
import PhotosUI

struct TripEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let trip: Trip

    @State private var viewModel = TripEditorViewModel()
    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("行程名称") {
                    TextField("给这段旅程起个名字", text: $title)
                        .onChange(of: title) { _, newValue in
                            trip.title = newValue
                        }
                }

                Section("风格设置") {
                    MapStylePickerView(selected: Binding(
                        get: { trip.mapStyle },
                        set: { trip.mapStyle = $0 }
                    ))
                    CharacterPickerView(selected: Binding(
                        get: { trip.characterAssetName },
                        set: { trip.characterAssetName = $0 }
                    ))
                }

                Section {
                    ForEach(trip.orderedWaypoints) { waypoint in
                        WaypointRowView(
                            waypoint: waypoint,
                            onAddPhotos: {
                                viewModel.selectedWaypointForPhotos = waypoint
                                viewModel.isPickingPhotos = true
                            },
                            onRemovePhoto: { file in
                                viewModel.removePhoto(fileName: file, from: waypoint, context: context)
                            }
                        )
                    }
                    .onMove { source, dest in
                        viewModel.moveWaypoints(in: trip, from: source, to: dest, context: context)
                    }
                    .onDelete { indices in
                        let ordered = trip.orderedWaypoints
                        for i in indices { viewModel.deleteWaypoint(ordered[i], from: trip, context: context) }
                    }

                    Button {
                        viewModel.isShowingSearch = true
                    } label: {
                        Label("添加城市", systemImage: "plus.circle")
                    }
                } header: {
                    HStack {
                        Text("行程站点")
                        Spacer()
                        EditButton()
                    }
                }

                if trip.waypoints.count >= 2 {
                    Section {
                        Button {
                            viewModel.isShowingMapPreview = true
                        } label: {
                            Label("预览路线地图", systemImage: "map")
                        }
                        Button {
                            viewModel.isShowingAnimation = true
                        } label: {
                            Label("生成旅行动图", systemImage: "film.stack")
                        }
                        .tint(.orange)
                    }
                }

                if let err = viewModel.errorMessage {
                    ErrorBanner(message: err)
                }
            }
            .navigationTitle(title.isEmpty ? "新建旅程" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear { title = trip.title }
            .sheet(isPresented: $viewModel.isShowingSearch) {
                WaypointSearchSheet(nextOrder: trip.waypoints.count) { waypoint in
                    viewModel.addWaypoint(waypoint, to: trip, context: context)
                }
            }
            .sheet(isPresented: $viewModel.isShowingMapPreview) {
                RouteMapView(trip: trip)
            }
            .fullScreenCover(isPresented: $viewModel.isShowingAnimation) {
                AnimationPreviewView(trip: trip)
            }
            .photosPicker(
                isPresented: $viewModel.isPickingPhotos,
                selection: $viewModel.photoPickerItems,
                maxSelectionCount: 9,
                matching: .images
            )
            .onChange(of: viewModel.photoPickerItems) { _, items in
                if let waypoint = viewModel.selectedWaypointForPhotos, !items.isEmpty {
                    viewModel.processPickedPhotos(for: waypoint, context: context)
                }
            }
        }
    }
}
