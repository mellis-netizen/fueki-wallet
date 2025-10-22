# ADR-005: State Management and Persistence Strategy

## Status
**ACCEPTED** - 2025-10-21

## Context

The Fueki Mobile Wallet needs a robust state management solution to handle:
- Wallet state (balances, transactions, addresses)
- Application state (UI, settings, preferences)
- Real-time updates (new blocks, transactions)
- Offline-first capabilities
- Data persistence across app restarts

### Requirements
1. **Performance**: Fast state updates and queries
2. **Type Safety**: Full TypeScript support
3. **Persistence**: Encrypted local storage
4. **Reactivity**: UI auto-updates on state changes
5. **Offline Support**: Work without network
6. **Scalability**: Handle large transaction histories
7. **Testability**: Easy to test state logic

### Constraints
- React Native environment
- Limited device storage
- Must support offline mode
- Sensitive data must be encrypted
- No external state management services

## Decision

We will use a **hybrid state management approach** combining:
1. **Zustand** for global application state (lightweight, no boilerplate)
2. **React Context** for component-scoped state
3. **MMKV** for encrypted persistence
4. **AsyncStorage** for non-sensitive data

## Architecture

### State Management Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    React Components                             │
│        (UI components subscribe to state changes)               │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   State Layer                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Wallet       │  │ Transaction  │  │ Settings     │         │
│  │ Store        │  │ Store        │  │ Store        │         │
│  │ (Zustand)    │  │ (Zustand)    │  │ (Zustand)    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Auth         │  │ Network      │  │ UI           │         │
│  │ Context      │  │ Store        │  │ Store        │         │
│  │ (React)      │  │ (Zustand)    │  │ (Zustand)    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Persistence Layer                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ MMKV (Encrypted)                                         │  │
│  │ - Wallet data                                            │  │
│  │ - Transaction history                                    │  │
│  │ - Balances                                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ AsyncStorage (Non-sensitive)                             │  │
│  │ - Settings                                               │  │
│  │ - UI preferences                                         │  │
│  │ - Cache                                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation

#### 1. Wallet Store (Zustand)

```typescript
// src/stores/walletStore.ts

import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { MMKV } from 'react-native-mmkv';
import { immer } from 'zustand/middleware/immer';

// MMKV instance for encrypted storage
const mmkvStorage = new MMKV({
  id: 'fueki-wallet-store',
  encryptionKey: 'your-encryption-key', // Should be derived from device key
});

// MMKV adapter for Zustand
const mmkvZustandStorage = {
  getItem: (name: string) => {
    const value = mmkvStorage.getString(name);
    return value ? JSON.parse(value) : null;
  },
  setItem: (name: string, value: any) => {
    mmkvStorage.set(name, JSON.stringify(value));
  },
  removeItem: (name: string) => {
    mmkvStorage.delete(name);
  },
};

interface WalletState {
  // State
  addresses: Map<string, Address>; // chainId:address -> Address
  balances: Map<string, Balance>;  // chainId:address -> Balance
  transactions: Map<string, Transaction[]>; // chainId:address -> Transaction[]
  isInitialized: boolean;
  lastSyncTime: number;

  // Actions
  addAddress: (chainId: string, address: Address) => void;
  updateBalance: (chainId: string, address: string, balance: Balance) => void;
  addTransaction: (chainId: string, address: string, transaction: Transaction) => void;
  updateTransaction: (chainId: string, txHash: string, update: Partial<Transaction>) => void;
  clearWallet: () => void;
  setInitialized: (initialized: boolean) => void;
  sync: () => Promise<void>;
}

export const useWalletStore = create<WalletState>()(
  persist(
    immer((set, get) => ({
      // Initial state
      addresses: new Map(),
      balances: new Map(),
      transactions: new Map(),
      isInitialized: false,
      lastSyncTime: 0,

      // Actions
      addAddress: (chainId, address) =>
        set((state) => {
          const key = `${chainId}:${address.address}`;
          state.addresses.set(key, address);
        }),

      updateBalance: (chainId, address, balance) =>
        set((state) => {
          const key = `${chainId}:${address}`;
          state.balances.set(key, balance);
        }),

      addTransaction: (chainId, address, transaction) =>
        set((state) => {
          const key = `${chainId}:${address}`;
          const existing = state.transactions.get(key) || [];

          // Add if not exists
          if (!existing.find(tx => tx.hash === transaction.hash)) {
            existing.unshift(transaction); // Add to beginning
            state.transactions.set(key, existing);
          }
        }),

      updateTransaction: (chainId, txHash, update) =>
        set((state) => {
          for (const [key, txs] of state.transactions.entries()) {
            if (key.startsWith(chainId)) {
              const index = txs.findIndex(tx => tx.hash === txHash);
              if (index !== -1) {
                txs[index] = { ...txs[index], ...update };
                state.transactions.set(key, txs);
                break;
              }
            }
          }
        }),

      clearWallet: () =>
        set((state) => {
          state.addresses.clear();
          state.balances.clear();
          state.transactions.clear();
          state.isInitialized = false;
          state.lastSyncTime = 0;
        }),

      setInitialized: (initialized) =>
        set((state) => {
          state.isInitialized = initialized;
        }),

      sync: async () => {
        const state = get();
        const walletManager = new WalletManager();

        // Sync balances for all addresses
        for (const [key, address] of state.addresses) {
          const [chainId] = key.split(':');
          try {
            const balance = await walletManager.getBalance(chainId, address.address);
            get().updateBalance(chainId, address.address, balance);
          } catch (error) {
            console.error(`Failed to sync balance for ${key}:`, error);
          }
        }

        set((state) => {
          state.lastSyncTime = Date.now();
        });
      },
    })),
    {
      name: 'wallet-storage',
      storage: createJSONStorage(() => mmkvZustandStorage),
      // Serialize Maps for persistence
      serialize: (state) =>
        JSON.stringify({
          ...state,
          addresses: Array.from(state.addresses.entries()),
          balances: Array.from(state.balances.entries()),
          transactions: Array.from(state.transactions.entries()),
        }),
      deserialize: (str) => {
        const data = JSON.parse(str);
        return {
          ...data,
          addresses: new Map(data.addresses || []),
          balances: new Map(data.balances || []),
          transactions: new Map(data.transactions || []),
        };
      },
    }
  )
);
```

#### 2. Transaction Store

```typescript
// src/stores/transactionStore.ts

import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';

interface TransactionState {
  // Pending transactions
  pendingTransactions: Map<string, UnsignedTransaction>;

  // Transaction history cache
  historyCache: Map<string, Transaction[]>;

  // Actions
  addPendingTransaction: (tx: UnsignedTransaction) => string;
  removePendingTransaction: (id: string) => void;
  getPendingTransaction: (id: string) => UnsignedTransaction | undefined;
  updateTransactionHistory: (chainId: string, address: string, transactions: Transaction[]) => void;
  getTransactionHistory: (chainId: string, address: string) => Transaction[];
}

export const useTransactionStore = create<TransactionState>()(
  immer((set, get) => ({
    pendingTransactions: new Map(),
    historyCache: new Map(),

    addPendingTransaction: (tx) => {
      const id = `pending_${Date.now()}_${Math.random()}`;
      set((state) => {
        state.pendingTransactions.set(id, tx);
      });
      return id;
    },

    removePendingTransaction: (id) =>
      set((state) => {
        state.pendingTransactions.delete(id);
      }),

    getPendingTransaction: (id) => {
      return get().pendingTransactions.get(id);
    },

    updateTransactionHistory: (chainId, address, transactions) =>
      set((state) => {
        const key = `${chainId}:${address}`;
        state.historyCache.set(key, transactions);
      }),

    getTransactionHistory: (chainId, address) => {
      const key = `${chainId}:${address}`;
      return get().historyCache.get(key) || [];
    },
  }))
);
```

#### 3. Settings Store

```typescript
// src/stores/settingsStore.ts

import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface SettingsState {
  // Settings
  currency: string;
  language: string;
  theme: 'light' | 'dark' | 'system';
  biometricEnabled: boolean;
  autoLockTimeout: number; // seconds
  showBalanceInFiat: boolean;
  defaultNetwork: Network;

  // Notifications
  transactionNotifications: boolean;
  priceAlerts: boolean;

  // Privacy
  hideBalances: boolean;
  analyticsEnabled: boolean;

  // Actions
  setCurrency: (currency: string) => void;
  setLanguage: (language: string) => void;
  setTheme: (theme: 'light' | 'dark' | 'system') => void;
  setBiometricEnabled: (enabled: boolean) => void;
  setAutoLockTimeout: (timeout: number) => void;
  toggleShowBalanceInFiat: () => void;
  setDefaultNetwork: (network: Network) => void;
  setTransactionNotifications: (enabled: boolean) => void;
  setPriceAlerts: (enabled: boolean) => void;
  toggleHideBalances: () => void;
  setAnalyticsEnabled: (enabled: boolean) => void;
  resetSettings: () => void;
}

const defaultSettings: Omit<SettingsState, keyof SettingsActions> = {
  currency: 'USD',
  language: 'en',
  theme: 'system',
  biometricEnabled: false,
  autoLockTimeout: 300, // 5 minutes
  showBalanceInFiat: true,
  defaultNetwork: Network.MAINNET,
  transactionNotifications: true,
  priceAlerts: false,
  hideBalances: false,
  analyticsEnabled: false,
};

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      ...defaultSettings,

      setCurrency: (currency) => set({ currency }),
      setLanguage: (language) => set({ language }),
      setTheme: (theme) => set({ theme }),
      setBiometricEnabled: (enabled) => set({ biometricEnabled: enabled }),
      setAutoLockTimeout: (timeout) => set({ autoLockTimeout: timeout }),
      toggleShowBalanceInFiat: () => set((state) => ({ showBalanceInFiat: !state.showBalanceInFiat })),
      setDefaultNetwork: (network) => set({ defaultNetwork: network }),
      setTransactionNotifications: (enabled) => set({ transactionNotifications: enabled }),
      setPriceAlerts: (enabled) => set({ priceAlerts: enabled }),
      toggleHideBalances: () => set((state) => ({ hideBalances: !state.hideBalances })),
      setAnalyticsEnabled: (enabled) => set({ analyticsEnabled: enabled }),
      resetSettings: () => set(defaultSettings),
    }),
    {
      name: 'settings-storage',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);
```

#### 4. Network Store

```typescript
// src/stores/networkStore.ts

import { create } from 'zustand';
import NetInfo from '@react-native-community/netinfo';

interface NetworkState {
  isConnected: boolean;
  isInternetReachable: boolean;
  connectionType: string;
  syncStatus: 'idle' | 'syncing' | 'synced' | 'error';
  lastSyncTime: number;

  // Actions
  setNetworkState: (isConnected: boolean, isInternetReachable: boolean, type: string) => void;
  setSyncStatus: (status: 'idle' | 'syncing' | 'synced' | 'error') => void;
  setLastSyncTime: (time: number) => void;
}

export const useNetworkStore = create<NetworkState>()((set) => ({
  isConnected: true,
  isInternetReachable: true,
  connectionType: 'unknown',
  syncStatus: 'idle',
  lastSyncTime: 0,

  setNetworkState: (isConnected, isInternetReachable, type) =>
    set({ isConnected, isInternetReachable, connectionType: type }),

  setSyncStatus: (status) => set({ syncStatus: status }),

  setLastSyncTime: (time) => set({ lastSyncTime: time }),
}));

// Initialize network listener
NetInfo.addEventListener((state) => {
  useNetworkStore.getState().setNetworkState(
    state.isConnected ?? false,
    state.isInternetReachable ?? false,
    state.type
  );
});
```

#### 5. Auth Context (React Context)

```typescript
// src/contexts/AuthContext.tsx

import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import { KeyManagementService } from '../core/wallet/KeyManagementService';
import { BiometricAuth } from '../services/BiometricAuth';

interface AuthContextType {
  isAuthenticated: boolean;
  isWalletUnlocked: boolean;
  authenticate: () => Promise<boolean>;
  logout: () => void;
  unlockWallet: () => Promise<void>;
  lockWallet: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isWalletUnlocked, setIsWalletUnlocked] = useState(false);
  const keyManager = new KeyManagementService();

  const authenticate = useCallback(async (): Promise<boolean> => {
    try {
      const result = await BiometricAuth.authenticate('Unlock Fueki Wallet');
      setIsAuthenticated(result);
      return result;
    } catch (error) {
      console.error('Authentication failed:', error);
      return false;
    }
  }, []);

  const logout = useCallback(() => {
    setIsAuthenticated(false);
    setIsWalletUnlocked(false);
    keyManager.lock();
  }, []);

  const unlockWallet = useCallback(async () => {
    if (!isAuthenticated) {
      throw new Error('User must authenticate first');
    }

    await keyManager.unlock();
    setIsWalletUnlocked(true);
  }, [isAuthenticated]);

  const lockWallet = useCallback(() => {
    keyManager.lock();
    setIsWalletUnlocked(false);
  }, []);

  // Auto-lock on app background
  useEffect(() => {
    // Implement app state listener
    // Lock wallet when app goes to background
  }, []);

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        isWalletUnlocked,
        authenticate,
        logout,
        unlockWallet,
        lockWallet,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
```

#### 6. UI Store

```typescript
// src/stores/uiStore.ts

import { create } from 'zustand';

interface UIState {
  // Navigation
  activeTab: string;
  activeChain: string;

  // Modals
  isTransactionModalOpen: boolean;
  isQRScannerOpen: boolean;
  isSettingsOpen: boolean;

  // Loading states
  isLoading: boolean;
  loadingMessage: string;

  // Toast notifications
  toasts: Toast[];

  // Actions
  setActiveTab: (tab: string) => void;
  setActiveChain: (chain: string) => void;
  openTransactionModal: () => void;
  closeTransactionModal: () => void;
  openQRScanner: () => void;
  closeQRScanner: () => void;
  openSettings: () => void;
  closeSettings: () => void;
  setLoading: (loading: boolean, message?: string) => void;
  showToast: (toast: Omit<Toast, 'id'>) => void;
  hideToast: (id: string) => void;
}

interface Toast {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  message: string;
  duration?: number;
}

export const useUIStore = create<UIState>()((set, get) => ({
  activeTab: 'wallet',
  activeChain: 'bitcoin',
  isTransactionModalOpen: false,
  isQRScannerOpen: false,
  isSettingsOpen: false,
  isLoading: false,
  loadingMessage: '',
  toasts: [],

  setActiveTab: (tab) => set({ activeTab: tab }),
  setActiveChain: (chain) => set({ activeChain: chain }),
  openTransactionModal: () => set({ isTransactionModalOpen: true }),
  closeTransactionModal: () => set({ isTransactionModalOpen: false }),
  openQRScanner: () => set({ isQRScannerOpen: true }),
  closeQRScanner: () => set({ isQRScannerOpen: false }),
  openSettings: () => set({ isSettingsOpen: true }),
  closeSettings: () => set({ isSettingsOpen: false }),

  setLoading: (loading, message = '') =>
    set({ isLoading: loading, loadingMessage: message }),

  showToast: (toast) => {
    const id = `toast_${Date.now()}`;
    const newToast: Toast = { ...toast, id };

    set((state) => ({
      toasts: [...state.toasts, newToast],
    }));

    // Auto-hide after duration
    if (toast.duration) {
      setTimeout(() => {
        get().hideToast(id);
      }, toast.duration);
    }
  },

  hideToast: (id) =>
    set((state) => ({
      toasts: state.toasts.filter((t) => t.id !== id),
    })),
}));
```

## Usage Examples

### Component Using Stores

```typescript
// src/screens/WalletScreen.tsx

import React, { useEffect } from 'react';
import { View, Text, FlatList } from 'react-native';
import { useWalletStore } from '../stores/walletStore';
import { useNetworkStore } from '../stores/networkStore';
import { useUIStore } from '../stores/uiStore';

export const WalletScreen: React.FC = () => {
  const balances = useWalletStore((state) => state.balances);
  const sync = useWalletStore((state) => state.sync);
  const isConnected = useNetworkStore((state) => state.isConnected);
  const syncStatus = useNetworkStore((state) => state.syncStatus);
  const showToast = useUIStore((state) => state.showToast);

  useEffect(() => {
    if (isConnected && syncStatus === 'idle') {
      sync()
        .then(() => {
          showToast({ type: 'success', message: 'Wallet synced', duration: 3000 });
        })
        .catch((error) => {
          showToast({ type: 'error', message: 'Sync failed', duration: 3000 });
        });
    }
  }, [isConnected]);

  return (
    <View>
      <Text>Total Balance</Text>
      <FlatList
        data={Array.from(balances.entries())}
        renderItem={({ item }) => (
          <Text>
            {item[0]}: {item[1].total.toString()}
          </Text>
        )}
      />
    </View>
  );
};
```

## Performance Considerations

### 1. **Selector Optimization**
```typescript
// ✅ Good: Only re-renders when balance changes
const balance = useWalletStore((state) => state.balances.get('bitcoin:address'));

// ❌ Bad: Re-renders on any state change
const state = useWalletStore();
```

### 2. **Computed Values**
```typescript
// Create derived state
const useTotalBalance = () => {
  return useWalletStore((state) => {
    let total = BigInt(0);
    for (const balance of state.balances.values()) {
      total += balance.total;
    }
    return total;
  });
};
```

### 3. **Debounced Updates**
```typescript
import { debounce } from 'lodash';

const debouncedSync = debounce(() => {
  useWalletStore.getState().sync();
}, 5000);
```

## Data Migration

```typescript
// src/stores/migrations.ts

export const migrations = {
  0: (state: any) => {
    // Initial state
    return state;
  },
  1: (state: any) => {
    // Migration v0 -> v1
    return {
      ...state,
      newField: 'default value',
    };
  },
  2: (state: any) => {
    // Migration v1 -> v2
    return {
      ...state,
      renamedField: state.oldField,
    };
  },
};

// Apply in persist config
persist(
  // ...
  {
    name: 'wallet-storage',
    version: 2,
    migrate: (persistedState: any, version: number) => {
      let state = persistedState;
      for (let i = version; i < 2; i++) {
        state = migrations[i + 1](state);
      }
      return state;
    },
  }
);
```

## Testing

```typescript
// src/stores/__tests__/walletStore.test.ts

import { renderHook, act } from '@testing-library/react-hooks';
import { useWalletStore } from '../walletStore';

describe('WalletStore', () => {
  beforeEach(() => {
    // Reset store before each test
    useWalletStore.getState().clearWallet();
  });

  it('should add address', () => {
    const { result } = renderHook(() => useWalletStore());

    act(() => {
      result.current.addAddress('bitcoin', {
        address: 'bc1q...',
        chainId: 'bitcoin',
        addressType: AddressType.SEGWIT,
        derivationPath: "m/84'/0'/0'/0/0",
        publicKey: '...',
      });
    });

    expect(result.current.addresses.size).toBe(1);
  });

  it('should update balance', () => {
    const { result } = renderHook(() => useWalletStore());

    act(() => {
      result.current.updateBalance('bitcoin', 'bc1q...', {
        address: 'bc1q...',
        chainId: 'bitcoin',
        confirmed: BigInt(100000000),
        unconfirmed: BigInt(0),
        total: BigInt(100000000),
      });
    });

    const balance = result.current.balances.get('bitcoin:bc1q...');
    expect(balance?.total).toBe(BigInt(100000000));
  });
});
```

## Consequences

### Positive
✅ **Simple**: Zustand has minimal boilerplate
✅ **Type-Safe**: Full TypeScript support
✅ **Fast**: Optimized re-renders with selectors
✅ **Persistent**: Auto-save to encrypted storage
✅ **Testable**: Easy to test stores in isolation
✅ **Flexible**: Can combine with React Context

### Negative
⚠️ **Learning Curve**: Developers need to understand Zustand
⚠️ **Storage Limits**: MMKV has device storage constraints

## References

- [Zustand Documentation](https://github.com/pmndrs/zustand)
- [MMKV Documentation](https://github.com/mrousavy/react-native-mmkv)
- [React Context](https://react.dev/reference/react/useContext)

---

**Related ADRs:**
- [ADR-002: Key Management](./adr-002-key-management.md)
- [ADR-004: Network Layer](./adr-004-network-layer.md)
- [ADR-006: Biometric Authentication](./adr-006-biometric-auth.md)
