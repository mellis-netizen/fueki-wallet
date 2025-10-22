import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../index';
import { TokenService } from '../../services/wallet/TokenService';
import type { ChainType } from '../../types/blockchain';

export interface Token {
  address: string;
  symbol: string;
  name: string;
  decimals: number;
  balance: string;
  chain: ChainType;
  logo?: string;
  price?: number;
}

interface TokenState {
  tokens: Token[];
  favoriteTokens: string[];
  isLoading: boolean;
  error: string | null;
}

const initialState: TokenState = {
  tokens: [],
  favoriteTokens: [],
  isLoading: false,
  error: null,
};

export const loadTokens = createAsyncThunk(
  'token/load',
  async ({ address, chain }: { address: string; chain: ChainType }, { rejectWithValue }) => {
    try {
      const tokens = await TokenService.getTokens(address, chain);
      return tokens;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const addCustomToken = createAsyncThunk(
  'token/add',
  async (
    { tokenAddress, chain }: { tokenAddress: string; chain: ChainType },
    { rejectWithValue }
  ) => {
    try {
      const token = await TokenService.getTokenInfo(tokenAddress, chain);
      return token;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

const tokenSlice = createSlice({
  name: 'token',
  initialState,
  reducers: {
    toggleFavoriteToken: (state, action: PayloadAction<string>) => {
      const index = state.favoriteTokens.indexOf(action.payload);
      if (index >= 0) {
        state.favoriteTokens.splice(index, 1);
      } else {
        state.favoriteTokens.push(action.payload);
      }
    },
    removeToken: (state, action: PayloadAction<string>) => {
      state.tokens = state.tokens.filter((t) => t.address !== action.payload);
    },
    updateTokenBalance: (state, action: PayloadAction<{ address: string; balance: string }>) => {
      const token = state.tokens.find((t) => t.address === action.payload.address);
      if (token) {
        token.balance = action.payload.balance;
      }
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(loadTokens.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(loadTokens.fulfilled, (state, action) => {
        state.isLoading = false;
        state.tokens = action.payload;
      })
      .addCase(loadTokens.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload as string;
      })
      .addCase(addCustomToken.fulfilled, (state, action) => {
        const exists = state.tokens.some((t) => t.address === action.payload.address);
        if (!exists) {
          state.tokens.push(action.payload);
        }
      });
  },
});

export const { toggleFavoriteToken, removeToken, updateTokenBalance } = tokenSlice.actions;

export const selectTokens = (state: RootState) => state.token.tokens;
export const selectFavoriteTokens = (state: RootState) => state.token.favoriteTokens;

export default tokenSlice.reducer;
