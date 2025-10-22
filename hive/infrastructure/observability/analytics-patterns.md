# Analytics & Monitoring Patterns

## Overview
Complete analytics, logging, and crash reporting infrastructure for the Fueki Wallet.

## Components

### 1. Analytics System
- **AnalyticsManager**: Central coordinator for multiple analytics providers
- **AnalyticsEvents**: Comprehensive event definitions with privacy-safe parameters
- **AnalyticsProtocol**: Provider interface for extensibility
- **Providers**:
  - ConsoleAnalyticsProvider (development)
  - FirebaseAnalyticsProvider (production-ready, awaiting Firebase configuration)

### 2. Logging Infrastructure
- **Logger**: Multi-destination logging (console, file, remote)
- **LogLevel**: Hierarchical log levels (verbose → critical)
- **Log Categories**: Organized logging by domain (network, blockchain, wallet, etc.)
- **Features**:
  - Automatic log rotation (max 10MB per file, 5 files max)
  - Thread-safe async logging
  - Privacy-safe logging (no sensitive data)

### 3. Crash Reporting
- **CrashReporter**: Exception and signal handling
- **Breadcrumbs**: Context tracking (max 100 breadcrumbs)
- **Custom Metadata**: Key-value crash context
- **Integration Ready**: Prepared for Crashlytics/Sentry

### 4. Performance Monitoring
- **PerformanceMonitor**: Trace-based performance tracking
- **Features**:
  - Custom traces with metrics
  - Memory usage monitoring
  - FPS monitoring
  - Slow operation detection (thresholds: 1s warning, 3s critical)

### 5. Error Tracking
- **ErrorTracker**: Categorized error tracking and analysis
- **Error Categories**: Network, Blockchain, Wallet, Security, Storage, Validation, UI
- **Error Severity**: Low, Medium, High, Critical
- **Statistics**: Error trends and category distribution

### 6. User Properties
- **UserPropertyManager**: User attribute management
- **Standard Properties**: Device info, app info, user preferences
- **Privacy**: Automatic user ID anonymization
- **Persistence**: Cross-session property storage

### 7. Remote Logging
- **RemoteLogger**: Critical error remote reporting
- **Features**:
  - Batch upload (every 5 minutes or 10 logs)
  - Offline persistence
  - Device and app info collection

## Analytics Events

### Wallet Events
- wallet_created, wallet_imported, wallet_deleted
- wallet_backed_up, wallet_restored, wallet_switched

### Transaction Events
- transaction_initiated, transaction_signed, transaction_broadcast
- transaction_completed, transaction_failed

### Screen Events
- screen_viewed, screen_dismissed

### User Actions
- button_tapped, feature_used, setting_changed, search_performed

### Security Events
- biometric_auth_attempted, pin_code_attempted
- session_expired, security_lock_enabled/disabled

### Error Events
- error_occurred, network_error, validation_error

### Performance Events
- performance_metric, api_call_completed

### Blockchain Events
- blockchain_connected/disconnected
- gas_estimated, contract_interaction

## Privacy & Security

### Privacy-Safe Logging
- No logging of private keys, seed phrases, or passwords
- Transaction amounts not logged (only presence)
- User IDs are hashed/anonymized
- Search queries logged by length only

### User Consent
- Analytics requires explicit user consent
- Controlled via `AnalyticsManager.userHasConsentedToAnalytics`
- All providers disabled without consent (except console in debug)

### Data Anonymization
- Wallet IDs hashed before logging
- User IDs anonymized (SHA256 hash)
- Device IDs are persistent UUIDs (not tied to personal info)

## Usage Patterns

### Basic Analytics
```swift
// Initialize on app launch
AnalyticsManager.shared.initialize()

// Track event
AnalyticsManager.shared.track(.walletCreated(type: .hd))

// Track screen
AnalyticsManager.shared.trackScreen("WalletDetail")

// Set user property
UserPropertyManager.shared.setProperty(.walletCount, value: "3")
```

### Logging
```swift
// Simple logging
Logger.shared.info("User logged in", category: .security)
Logger.shared.error("Network request failed", category: .network)

// With metadata
Logger.shared.log(
    "Transaction completed",
    level: .info,
    category: .blockchain,
    metadata: ["tx_hash": hash, "status": "confirmed"]
)
```

### Crash Reporting
```swift
// Initialize
CrashReporter.shared.initialize()

// Record breadcrumbs
CrashReporter.shared.recordBreadcrumb(
    "User tapped send button",
    category: .user
)

// Record non-fatal error
CrashReporter.shared.recordError(error, context: "Transaction signing")

// Set custom metadata
CrashReporter.shared.setCustomValue("mainnet", forKey: "network")
```

### Performance Monitoring
```swift
// Start trace
let traceId = PerformanceMonitor.shared.startTrace("load_wallet")

// Add metrics
PerformanceMonitor.shared.addMetric(
    to: traceId,
    metricName: "balance_count",
    value: 5
)

// Stop trace
PerformanceMonitor.shared.stopTrace(traceId)

// Convenience method
PerformanceMonitor.shared.measure(name: "api_call") {
    // Code to measure
}
```

### Error Tracking
```swift
// Track error
ErrorTracker.shared.track(
    error: error,
    category: .network,
    severity: .high,
    context: "Fetching token prices"
)

// Get statistics
let stats = ErrorTracker.shared.getStatistics()
print("Total errors: \(stats.totalErrors)")
print("Critical errors: \(stats.criticalSeverityCount)")
```

## Integration Checklist

### Firebase Analytics (When Ready)
1. Add Firebase SDK to project
2. Configure GoogleService-Info.plist
3. Enable FirebaseAnalyticsProvider in AnalyticsManager
4. Uncomment Firebase code in AnalyticsProtocol.swift

### Crashlytics (When Ready)
1. Add Crashlytics SDK
2. Configure in Firebase console
3. Uncomment Crashlytics code in CrashReporter.swift
4. Test with forced crash

### Remote Logging (When Backend Ready)
1. Configure endpoint in RemoteLogger
2. Set API key for authentication
3. Test log upload
4. Monitor remote logs in backend dashboard

## Best Practices

### Development
- Use console logging in debug builds
- Test crash reporting with test crashes
- Monitor performance during development
- Review error statistics regularly

### Production
- Enable file logging for support
- Configure remote logging for critical errors
- Set up crash reporting alerts
- Monitor analytics dashboard

### Privacy
- Always check user consent before tracking
- Never log sensitive information
- Anonymize user identifiers
- Respect user privacy preferences

### Performance
- Use async logging to avoid blocking main thread
- Limit breadcrumb count (max 100)
- Rotate logs automatically
- Batch remote logs for efficiency

## File Organization

```
Analytics/
├── LogLevel.swift              # Log level and category definitions
├── AnalyticsEvents.swift       # Event definitions
├── AnalyticsProtocol.swift     # Provider protocol and implementations
├── AnalyticsManager.swift      # Main analytics coordinator
├── Logger.swift                # Logging infrastructure
├── RemoteLogger.swift          # Remote logging service
├── CrashReporter.swift         # Crash reporting and exception handling
├── PerformanceMonitor.swift    # Performance metrics and traces
├── ErrorTracker.swift          # Error tracking and categorization
└── UserPropertyManager.swift   # User properties management
```

## Metrics & KPIs

### Analytics
- Event tracking coverage: 100% of major user actions
- Screen tracking: All screens tracked
- User properties: 13 standard properties

### Logging
- Log levels: 6 levels (verbose → critical)
- Log categories: 10 categories
- Log rotation: Automatic (10MB/file, 5 files)

### Performance
- Trace types: Screen load, network, transaction, custom
- Memory monitoring: Active
- FPS monitoring: Available
- Slow operation detection: 1s warning, 3s critical

### Error Tracking
- Error categories: 7 categories
- Severity levels: 4 levels
- Error history: Up to 100 errors

## Testing Strategy

### Unit Tests
- Test event parameter generation
- Test log formatting
- Test error categorization
- Test user property persistence

### Integration Tests
- Test analytics provider coordination
- Test crash reporting flow
- Test performance trace lifecycle
- Test remote logging batch upload

### Manual Tests
- Verify analytics events in console
- Test crash reporting with forced crash
- Monitor performance traces
- Review error statistics

## Future Enhancements

### Short-term
- Add A/B testing support
- Implement feature flags
- Add custom dashboards
- Enhanced user segmentation

### Long-term
- Machine learning for anomaly detection
- Predictive analytics
- Real-time monitoring dashboard
- Advanced performance profiling

## Coordination with Other Agents

### Security Agent
- Share security event definitions
- Coordinate on privacy requirements
- Align on sensitive data handling

### Network Agent
- Share network error tracking
- Coordinate on API call monitoring
- Align on performance metrics

### UI/UX Agent
- Share screen tracking implementation
- Coordinate on user interaction events
- Align on performance monitoring

### Testing Agent
- Share test event definitions
- Coordinate on test analytics
- Align on error simulation

## Success Metrics

- 100% crash-free users
- <100ms logging overhead
- <1% analytics events dropped
- <5MB total log file size
- <500ms performance trace overhead
