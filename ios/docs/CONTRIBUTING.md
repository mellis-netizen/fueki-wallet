# Contributing to Fueki Wallet

Thank you for your interest in contributing to Fueki Wallet! This document provides guidelines and instructions for contributing.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Coding Standards](#coding-standards)
5. [Testing Guidelines](#testing-guidelines)
6. [Pull Request Process](#pull-request-process)
7. [Issue Reporting](#issue-reporting)
8. [Documentation](#documentation)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inspiring community for everyone. Please be respectful and constructive in all interactions.

### Expected Behavior

- Use welcoming and inclusive language
- Be respectful of differing viewpoints
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment, discrimination, or trolling
- Publishing others' private information
- Spam or excessive self-promotion
- Other conduct which could reasonably be considered inappropriate

## Getting Started

### Prerequisites

1. **Development Environment**
   ```bash
   # macOS 13.0+
   # Xcode 15.0+
   # Git
   ```

2. **Fork the Repository**
   - Fork on GitHub
   - Clone your fork locally

3. **Setup**
   ```bash
   git clone https://github.com/your-username/Fueki-Mobile-Wallet.git
   cd Fueki-Mobile-Wallet/ios
   pod install
   ```

4. **Configure Git**
   ```bash
   git config user.name "Your Name"
   git config user.email "your.email@example.com"
   ```

### Understanding the Codebase

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Review [CODE_STYLE.md](CODE_STYLE.md) for coding standards
- Check [TESTING.md](TESTING.md) for testing practices

## Development Workflow

### Branching Strategy

We use Git Flow:

```
main            # Production releases
└── develop     # Integration branch
    └── feature/    # New features
    └── bugfix/     # Bug fixes
    └── hotfix/     # Production hotfixes
```

### Creating a Feature Branch

```bash
# Update develop branch
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/wallet-qr-scanner

# Make changes and commit
git add .
git commit -m "Add QR code scanner for wallet addresses"

# Push to your fork
git push origin feature/wallet-qr-scanner
```

### Branch Naming

- **Features**: `feature/descriptive-name`
- **Bug Fixes**: `bugfix/issue-number-description`
- **Hotfixes**: `hotfix/critical-bug-description`
- **Documentation**: `docs/what-is-being-documented`
- **Refactoring**: `refactor/component-name`

Examples:
- `feature/add-dark-mode`
- `bugfix/123-fix-transaction-crash`
- `hotfix/security-vulnerability`
- `docs/update-api-integration`

### Commit Messages

Follow Conventional Commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process or auxiliary tool changes

**Examples**:

```bash
feat(wallet): add QR code scanner for addresses

Implemented camera-based QR code scanner to easily scan
wallet addresses when sending transactions.

Closes #123

---

fix(transaction): prevent crash on invalid gas price

Added validation for gas price input to prevent crashes
when users enter invalid values.

Fixes #456

---

docs(api): update blockchain integration guide

Updated API integration documentation with new Solana
endpoints and examples.
```

### Code Review Process

1. **Self-Review**
   - Review your own changes first
   - Run tests and linter
   - Check for console warnings

2. **Automated Checks**
   - CI/CD pipeline must pass
   - Code coverage must not decrease
   - No new SwiftLint warnings

3. **Peer Review**
   - At least one approval required
   - Address all feedback
   - Re-request review after changes

4. **Merge**
   - Squash commits if needed
   - Update documentation
   - Delete feature branch

## Coding Standards

### Swift Style Guide

See [CODE_STYLE.md](CODE_STYLE.md) for detailed guidelines.

**Quick Reference**:

```swift
// ✅ Good
class WalletManager {
    private let storage: StorageProtocol
    private let networkManager: NetworkManager

    init(storage: StorageProtocol, networkManager: NetworkManager) {
        self.storage = storage
        self.networkManager = networkManager
    }

    func fetchWallets() async throws -> [Wallet] {
        try await networkManager.request(.wallets)
    }
}

// ❌ Bad
class WalletManager {
    var storage:StorageProtocol!
    var nm:NetworkManager!

    func getWallets()->Array<Wallet> {
        // Implementation
    }
}
```

### SwiftLint

All code must pass SwiftLint:

```bash
# Run SwiftLint
swiftlint

# Auto-fix issues
swiftlint --fix

# Custom rules in .swiftlint.yml
```

### File Organization

```swift
// MARK: - Imports
import Foundation
import UIKit

// MARK: - Protocol
protocol WalletServiceProtocol {
    func fetchWallets() async throws -> [Wallet]
}

// MARK: - Implementation
class WalletService: WalletServiceProtocol {
    // MARK: - Properties
    private let networkManager: NetworkManager

    // MARK: - Initialization
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }

    // MARK: - Public Methods
    func fetchWallets() async throws -> [Wallet] {
        // Implementation
    }

    // MARK: - Private Methods
    private func validateWallet(_ wallet: Wallet) -> Bool {
        // Implementation
    }
}

// MARK: - Extensions
extension WalletService {
    func refreshWallets() async throws {
        // Implementation
    }
}
```

## Testing Guidelines

### Test Requirements

- **Unit Tests**: All new business logic
- **Integration Tests**: API and storage interactions
- **UI Tests**: Critical user flows
- **Code Coverage**: Maintain or improve coverage

### Writing Tests

```swift
import XCTest
@testable import FuekiWallet

class WalletServiceTests: XCTestCase {
    var sut: WalletService!
    var mockNetwork: MockNetworkManager!

    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkManager()
        sut = WalletService(networkManager: mockNetwork)
    }

    override func tearDown() {
        sut = nil
        mockNetwork = nil
        super.tearDown()
    }

    // MARK: - Tests
    func testFetchWallets_Success() async throws {
        // Given
        let expectedWallets = [Wallet.mock()]
        mockNetwork.walletsToReturn = expectedWallets

        // When
        let wallets = try await sut.fetchWallets()

        // Then
        XCTAssertEqual(wallets.count, 1)
        XCTAssertTrue(mockNetwork.fetchCalled)
    }

    func testFetchWallets_NetworkError_ThrowsError() async {
        // Given
        mockNetwork.shouldFail = true

        // When/Then
        do {
            _ = try await sut.fetchWallets()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }
}
```

### Running Tests

```bash
# All tests
xcodebuild test -scheme FuekiWallet

# Specific test
xcodebuild test -only-testing:FuekiWalletTests/WalletServiceTests

# With coverage
xcodebuild test -scheme FuekiWallet -enableCodeCoverage YES
```

## Pull Request Process

### Before Submitting

1. **Update Your Branch**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout your-feature-branch
   git rebase develop
   ```

2. **Run Checks**
   ```bash
   # Lint
   swiftlint

   # Tests
   xcodebuild test -scheme FuekiWallet

   # Build
   xcodebuild build -scheme FuekiWallet
   ```

3. **Update Documentation**
   - Update relevant .md files
   - Add code comments
   - Update CHANGELOG.md

### Creating Pull Request

1. **Push to Your Fork**
   ```bash
   git push origin feature/your-feature
   ```

2. **Open PR on GitHub**
   - Use PR template
   - Link related issues
   - Add screenshots (for UI changes)
   - Add description and testing notes

3. **PR Template**

   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## Changes Made
   - Change 1
   - Change 2
   - Change 3

   ## Testing
   - [ ] Unit tests added/updated
   - [ ] Integration tests added/updated
   - [ ] UI tests added/updated
   - [ ] Manual testing performed

   ## Screenshots (if applicable)
   [Add screenshots here]

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Comments added to complex code
   - [ ] Documentation updated
   - [ ] No new warnings generated
   - [ ] Tests pass locally
   - [ ] Dependent changes merged

   ## Related Issues
   Closes #123
   Related to #456
   ```

### PR Review Checklist

**For Reviewers**:

- [ ] Code follows style guidelines
- [ ] Tests are comprehensive
- [ ] Documentation is updated
- [ ] No security vulnerabilities
- [ ] Performance is acceptable
- [ ] UI/UX is intuitive (for UI changes)
- [ ] Edge cases are handled
- [ ] Error handling is appropriate

### After Approval

1. **Address Feedback**
   - Make requested changes
   - Push updates
   - Re-request review

2. **Merge**
   ```bash
   # Squash commits if needed
   git rebase -i HEAD~n

   # Merge (maintainer will do this)
   ```

3. **Clean Up**
   ```bash
   # Delete local branch
   git branch -d feature/your-feature

   # Delete remote branch (if needed)
   git push origin --delete feature/your-feature
   ```

## Issue Reporting

### Bug Reports

Use the bug report template:

```markdown
**Bug Description**
Clear description of the bug

**Steps to Reproduce**
1. Go to '...'
2. Tap on '...'
3. See error

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Screenshots**
If applicable

**Environment**
- iOS Version:
- App Version:
- Device:

**Additional Context**
Any other relevant information
```

### Feature Requests

Use the feature request template:

```markdown
**Feature Description**
Clear description of the feature

**Problem It Solves**
What problem does this solve?

**Proposed Solution**
How should it work?

**Alternatives Considered**
Other approaches you've thought about

**Additional Context**
Mockups, examples, etc.
```

## Documentation

### Types of Documentation

1. **Code Comments**
   - Explain "why", not "what"
   - Document complex logic
   - Add TODO/FIXME when needed

2. **API Documentation**
   - Document public interfaces
   - Include usage examples
   - Describe parameters and return values

3. **README Files**
   - Keep updated
   - Add setup instructions
   - Include examples

### Documentation Style

```swift
/// Manages wallet operations including creation, import, and deletion.
///
/// This service provides a high-level interface for wallet management,
/// handling secure storage of private keys and coordination with
/// blockchain networks.
///
/// - Important: All operations involving private keys are performed
///   securely using iOS Keychain.
///
/// Example usage:
/// ```swift
/// let walletManager = WalletManager()
/// let wallet = try await walletManager.createWallet(name: "My Wallet")
/// ```
class WalletManager {
    /// Creates a new wallet with the specified name and type.
    ///
    /// - Parameters:
    ///   - name: Display name for the wallet
    ///   - type: Type of blockchain (Ethereum, Bitcoin, etc.)
    /// - Returns: Newly created wallet
    /// - Throws: `WalletError` if creation fails
    func createWallet(name: String, type: WalletType) async throws -> Wallet {
        // Implementation
    }
}
```

## Communication

### Channels

- **GitHub Issues**: Bug reports and feature requests
- **Pull Requests**: Code review discussions
- **Discussions**: General questions and ideas

### Response Times

- Issues: Within 48 hours
- Pull Requests: Within 72 hours
- Security Issues: Within 24 hours

## Recognition

Contributors will be recognized in:
- CHANGELOG.md for each release
- Contributors section in README.md
- GitHub contributors page

## Questions?

If you have questions not covered here:
1. Check existing documentation
2. Search GitHub issues
3. Create a new discussion
4. Contact maintainers

---

Thank you for contributing to Fueki Wallet! 🚀
