import { configureStore } from '@reduxjs/toolkit';
import { persistStore, persistReducer } from 'redux-persist';
import AsyncStorage from '@react-native-async-storage/async-storage';

import appReducer from './slices/appSlice';
import authReducer from './slices/authSlice';
import walletReducer from './slices/walletSlice';
import transactionReducer from './slices/transactionSlice';
import tokenReducer from './slices/tokenSlice';
import networkReducer from './slices/networkSlice';
import priceReducer from './slices/priceSlice';

const appPersistConfig = {
  key: 'app',
  storage: AsyncStorage,
  whitelist: ['theme', 'currency'],
};

const authPersistConfig = {
  key: 'auth',
  storage: AsyncStorage,
  whitelist: ['hasWallet', 'biometricEnabled'],
};

const walletPersistConfig = {
  key: 'wallet',
  storage: AsyncStorage,
  whitelist: ['activeAddress', 'addresses'],
};

const networkPersistConfig = {
  key: 'network',
  storage: AsyncStorage,
  whitelist: ['selectedChain', 'customNetworks'],
};

export const store = configureStore({
  reducer: {
    app: persistReducer(appPersistConfig, appReducer),
    auth: persistReducer(authPersistConfig, authReducer),
    wallet: persistReducer(walletPersistConfig, walletReducer),
    transaction: transactionReducer,
    token: tokenReducer,
    network: persistReducer(networkPersistConfig, networkReducer),
    price: priceReducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['persist/PERSIST', 'persist/REHYDRATE'],
      },
    }),
});

export const persistor = persistStore(store);

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
