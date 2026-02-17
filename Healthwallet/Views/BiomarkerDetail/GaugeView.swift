import SwiftUI

struct GaugeView: View {
    let value: Double
    let status: BiomarkerStatus
    let progress: Double

    private let startAngle = Angle.degrees(150)
    private let endAngle = Angle.degrees(390)

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height * 0.55)
            let radius = size * 0.4

            ZStack {
                // Track
                ArcShape(startAngle: startAngle, endAngle: endAngle, center: center, radius: radius)
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 20, lineCap: .round))

                // Colored arc
                ArcShape(startAngle: startAngle, endAngle: endAngle, center: center, radius: radius)
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.yellow, .yellow, .green, .green],
                            center: UnitPoint(x: center.x / geometry.size.width, y: center.y / geometry.size.height),
                            startAngle: startAngle,
                            endAngle: endAngle
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )

                // Needle
                needleView(center: center, radius: radius)

                // Value label
                VStack(spacing: 2) {
                    Text(value, format: .number.precision(.fractionLength(0)))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(status.color)
                }
                .position(x: center.x, y: center.y + 20)

                // Labels
                HStack {
                    Text("Low")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                    Spacer()
                    Text("Optimal")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .position(x: geometry.size.width / 2, y: center.y + 60)
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
    }

    private func needleView(center: CGPoint, radius: CGFloat) -> some View {
        let angle = startAngle + (endAngle - startAngle) * progress
        let needleRadius = radius - 10
        let x = center.x + needleRadius * cos(CGFloat(angle.radians))
        let y = center.y + needleRadius * sin(CGFloat(angle.radians))

        return Circle()
            .fill(Color(.label))
            .frame(width: 12, height: 12)
            .position(x: x, y: y)
    }
}

struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

#Preview {
    GaugeView(value: 24, status: .low, progress: 0.3)
        .frame(height: 250)
        .padding()
}
