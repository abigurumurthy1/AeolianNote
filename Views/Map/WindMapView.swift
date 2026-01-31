import SwiftUI
import MapKit

struct WindMapView: View {
    @StateObject private var viewModel = WindMapViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // US center
        span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
    )
    @State private var showingNoteDetail = false

    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $region, annotationItems: viewModel.notes) { note in
                MapAnnotation(coordinate: note.currentCoordinate) {
                    NoteAnnotationView(note: note) {
                        viewModel.selectNote(note)
                        showingNoteDetail = true
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            // Overlay UI
            VStack {
                HStack {
                    Spacer()

                    // Compass
                    if let windData = viewModel.currentWindData {
                        VStack(spacing: 4) {
                            CompassNeedle(windBearing: windData.windBearingDegrees)

                            Text(String(format: "%.0f mph", windData.windSpeedMph))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.ink)
                        }
                        .padding()
                        .background(DesignSystem.Colors.parchment.opacity(0.9))
                        .cornerRadius(16)
                        .shadow(radius: 5)
                    }
                }
                .padding()

                Spacer()

                // Legend
                HStack(spacing: DesignSystem.Spacing.md) {
                    LegendItem(color: DesignSystem.Colors.glow, label: "Active Notes")
                    LegendItem(color: DesignSystem.Colors.wind, label: "Your Area")
                }
                .padding()
                .background(DesignSystem.Colors.parchment.opacity(0.9))
                .cornerRadius(12)
                .padding(.bottom)
            }

            // Loading
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(DesignSystem.Colors.parchment.opacity(0.9))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            viewModel.startUpdates()
        }
        .onDisappear {
            viewModel.stopUpdates()
        }
        .onChange(of: viewModel.userCoordinate) { newCoord in
            if let coord = newCoord {
                withAnimation {
                    region.center = coord
                    region.span = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                }
            }
        }
        .sheet(isPresented: $showingNoteDetail) {
            if let note = viewModel.selectedNote {
                NoteDetailSheet(note: note)
            }
        }
    }
}

struct NoteAnnotationView: View {
    let note: Note
    let onTap: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glow pulse
                Circle()
                    .fill(DesignSystem.Colors.glow.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulseScale)

                // Note dot
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DesignSystem.Colors.glow, DesignSystem.Colors.sunset],
                            center: .center,
                            startRadius: 0,
                            endRadius: 10
                        )
                    )
                    .frame(width: 16, height: 16)
                    .shadow(color: DesignSystem.Colors.glow.opacity(0.8), radius: 5)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.ink)
        }
    }
}

struct NoteDetailSheet: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Journey visualization
                JourneyPathView(journeyPath: note.journeyPath)
                    .frame(height: 200)
                    .padding()

                // Stats
                VStack(spacing: DesignSystem.Spacing.sm) {
                    StatRow(label: "Distance Traveled", value: String(format: "%.1f miles", note.totalDistance))
                    StatRow(label: "Time Remaining", value: formatTimeRemaining(note.timeRemaining))
                    StatRow(label: "Status", value: note.status.rawValue.capitalized)
                }
                .padding()
                .background(DesignSystem.Colors.parchment)
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationTitle("Note Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatTimeRemaining(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.ink)
        }
    }
}

struct JourneyPathView: View {
    let journeyPath: [Note.JourneyPoint]

    var body: some View {
        GeometryReader { geometry in
            if journeyPath.count >= 2 {
                Path { path in
                    let points = normalizedPoints(in: geometry.size)
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [DesignSystem.Colors.ocean, DesignSystem.Colors.sunset],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                // Origin marker
                if let first = normalizedPoints(in: geometry.size).first {
                    Circle()
                        .fill(DesignSystem.Colors.ocean)
                        .frame(width: 10, height: 10)
                        .position(first)
                }

                // Current position marker
                if let last = normalizedPoints(in: geometry.size).last {
                    Circle()
                        .fill(DesignSystem.Colors.sunset)
                        .frame(width: 12, height: 12)
                        .position(last)
                        .shadow(color: DesignSystem.Colors.glow, radius: 5)
                }
            }
        }
        .background(DesignSystem.Colors.parchment.opacity(0.5))
        .cornerRadius(12)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !journeyPath.isEmpty else { return [] }

        let lats = journeyPath.map { $0.lat }
        let lons = journeyPath.map { $0.lon }

        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let latRange = max(maxLat - minLat, 0.01)
        let lonRange = max(maxLon - minLon, 0.01)

        let padding: CGFloat = 20

        return journeyPath.map { point in
            let x = padding + CGFloat((point.lon - minLon) / lonRange) * (size.width - 2 * padding)
            let y = padding + CGFloat(1 - (point.lat - minLat) / latRange) * (size.height - 2 * padding)
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    WindMapView()
}
