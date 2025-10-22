import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../index';
import { WalletService } from '../../services/wallet/WalletService';
import type { ChainType } from '../../types/blockchain';

export interface WalletAddress {
  address: string;
  chain: ChainType;
  balance: string;
  name?: string;
}

interface WalletState {
  mnemonic: string | null;
  addresses: Record<ChainType, WalletAddress[]>;
  activeAddress: string | null;
  activeChain: ChainType;
  balances: Record<string, string>;
  isLoading: boolean;
  error: string | null;
}

const initialState: WalletState = {
  mnemonic: null,
  addresses: {
    ethereum: [],
    bitcoin: [],
    solana: [],
  },
  activeAddress: null,
  activeChain: 'ethereum',
  balances: {},
  isLoading: false,
  error: null,
};

export const createWallet = createAsyncThunk(
  'wallet/create',
  async (_, { rejectWithValue }) => {
    try {
      const result = await WalletService.createWallet();
      return result;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const importWallet = createAsyncThunk(
  'wallet/import',
  async (mnemonic: string, { rejectWithValue }) => {
    try {
      const result = await WalletService.importWallet(mnemonic);
      return result;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const loadWalletAddresses = createAsyncThunk(
  'wallet/loadAddresses',
  async (_, { rejectWithValue }) => {
    try {
      const addresses = await WalletService.getAddresses();
      return addresses;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const refreshBalances = createAsyncThunk(
  'wallet/refreshBalances',
  async (_, { getState, rejectWithValue }) => {
    try {
      const state = getState() as RootState;
      const { addresses, activeChain } = state.wallet;

      const balances: Record<string, string> = {};

      for (const address of addresses[activeChain]) {
        const balance = await WalletService.getBalance(address.address, activeChain);
        balances[address.address] = balance;
      }

      return balances;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

const walletSlice = createSlice({
  name: 'wallet',
  initialState,
  reducers: {
    setActiveAddress: (state, action: PayloadAction<string>) => {
      state.activeAddress = action.payload;
    },
    setActiveChain: (state, action: PayloadAction<ChainType>) => {
      state.activeChain = action.payload;
    },
    updateBalance: (state, action: PayloadAction<{ address: string; balance: string }>) => {
      state.balances[action.payload.address] = action.payload.balance;
    },
    clearWallet: (state) => {
      state.mnemonic = null;
      state.addresses = { ethereum: [], bitcoin: [], solana: [] };
      state.activeAddress = null;
      state.balances = {};
    },
  },
  extraReducers: (builder) => {
    builder
      // Create Wallet
      .addCase(createWallet.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(createWallet.fulfilled, (state, action) => {
        state.isLoading = false;
        state.mnemonic = action.payload.mnemonic;
        state.addresses = action.payload.addresses;
        state.activeAddress = action.payload.addresses.ethereum[0]?.address;
      })
      .addCase(createWallet.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload as string;
      })
      // Import Wallet
      .addCase(importWallet.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(importWallet.fulfilled, (state, action) => {
        state.isLoading = false;
        state.addresses = action.payload.addresses;
        state.activeAddress = action.payload.addresses.ethereum[0]?.address;
      })
      .addCase(importWallet.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload as string;
      })
      // Load Addresses
      .addCase(loadWalletAddresses.fulfilled, (state, action) => {
        state.addresses = action.payload;
      })
      // Refresh Balances
      .addCase(refreshBalances.pending, (state) => {
        state.isLoading = true;
      })
      .addCase(refreshBalances.fulfilled, (state, action) => {
        state.isLoading = false;
        state.balances = action.payload;
      })
      .addCase(refreshBalances.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload as string;
      });
  },
});

export const { setActiveAddress, setActiveChain, updateBalance, clearWallet } = walletSlice.actions;

export const selectAddresses = (state: RootState) => state.wallet.addresses;
export const selectActiveAddress = (state: RootState) => state.wallet.activeAddress;
export const selectActiveChain = (state: RootState) => state.wallet.activeChain;
export const selectBalances = (state: RootState) => state.wallet.balances;
export const selectCurrentBalance = (state: RootState) => {
  const { activeAddress, balances } = state.wallet;
  return activeAddress ? balances[activeAddress] || '0' : '0';
};

export default walletSlice.reducer;
