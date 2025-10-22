import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../index';
import { PriceService } from '../../services/wallet/PriceService';

interface PriceState {
  prices: Record<string, number>;
  priceChange24h: Record<string, number>;
  lastUpdated: number | null;
  isLoading: boolean;
  error: string | null;
}

const initialState: PriceState = {
  prices: {},
  priceChange24h: {},
  lastUpdated: null,
  isLoading: false,
  error: null,
};

export const fetchPrices = createAsyncThunk(
  'price/fetch',
  async (symbols: string[], { rejectWithValue }) => {
    try {
      const prices = await PriceService.getPrices(symbols);
      return prices;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

const priceSlice = createSlice({
  name: 'price',
  initialState,
  reducers: {
    updatePrice: (state, action: PayloadAction<{ symbol: string; price: number }>) => {
      state.prices[action.payload.symbol] = action.payload.price;
    },
    clearPrices: (state) => {
      state.prices = {};
      state.priceChange24h = {};
      state.lastUpdated = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchPrices.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(fetchPrices.fulfilled, (state, action) => {
        state.isLoading = false;
        state.prices = action.payload.prices;
        state.priceChange24h = action.payload.priceChange24h;
        state.lastUpdated = Date.now();
      })
      .addCase(fetchPrices.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload as string;
      });
  },
});

export const { updatePrice, clearPrices } = priceSlice.actions;

export const selectPrices = (state: RootState) => state.price.prices;
export const selectPriceChange24h = (state: RootState) => state.price.priceChange24h;
export const selectPrice = (symbol: string) => (state: RootState) =>
  state.price.prices[symbol] || 0;

export default priceSlice.reducer;
