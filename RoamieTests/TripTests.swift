import XCTest
import SwiftData
@testable import Roamie

final class TripTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([Trip.self, Waypoint.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDown() {
        container = nil
    }

    // MARK: - Trip model

    func testTripDefaultValues() {
        let trip = Trip()
        XCTAssertFalse(trip.id.uuidString.isEmpty)
        XCTAssertEqual(trip.mapStyle, .terrain)
        XCTAssertEqual(trip.characterAssetName, CharacterAsset.carFlag.assetName)
        XCTAssertTrue(trip.waypoints.isEmpty)
    }

    func testHasAnyPhotos() {
        let trip = Trip(title: "Test")
        let wp1 = Waypoint(order: 0, name: "北京", latitude: 39.9, longitude: 116.4)
        let wp2 = Waypoint(order: 1, name: "上海", latitude: 31.2, longitude: 121.5)
        trip.waypoints = [wp1, wp2]
        XCTAssertFalse(trip.hasAnyPhotos)

        wp1.photoFileNames = ["photo1.jpg"]
        XCTAssertTrue(trip.hasAnyPhotos)
    }

    // MARK: - Waypoint model

    func testWaypointCoordinate() {
        let wp = Waypoint(order: 0, name: "北京", latitude: 39.9042, longitude: 116.4074)
        XCTAssertEqual(wp.coordinate.latitude, 39.9042, accuracy: 0.0001)
        XCTAssertEqual(wp.coordinate.longitude, 116.4074, accuracy: 0.0001)
    }

    func testWaypointHasPhotos() {
        let wp = Waypoint(order: 0, name: "成都", latitude: 30.5, longitude: 104.1)
        XCTAssertFalse(wp.hasPhotos)
        wp.photoFileNames = ["a.jpg"]
        XCTAssertTrue(wp.hasPhotos)
    }

    func testOrderedWaypoints() {
        let trip = Trip(title: "顺序测试")
        let wp0 = Waypoint(order: 0, name: "A", latitude: 0, longitude: 0)
        let wp1 = Waypoint(order: 1, name: "B", latitude: 1, longitude: 1)
        let wp2 = Waypoint(order: 2, name: "C", latitude: 2, longitude: 2)
        // Insert out of order
        trip.waypoints = [wp2, wp0, wp1]
        let ordered = trip.orderedWaypoints
        XCTAssertEqual(ordered.map { $0.name }, ["A", "B", "C"])
    }

    // MARK: - MKCoordinateRegion fitting

    func testRegionFittingSinglePoint() {
        let region = MKCoordinateRegion.fitting(
            coordinates: [CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)]
        )
        XCTAssertEqual(region.center.latitude, 39.9, accuracy: 0.01)
    }

    func testRegionFittingMultiplePoints() {
        let coords = [
            CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
            CLLocationCoordinate2D(latitude: 31.2, longitude: 121.5)
        ]
        let region = MKCoordinateRegion.fitting(coordinates: coords)
        // Center should be roughly between Beijing and Shanghai
        XCTAssertEqual(region.center.latitude, 35.55, accuracy: 1.0)
        XCTAssertEqual(region.center.longitude, 118.95, accuracy: 1.0)
        XCTAssertGreaterThan(region.span.latitudeDelta, 0)
    }

    // MARK: - Arc length table

    func testArcLengthTableMonotonicallyIncreasing() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 200, y: 100)]
        let table = buildArcLengthTable(from: points)
        XCTAssertFalse(table.isEmpty)
        for i in 1..<table.count {
            XCTAssertGreaterThanOrEqual(table[i].arcLength, table[i-1].arcLength)
        }
    }

    func testInterpolationAtBoundaries() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]
        let table = buildArcLengthTable(from: points)
        let start = interpolate(table: table, at: 0)
        let end = interpolate(table: table, at: table.last!.arcLength)
        XCTAssertEqual(start?.position.x ?? 99, 0, accuracy: 1)
        XCTAssertEqual(end?.position.x ?? 0, 100, accuracy: 1)
    }
}

// Allow importing Roamie types in tests
import CoreLocation
import MapKit
