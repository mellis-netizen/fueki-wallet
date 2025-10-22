import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../index';

export type Theme = 'light' | 'dark' | 'auto';
export type Currency = 'USD' | 'EUR' | 'GBP' | 'JPY' | 'CNY';

interface AppState {
  isInitialized: boolean;
  isLoading: boolean;
  theme: Theme;
  currency: Currency;
  language: string;
  error: string | null;
}

const initialState: AppState = {
  isInitialized: false,
  isLoading: false,
  theme: 'auto',
  currency: 'USD',
  language: 'en',
  error: null,
};

export const initializeApp = createAsyncThunk(
  'app/initialize',
  async () => {
    // Perform any app initialization tasks
    await new Promise(resolve => setTimeout(resolve, 500));
    return true;
  }
);

const appSlice = createSlice({
  name: 'app',
  initialState,
  reducers: {
    setTheme: (state, action: PayloadAction<Theme>) => {
      state.theme = action.payload;
    },
    setCurrency: (state, action: PayloadAction<Currency>) => {
      state.currency = action.payload;
    },
    setLanguage: (state, action: PayloadAction<string>) => {
      state.language = action.payload;
    },
    setError: (state, action: PayloadAction<string | null>) => {
      state.error = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(initializeApp.pending, (state) => {
        state.isLoading = true;
      })
      .addCase(initializeApp.fulfilled, (state) => {
        state.isInitialized = true;
        state.isLoading = false;
      })
      .addCase(initializeApp.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.error.message || 'Initialization failed';
      });
  },
});

export const { setTheme, setCurrency, setLanguage, setError } = appSlice.actions;

export const selectTheme = (state: RootState) => state.app.theme;
export const selectCurrency = (state: RootState) => state.app.currency;
export const selectIsInitialized = (state: RootState) => state.app.isInitialized;

export default appSlice.reducer;
