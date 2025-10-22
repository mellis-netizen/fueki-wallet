import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../index';
import { BiometricService } from '../../services/security/BiometricService';
import { SecureStorageService } from '../../services/security/SecureStorageService';

interface AuthState {
  isAuthenticated: boolean;
  hasWallet: boolean;
  biometricEnabled: boolean;
  biometricType: 'FaceID' | 'TouchID' | 'Fingerprint' | null;
  lastAuthTime: number | null;
  pinEnabled: boolean;
}

const initialState: AuthState = {
  isAuthenticated: false,
  hasWallet: false,
  biometricEnabled: false,
  biometricType: null,
  lastAuthTime: null,
  pinEnabled: false,
};

export const checkWalletExists = createAsyncThunk(
  'auth/checkWallet',
  async () => {
    const hasWallet = await SecureStorageService.hasWallet();
    return hasWallet;
  }
);

export const authenticateWithBiometric = createAsyncThunk(
  'auth/biometric',
  async () => {
    const result = await BiometricService.authenticate();
    if (!result.success) {
      throw new Error(result.error || 'Authentication failed');
    }
    return true;
  }
);

export const authenticateWithPin = createAsyncThunk(
  'auth/pin',
  async (pin: string) => {
    const isValid = await SecureStorageService.verifyPin(pin);
    if (!isValid) {
      throw new Error('Invalid PIN');
    }
    return true;
  }
);

export const setupBiometric = createAsyncThunk(
  'auth/setupBiometric',
  async () => {
    const available = await BiometricService.isBiometricAvailable();
    if (available) {
      await SecureStorageService.setBiometricEnabled(true);
      const type = await BiometricService.getBiometricType();
      return type;
    }
    return null;
  }
);

export const setupPin = createAsyncThunk(
  'auth/setupPin',
  async (pin: string) => {
    await SecureStorageService.setPin(pin);
    return true;
  }
);

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setAuthenticated: (state, action: PayloadAction<boolean>) => {
      state.isAuthenticated = action.payload;
      if (action.payload) {
        state.lastAuthTime = Date.now();
      }
    },
    setHasWallet: (state, action: PayloadAction<boolean>) => {
      state.hasWallet = action.payload;
    },
    setBiometricEnabled: (state, action: PayloadAction<boolean>) => {
      state.biometricEnabled = action.payload;
    },
    logout: (state) => {
      state.isAuthenticated = false;
      state.lastAuthTime = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(checkWalletExists.fulfilled, (state, action) => {
        state.hasWallet = action.payload;
      })
      .addCase(authenticateWithBiometric.fulfilled, (state) => {
        state.isAuthenticated = true;
        state.lastAuthTime = Date.now();
      })
      .addCase(authenticateWithPin.fulfilled, (state) => {
        state.isAuthenticated = true;
        state.lastAuthTime = Date.now();
      })
      .addCase(setupBiometric.fulfilled, (state, action) => {
        state.biometricEnabled = true;
        state.biometricType = action.payload;
      })
      .addCase(setupPin.fulfilled, (state) => {
        state.pinEnabled = true;
      });
  },
});

export const { setAuthenticated, setHasWallet, setBiometricEnabled, logout } = authSlice.actions;

export const selectIsAuthenticated = (state: RootState) => state.auth.isAuthenticated;
export const selectHasWallet = (state: RootState) => state.auth.hasWallet;
export const selectBiometricEnabled = (state: RootState) => state.auth.biometricEnabled;
export const selectBiometricType = (state: RootState) => state.auth.biometricType;

export default authSlice.reducer;
