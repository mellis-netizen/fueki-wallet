import SwiftUI

struct CustomButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
        case destructive

        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return Color(UIColor.secondarySystemBackground)
            case .tertiary: return .clear
            case .destructive: return .red
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .destructive: return .white
            case .secondary, .tertiary: return .primary
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.body)
                    }
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style.backgroundColor)
            )
            .foregroundColor(style.foregroundColor)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Preview
struct CustomButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            CustomButton(title: "Primary Button", icon: "checkmark.circle.fill", style: .primary) {}
            CustomButton(title: "Secondary Button", icon: "arrow.right", style: .secondary) {}
            CustomButton(title: "Tertiary Button", style: .tertiary) {}
            CustomButton(title: "Loading", style: .primary, isLoading: true) {}
            CustomButton(title: "Disabled", style: .primary, isDisabled: true) {}
            CustomButton(title: "Destructive", icon: "trash.fill", style: .destructive) {}
        }
        .padding()
    }
}
