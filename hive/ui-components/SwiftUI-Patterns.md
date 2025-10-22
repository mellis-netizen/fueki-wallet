# Fueki Wallet - SwiftUI UI Patterns

## Overview
Production-grade SwiftUI interface with MVVM architecture, accessibility support, and excellent UX.

## Architecture

### MVVM Pattern
- **Views**: SwiftUI views with declarative UI
- **ViewModels**: `@ObservableObject` classes managing state
- **Models**: Data structures and business logic
- **Services**: Singleton services for wallet, network, storage

### Dependency Injection
```swift
@EnvironmentObject var appCoordinator: AppCoordinator
@EnvironmentObject var walletManager: WalletManager
@EnvironmentObject var themeManager: ThemeManager
```

## Key Components

### Navigation
- **AppCoordinator**: Central navigation and app state management
- **MainTabView**: Tab-based navigation (Wallet, Assets, Activity, Settings)
- **NavigationView**: Per-screen navigation stacks

### Onboarding Flow
1. WelcomeView → Feature carousel
2. CreateWalletView / ImportWalletView → Wallet setup
3. MnemonicDisplayView → Recovery phrase display
4. MnemonicVerificationView → Recovery phrase verification
5. BiometricSetupView → Optional biometric auth
6. PINSetupView → PIN creation

### Main Features
- **WalletDashboardView**: Portfolio overview, quick actions
- **AssetsListView**: Asset management with search
- **ActivityView**: Transaction history with filters
- **SettingsView**: App configuration

### Transaction Flow
1. SendView → Asset selection, recipient, amount
2. TransactionConfirmationView → Review details
3. TransactionDetailsView → View completed transaction

### Security Features
- Biometric authentication (Face ID / Touch ID)
- 6-digit PIN code
- Auto-lock functionality
- Screenshot protection
- Transaction authentication

## Reusable Components

### CustomButton
```swift
CustomButton(
    title: "Send",
    icon: "arrow.up.circle.fill",
    style: .primary,
    isLoading: false,
    isDisabled: false
) {
    // Action
}
```

Styles: `.primary`, `.secondary`, `.tertiary`, `.destructive`

### AssetRow
```swift
AssetRow(asset: asset)
```
Displays asset icon, name, balance, and price change.

### TransactionRow
```swift
TransactionRow(transaction: transaction)
```
Shows transaction type, asset, amount, and status.

### QRCodeView
```swift
QRCodeView(content: "0x123...", size: 250)
```
Generates and displays QR codes.

### LoadingView
```swift
LoadingView(message: "Loading wallet...")
```

### ErrorView
```swift
ErrorView(error: error) {
    // Retry action
}
```

## Design System

### Colors
- **Primary**: Blue (`Color.blue`)
- **Success**: Green (`Color.green`)
- **Warning**: Orange (`Color.orange`)
- **Error**: Red (`Color.red`)
- **Background**: System adaptive colors

### Typography
- **Title**: `.title`, `.title2`, `.title3`
- **Body**: `.body`, `.subheadline`
- **Caption**: `.caption`, `.caption2`
- **Weights**: `.regular`, `.medium`, `.semibold`, `.bold`

### Spacing
- Small: 8-12pt
- Medium: 16-24pt
- Large: 32-40pt

### Corner Radius
- Small: 8pt
- Medium: 12pt
- Large: 16pt

## Accessibility

### VoiceOver Support
- Proper accessibility labels
- Semantic UI elements
- Grouped related content

### Dynamic Type
- All text scales with system settings
- Layouts adapt to larger text sizes

### Color Contrast
- WCAG AA compliant
- Dark mode support
- High contrast colors

## Animations

### Transitions
```swift
.transition(.scale)
.animation(.easeInOut(duration: 0.2), value: state)
```

### Haptic Feedback
```swift
UIImpactFeedbackGenerator(style: .medium).impactOccurred()
UINotificationFeedbackGenerator().notificationOccurred(.success)
```

## State Management

### Published Properties
```swift
@Published var isLoading = false
@Published var assets: [Asset] = []
```

### Async Operations
```swift
func loadData() async {
    await MainActor.run {
        isLoading = true
    }
    // Async work
    await MainActor.run {
        isLoading = false
    }
}
```

### Pull to Refresh
```swift
.refreshable {
    await viewModel.refresh()
}
```

## Best Practices

1. **Separation of Concerns**: ViewModels handle logic, Views handle UI
2. **Declarative UI**: Use SwiftUI's declarative syntax
3. **State-Driven**: UI updates automatically from state changes
4. **Accessibility First**: Consider VoiceOver and Dynamic Type
5. **Dark Mode**: Support both light and dark themes
6. **Haptics**: Provide tactile feedback for actions
7. **Loading States**: Show progress for async operations
8. **Error Handling**: Display user-friendly error messages
9. **Empty States**: Provide guidance when no data
10. **Confirmation**: Require confirmation for destructive actions

## File Organization

```
ios/FuekiWallet/UI/
├── App.swift                    # Main app entry
├── AppCoordinator.swift         # Navigation coordinator
├── Views/
│   ├── Onboarding/             # Onboarding flow
│   ├── Main/                   # Main app screens
│   ├── Transaction/            # Transaction screens
│   └── Security/               # Security screens
└── Components/                  # Reusable components
```

## Testing Considerations

- Use PreviewProvider for SwiftUI previews
- Mock data for UI testing
- Accessibility inspector validation
- Test on multiple device sizes
- Test both light and dark mode
- Test with dynamic type sizes

## Performance Tips

1. Use `LazyVStack` for long lists
2. Optimize images (compression, caching)
3. Limit view hierarchy depth
4. Use `@StateObject` for view model lifecycle
5. Debounce user input (search, etc.)
6. Prefetch data when possible
7. Cache expensive computations
8. Use `GeometryReader` sparingly
