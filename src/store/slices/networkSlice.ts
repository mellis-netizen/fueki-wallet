import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../index';
import type { ChainType } from '../../types/blockchain';

export interface Network {
  id: string;
  name: string;
  chain: ChainType;
  rpcUrl: string;
  chainId: number;
  symbol: string;
  explorerUrl: string;
  isTestnet: boolean;
}

interface NetworkState {
  selectedChain: ChainType;
  customNetworks: Network[];
  networkStatus: Record<ChainType, 'online' | 'offline' | 'checking'>;
}

const initialState: NetworkState = {
  selectedChain: 'ethereum',
  customNetworks: [],
  networkStatus: {
    ethereum: 'online',
    bitcoin: 'online',
    solana: 'online',
  },
};

const networkSlice = createSlice({
  name: 'network',
  initialState,
  reducers: {
    setSelectedChain: (state, action: PayloadAction<ChainType>) => {
      state.selectedChain = action.payload;
    },
    addCustomNetwork: (state, action: PayloadAction<Network>) => {
      const exists = state.customNetworks.some((n) => n.id === action.payload.id);
      if (!exists) {
        state.customNetworks.push(action.payload);
      }
    },
    removeCustomNetwork: (state, action: PayloadAction<string>) => {
      state.customNetworks = state.customNetworks.filter((n) => n.id !== action.payload);
    },
    updateNetworkStatus: (
      state,
      action: PayloadAction<{ chain: ChainType; status: 'online' | 'offline' | 'checking' }>
    ) => {
      state.networkStatus[action.payload.chain] = action.payload.status;
    },
  },
});

export const { setSelectedChain, addCustomNetwork, removeCustomNetwork, updateNetworkStatus } =
  networkSlice.actions;

export const selectSelectedChain = (state: RootState) => state.network.selectedChain;
export const selectCustomNetworks = (state: RootState) => state.network.customNetworks;
export const selectNetworkStatus = (state: RootState) => state.network.networkStatus;

export default networkSlice.reducer;
