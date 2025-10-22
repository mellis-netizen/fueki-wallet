import React, { useEffect } from 'react';
import { StatusBar, Platform } from 'react-native';
import { Provider } from 'react-redux';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { NavigationContainer } from '@react-navigation/native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import SplashScreen from 'react-native-splash-screen';

import { store } from './store';
import RootNavigator from './navigation/RootNavigator';
import { BiometricService } from './services/security/BiometricService';
import { navigationRef } from './navigation/navigationRef';
import { useAppDispatch } from './hooks/useRedux';
import { initializeApp } from './store/slices/appSlice';

const AppContent: React.FC = () => {
  const dispatch = useAppDispatch();

  useEffect(() => {
    const initialize = async () => {
      try {
        // Initialize biometric authentication
        await BiometricService.initialize();

        // Initialize app state
        await dispatch(initializeApp()).unwrap();
      } catch (error) {
        console.error('App initialization failed:', error);
      } finally {
        // Hide splash screen
        if (Platform.OS !== 'web') {
          SplashScreen?.hide();
        }
      }
    };

    initialize();
  }, [dispatch]);

  return (
    <SafeAreaProvider>
      <GestureHandlerRootView style={{ flex: 1 }}>
        <StatusBar
          barStyle="dark-content"
          backgroundColor="#FFFFFF"
          translucent={false}
        />
        <NavigationContainer ref={navigationRef}>
          <RootNavigator />
        </NavigationContainer>
      </GestureHandlerRootView>
    </SafeAreaProvider>
  );
};

const App: React.FC = () => {
  return (
    <Provider store={store}>
      <AppContent />
    </Provider>
  );
};

export default App;
