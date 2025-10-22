import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { useAppSelector } from '../hooks/useRedux';
import { selectIsAuthenticated, selectHasWallet } from '../store/slices/authSlice';

// Auth Screens
import OnboardingScreen from '../screens/auth/OnboardingScreen';
import CreateWalletScreen from '../screens/auth/CreateWalletScreen';
import ImportWalletScreen from '../screens/auth/ImportWalletScreen';
import BiometricSetupScreen from '../screens/auth/BiometricSetupScreen';
import PinSetupScreen from '../screens/auth/PinSetupScreen';

// Main App
import MainNavigator from './MainNavigator';
import LockScreen from '../screens/auth/LockScreen';

export type RootStackParamList = {
  Onboarding: undefined;
  CreateWallet: undefined;
  ImportWallet: undefined;
  BiometricSetup: undefined;
  PinSetup: { mnemonic?: string };
  Lock: undefined;
  Main: undefined;
};

const Stack = createStackNavigator<RootStackParamList>();

const RootNavigator: React.FC = () => {
  const isAuthenticated = useAppSelector(selectIsAuthenticated);
  const hasWallet = useAppSelector(selectHasWallet);

  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        gestureEnabled: false,
      }}
    >
      {!hasWallet ? (
        // Onboarding Flow
        <>
          <Stack.Screen name="Onboarding" component={OnboardingScreen} />
          <Stack.Screen name="CreateWallet" component={CreateWalletScreen} />
          <Stack.Screen name="ImportWallet" component={ImportWalletScreen} />
          <Stack.Screen name="BiometricSetup" component={BiometricSetupScreen} />
          <Stack.Screen name="PinSetup" component={PinSetupScreen} />
        </>
      ) : !isAuthenticated ? (
        // Lock Screen
        <Stack.Screen name="Lock" component={LockScreen} />
      ) : (
        // Main App
        <Stack.Screen name="Main" component={MainNavigator} />
      )}
    </Stack.Navigator>
  );
};

export default RootNavigator;
