# Fueki Mobile Wallet - Developer Setup Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Development Environment](#development-environment)
4. [Running Tests](#running-tests)
5. [Building the Project](#building-the-project)
6. [IDE Configuration](#ide-configuration)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements

- **Operating System**: macOS, Linux, or Windows with WSL2
- **Node.js**: 20.x or higher
- **npm**: 10.x or higher
- **Git**: 2.x or higher
- **RAM**: Minimum 4GB (8GB recommended)
- **Disk Space**: 2GB free space

### Required Tools

```bash
# Check Node.js version
node --version  # Should be v20.x or higher

# Check npm version
npm --version   # Should be 10.x or higher

# Check Git version
git --version   # Should be 2.x or higher
```

### Installing Node.js

**Using nvm (recommended)**:
```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Install Node.js 20
nvm install 20
nvm use 20
nvm alias default 20
```

**Using official installer**:
- Download from https://nodejs.org/
- Choose LTS version (20.x)
- Run installer and follow instructions

---

## Installation

### 1. Clone the Repository

```bash
# Clone via HTTPS
git clone https://github.com/yourorg/fueki-mobile-wallet.git

# Or clone via SSH
git clone git@github.com:yourorg/fueki-mobile-wallet.git

# Navigate to project directory
cd fueki-mobile-wallet
```

### 2. Install Dependencies

```bash
# Install all dependencies
npm install

# Or use clean install (recommended for CI/CD)
npm ci
```

**This will install**:
- Production dependencies (bitcoinjs-lib, ethereumjs, etc.)
- Development dependencies (TypeScript, Jest, etc.)
- All transitive dependencies

### 3. Verify Installation

```bash
# Check TypeScript installation
npx tsc --version

# Check Jest installation
npx jest --version

# Verify all packages installed
npm list --depth=0
```

---

## Development Environment

### Project Structure

```
fueki-mobile-wallet/
├── src/                          # Source code
│   └── networking/
│       └── rpc/                  # RPC client implementations
│           ├── bitcoin/          # Bitcoin Electrum client
│           ├── ethereum/         # Ethereum Web3 client
│           ├── common/           # Shared utilities
│           └── index.ts          # Main exports
├── tests/                        # Test suites
│   ├── security/                 # Security tests
│   └── vectors/                  # Test vectors
├── docs/                         # Documentation
├── scripts/                      # Build and utility scripts
├── package.json                  # Project configuration
├── tsconfig.json                 # TypeScript configuration
├── jest.config.js                # Jest configuration
└── README.md                     # Project readme
```

### Environment Configuration

Create a `.env` file for local development (optional):

```bash
# .env
NODE_ENV=development

# Bitcoin Network
BITCOIN_NETWORK=testnet
BITCOIN_RPC_URL=https://blockstream.info/testnet/api

# Ethereum Network
ETHEREUM_NETWORK=sepolia
ETHEREUM_RPC_URL=https://rpc.sepolia.org

# Optional: Custom endpoints
# CUSTOM_BITCOIN_ENDPOINTS=url1,url2,url3
# CUSTOM_ETHEREUM_ENDPOINTS=url1,url2,url3

# Logging
LOG_LEVEL=debug
```

**Security Note**: Never commit `.env` files to version control!

### TypeScript Configuration

The project uses TypeScript 5.3+ with strict mode enabled. Configuration is in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

### Jest Configuration

Test configuration is in `jest.config.js`:

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/index.ts'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
};
```

---

## Running Tests

### Test Suites

The project has multiple test suites:

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage report
npm run test:coverage

# Run specific test suite
npm run test:vectors      # Cryptographic test vectors
npm run test:bitcoin      # Bitcoin tests
npm run test:ethereum     # Ethereum tests
npm run test:tss          # TSS tests
npm run test:shamir       # Shamir secret sharing tests
```

### Security Tests

```bash
# Run all security tests
npm test tests/security

# Run specific security test
npm test tests/security/crypto.test.ts
npm test tests/security/signing.test.ts
npm test tests/security/storage.test.ts
```

### Test Vectors

Test vectors validate cryptographic operations against known values:

```bash
# Bitcoin test vectors
npm run test:bitcoin

# Tests include:
# - BIP32 key derivation
# - BIP39 mnemonic generation
# - BIP44 multi-account hierarchy
# - Transaction signing

# Ethereum test vectors
npm run test:ethereum

# Tests include:
# - Address generation
# - Transaction signing
# - EIP-155 replay protection
```

### Writing Tests

Example test file:

```typescript
// tests/example.test.ts
import { describe, test, expect } from '@jest/globals';
import { RPCClientFactory, ChainType, NetworkType } from '../src/networking/rpc';

describe('RPCClientFactory', () => {
  test('should create Bitcoin client', () => {
    const client = RPCClientFactory.createBitcoinClient({
      chain: ChainType.BITCOIN,
      network: NetworkType.TESTNET
    });

    expect(client).toBeDefined();
    expect(client.isConnected()).toBe(false);
  });

  test('should create Ethereum client', () => {
    const client = RPCClientFactory.createEthereumClient({
      chain: ChainType.ETHEREUM,
      network: NetworkType.TESTNET
    });

    expect(client).toBeDefined();
    expect(client.isConnected()).toBe(false);
  });
});
```

### Running Individual Tests

```bash
# Run specific test file
npm test tests/security/crypto.test.ts

# Run tests matching pattern
npm test -- --testNamePattern="Bitcoin"

# Run tests with verbose output
npm test -- --verbose

# Run tests and update snapshots
npm test -- -u
```

---

## Building the Project

### Development Build

```bash
# Compile TypeScript to JavaScript
npm run build

# Output will be in ./dist directory
```

### Production Build

```bash
# Clean previous build
rm -rf dist

# Build with optimizations
npm run build

# Verify build
ls -la dist
```

### Build Output

After building, the `dist/` directory contains:

```
dist/
├── networking/
│   └── rpc/
│       ├── bitcoin/
│       │   └── ElectrumClient.js
│       ├── ethereum/
│       │   └── Web3Client.js
│       ├── common/
│       │   ├── ConnectionPool.js
│       │   ├── RateLimiter.js
│       │   ├── RetryHandler.js
│       │   ├── WebSocketClient.js
│       │   └── NetworkConfig.js
│       └── index.js
├── *.d.ts                        # Type declarations
└── *.js.map                      # Source maps
```

### Type Checking

```bash
# Run TypeScript type checker
npx tsc --noEmit

# Watch mode for type checking
npx tsc --noEmit --watch
```

### Linting

```bash
# Run ESLint (if configured)
npm run lint

# Fix auto-fixable issues
npm run lint:fix
```

---

## IDE Configuration

### Visual Studio Code

**Recommended Extensions**:
```json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-typescript-next",
    "orta.vscode-jest"
  ]
}
```

**Settings** (`.vscode/settings.json`):
```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "typescript.tsdk": "node_modules/typescript/lib",
  "jest.autoRun": "off",
  "files.exclude": {
    "**/node_modules": true,
    "**/dist": true
  }
}
```

**Launch Configuration** (`.vscode/launch.json`):
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Jest Current File",
      "program": "${workspaceFolder}/node_modules/.bin/jest",
      "args": [
        "${fileBasename}",
        "--config",
        "jest.config.js"
      ],
      "console": "integratedTerminal",
      "internalConsoleOptions": "neverOpen"
    },
    {
      "type": "node",
      "request": "launch",
      "name": "Jest All",
      "program": "${workspaceFolder}/node_modules/.bin/jest",
      "args": [
        "--runInBand"
      ],
      "console": "integratedTerminal",
      "internalConsoleOptions": "neverOpen"
    }
  ]
}
```

### IntelliJ IDEA / WebStorm

1. **Enable TypeScript support**:
   - Languages & Frameworks → TypeScript
   - Enable TypeScript Language Service
   - Use project TypeScript version

2. **Configure Jest**:
   - Languages & Frameworks → JavaScript → Jest
   - Jest package: `<project>/node_modules/jest`
   - Configuration file: `<project>/jest.config.js`

3. **Set up run configurations**:
   - Run → Edit Configurations
   - Add Jest configuration
   - Specify working directory and config file

---

## Development Workflow

### 1. Create Feature Branch

```bash
# Create and checkout new branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/bug-description
```

### 2. Make Changes

```bash
# Edit files
# Run tests frequently
npm test

# Type check
npx tsc --noEmit

# Build to verify
npm run build
```

### 3. Commit Changes

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: add new feature"

# Or for fixes
git commit -m "fix: resolve issue with X"
```

### 4. Push and Create PR

```bash
# Push to remote
git push origin feature/your-feature-name

# Create pull request on GitHub
```

### Commit Message Convention

Follow conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions or changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `chore`: Build process or auxiliary tool changes

**Examples**:
```
feat(rpc): add connection pooling support

Implement connection pool with min/max connections,
health checks, and automatic failover.

Closes #123
```

---

## Troubleshooting

### Common Issues

#### 1. Installation Failures

**Problem**: `npm install` fails

**Solutions**:
```bash
# Clear npm cache
npm cache clean --force

# Remove node_modules and package-lock.json
rm -rf node_modules package-lock.json

# Reinstall
npm install

# Or use different registry
npm install --registry https://registry.npmjs.org/
```

#### 2. TypeScript Compilation Errors

**Problem**: TypeScript compilation fails

**Solutions**:
```bash
# Check TypeScript version
npx tsc --version

# Clean and rebuild
rm -rf dist
npm run build

# Check for conflicting type definitions
npm list @types
```

#### 3. Test Failures

**Problem**: Tests fail unexpectedly

**Solutions**:
```bash
# Run tests with verbose output
npm test -- --verbose

# Run single test file
npm test tests/path/to/test.ts

# Clear Jest cache
npm test -- --clearCache

# Update snapshots if needed
npm test -- -u
```

#### 4. Memory Issues

**Problem**: Node.js runs out of memory

**Solutions**:
```bash
# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"

# Run with increased memory
NODE_OPTIONS="--max-old-space-size=4096" npm test
```

#### 5. Network Connection Issues

**Problem**: Cannot connect to RPC endpoints

**Solutions**:
```bash
# Test endpoint connectivity
curl https://blockstream.info/testnet/api

# Check firewall settings
# Try alternative endpoints
# Verify network configuration
```

### Debug Mode

Enable debug logging:

```bash
# Set debug environment variable
export DEBUG=*

# Run with debug output
DEBUG=* npm test
```

### Getting Help

1. **Check Documentation**: Review API.md and ARCHITECTURE.md
2. **Search Issues**: Look for similar issues on GitHub
3. **Ask Questions**: Open a discussion or issue
4. **Contact Team**: Reach out to maintainers

---

## Development Tools

### Useful Commands

```bash
# Watch mode for development
npm run dev

# Run type checking in watch mode
npx tsc --noEmit --watch

# Generate coverage report
npm run test:coverage

# View coverage report
open coverage/lcov-report/index.html

# Check for outdated dependencies
npm outdated

# Update dependencies
npm update

# Audit dependencies for vulnerabilities
npm audit
npm audit fix
```

### Scripts Reference

All available npm scripts:

```json
{
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "test:vectors": "jest tests/vectors",
    "test:bitcoin": "jest tests/vectors/bitcoin",
    "test:ethereum": "jest tests/vectors/ethereum",
    "test:tss": "jest tests/vectors/tss",
    "test:shamir": "jest tests/vectors/shamir",
    "lint": "eslint src tests --ext .ts",
    "lint:fix": "eslint src tests --ext .ts --fix",
    "typecheck": "tsc --noEmit",
    "clean": "rm -rf dist coverage"
  }
}
```

---

## Next Steps

After setup:

1. **Explore the Codebase**: Review source code in `src/`
2. **Read Documentation**: Study API.md and ARCHITECTURE.md
3. **Run Examples**: Try example code from API.md
4. **Write Tests**: Add tests for new features
5. **Contribute**: Submit pull requests

---

## Additional Resources

- **API Documentation**: `/docs/API.md`
- **Architecture**: `/docs/ARCHITECTURE.md`
- **Security**: `/docs/SECURITY.md`
- **Deployment**: `/docs/DEPLOYMENT.md`
- **User Guide**: `/docs/USER_GUIDE.md`
- **Troubleshooting**: `/docs/TROUBLESHOOTING.md`

---

## Support

For help with setup:
- Open an issue on GitHub
- Contact: dev@fueki.io (example)
- Documentation: https://docs.fueki.io (example)
