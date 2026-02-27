import SwiftUI

struct StatusCycleButton: View {
    let status: TaskStatus
    let onCycle: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onCycle) {
            ZStack {
                Circle()
                    .fill(status.accentColor.opacity(isHovered ? 0.15 : 0))
                    .frame(width: 24, height: 24)
                    .animation(.easeInOut(duration: 0.1), value: isHovered)

                Image(systemName: status.symbolName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(status.accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(
                        .symbolEffect(.replace.magic(fallback: .replace))
                    )
                    .symbolEffect(
                        .pulse,
                        options: .repeating.speed(0.5),
                        isActive: status == .inProgress && !isHovered
                    )
            }
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(status.label)
    }
}
