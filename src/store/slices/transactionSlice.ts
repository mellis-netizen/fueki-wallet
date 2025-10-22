import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../index';
import { TransactionService } from '../../services/wallet/TransactionService';
import type { ChainType } from '../../types/blockchain';

export interface Transaction {
  hash: string;
  from: string;
  to: string;
  value: string;
  chain: ChainType;
  status: 'pending' | 'confirmed' | 'failed';
  timestamp: number;
  fee?: string;
  blockNumber?: number;
  tokenSymbol?: string;
}

interface TransactionState {
  transactions: Transaction[];
  pendingTransactions: Transaction[];
  isLoading: boolean;
  error: string | null;
}

const initialState: TransactionState = {
  transactions: [],
  pendingTransactions: [],
  isLoading: false,
  error: null,
};

export const loadTransactions = createAsyncThunk(
  'transaction/load',
  async ({ address, chain }: { address: string; chain: ChainType }, { rejectWithValue }) => {
    try {
      const transactions = await TransactionService.getTransactions(address, chain);
      return transactions;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const sendTransaction = createAsyncThunk(
  'transaction/send',
  async (
    params: {
      to: string;
      value: string;
      chain: ChainType;
      token?: string;
      gasLimit?: string;
    },
    { rejectWithValue }
  ) => {
    try {
      const txHash = await TransactionService.sendTransaction(params);
      return { ...params, hash: txHash, timestamp: Date.now(), status: 'pending' as const };
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const checkTransactionStatus = createAsyncThunk(
  'transaction/checkStatus',
  async ({ hash, chain }: { hash: string; chain: ChainType }, { rejectWithValue }) => {
    try {
      const status = await TransactionService.getTransactionStatus(hash, chain);
      return { hash, status };
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

const transactionSlice = createSlice({
  name: 'transaction',
  initialState,
  reducers: {
    addPendingTransaction: (state, action: PayloadAction<Transaction>) => {
      state.pendingTransactions.push(action.payload);
    },
    updateTransactionStatus: (
      state,
      action: PayloadAction<{ hash: string; status: Transaction['status'] }>
    ) => {
      const tx = state.pendingTransactions.find((t) => t.hash === action.payload.hash);
      if (tx) {
        tx.status = action.payload.status;
        if (action.payload.status !== 'pending') {
          state.transactions.unshift(tx);
          state.pendingTransactions = state.pendingTransactions.filter(
            (t) => t.hash !== action.payload.hash
          );
        }
      }
    },
    clearTransactions: (state) => {
      state.transactions = [];
      state.pendingTransactions = [];
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(loadTransactions.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(loadTransactions.fulfilled, (state, action) => {
        state.isLoading = false;
        state.transactions = action.payload;
      })
      .addCase(loadTransactions.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload as string;
      })
      .addCase(sendTransaction.fulfilled, (state, action) => {
        state.pendingTransactions.push(action.payload as Transaction);
      })
      .addCase(sendTransaction.rejected, (state, action) => {
        state.error = action.payload as string;
      })
      .addCase(checkTransactionStatus.fulfilled, (state, action) => {
        const tx = state.pendingTransactions.find((t) => t.hash === action.payload.hash);
        if (tx) {
          tx.status = action.payload.status;
        }
      });
  },
});

export const { addPendingTransaction, updateTransactionStatus, clearTransactions } =
  transactionSlice.actions;

export const selectTransactions = (state: RootState) => state.transaction.transactions;
export const selectPendingTransactions = (state: RootState) =>
  state.transaction.pendingTransactions;
export const selectAllTransactions = (state: RootState) => [
  ...state.transaction.pendingTransactions,
  ...state.transaction.transactions,
];

export default transactionSlice.reducer;
