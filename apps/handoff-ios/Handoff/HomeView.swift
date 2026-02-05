import SwiftUI

struct HomeView: View {
    let hasActiveSession: Bool
    let weeklyStartCount: Int
    let onPrimaryTap: () -> Void
    
    // Mock user name for now
    private let userName = "Woo"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(Theme.Fonts.body(16))
                    .foregroundStyle(Theme.textSecondary)
                
                Text(hasActiveSession ? "Welcome Back" : "Ready to Train?")
                    .font(Theme.Fonts.display(32))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.top, 20)
            
            // Weekly Stats Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Consistency")
                        .font(Theme.Fonts.headline(18))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(weeklyStartCount)/4")
                        .font(Theme.Fonts.number(18))
                        .foregroundStyle(Theme.textSecondary)
                }
                
                // Visual Indicator (Dots)
                HStack(spacing: 12) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index < weeklyStartCount ? Theme.accent : Theme.surface.opacity(0.5))
                            .frame(height: 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("You're on track for your weekly goal.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.Layout.padding)
            .premiumCard()
            
            Spacer()
            
            // Primary Action Button
            Button(action: onPrimaryTap) {
                HStack {
                    Spacer()
                    Text(hasActiveSession ? "Resume Workout" : "Start Workout")
                        .font(Theme.Fonts.headline(20))
                        .kerning(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(Theme.Fonts.headline(20))
                }
                .foregroundStyle(Theme.background)
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.4), radius: 20, x: 0, y: 10)
            }
        }
        .padding(Theme.Layout.padding)
        .appBackground()
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Good Morning, \(userName)"
        case 12..<18: return "Good Afternoon, \(userName)"
        default: return "Good Evening, \(userName)"
        }
    }
}

#Preview {
    HomeView(
        hasActiveSession: false,
        weeklyStartCount: 3,
        onPrimaryTap: {}
    )
    .background(Color.black)
}
