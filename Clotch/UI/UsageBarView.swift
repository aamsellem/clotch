import SwiftUI

/// Shows Claude API usage as text + thin bar. Text is ALWAYS above the bar, never overlapped.
struct UsageBarView: View {
    @Bindable var usageService: UsageService

    var body: some View {
        let quota = usageService.quota
        let pct = Int(min(max(quota.dominantUsage, 0), 1.0) * 100)
        let barFraction = min(max(quota.dominantUsage, 0), 1.0)

        VStack(alignment: .leading, spacing: 4) {
            // Text row — white on dark, always readable
            HStack {
                Text("USAGE  \(pct)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }

            // Thin bar below text
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 6)
                    .cornerRadius(3)

                Rectangle()
                    .fill(barFraction < 0.7 ? Color.green : (barFraction < 0.9 ? Color.orange : Color.red))
                    .frame(width: max(6, CGFloat(barFraction) * 300), height: 6)
                    .cornerRadius(3)
            }
            .frame(height: 6)
            .frame(maxWidth: 300)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
