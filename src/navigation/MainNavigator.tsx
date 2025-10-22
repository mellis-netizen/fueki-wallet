import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';

// Tab Screens
import HomeScreen from '../screens/main/HomeScreen';
import AssetsScreen from '../screens/main/AssetsScreen';
import DAppsScreen from '../screens/main/DAppsScreen';
import SettingsScreen from '../screens/main/SettingsScreen';

// Modal Screens
import SendScreen from '../screens/transaction/SendScreen';
import ReceiveScreen from '../screens/transaction/ReceiveScreen';
import TransactionDetailScreen from '../screens/transaction/TransactionDetailScreen';
import QRScannerScreen from '../screens/transaction/QRScannerScreen';
import TokenDetailScreen from '../screens/token/TokenDetailScreen';
import AddTokenScreen from '../screens/token/AddTokenScreen';
import NetworkSelectionScreen from '../screens/settings/NetworkSelectionScreen';
import BackupWalletScreen from '../screens/settings/BackupWalletScreen';
import SecuritySettingsScreen from '../screens/settings/SecuritySettingsScreen';

export type MainTabParamList = {
  Home: undefined;
  Assets: undefined;
  DApps: undefined;
  Settings: undefined;
};

export type MainStackParamList = {
  MainTabs: undefined;
  Send: { tokenAddress?: string; chain?: string };
  Receive: { tokenAddress?: string; chain?: string };
  TransactionDetail: { txHash: string; chain: string };
  QRScanner: { onScan: (data: string) => void };
  TokenDetail: { tokenAddress: string; chain: string };
  AddToken: undefined;
  NetworkSelection: undefined;
  BackupWallet: undefined;
  SecuritySettings: undefined;
};

const Tab = createBottomTabNavigator<MainTabParamList>();
const Stack = createStackNavigator<MainStackParamList>();

const MainTabs: React.FC = () => {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: '#4F46E5',
        tabBarInactiveTintColor: '#9CA3AF',
        tabBarStyle: {
          borderTopWidth: 1,
          borderTopColor: '#E5E7EB',
          paddingBottom: 8,
          paddingTop: 8,
          height: 60,
        },
        tabBarLabelStyle: {
          fontSize: 12,
          fontWeight: '600',
        },
      }}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{
          tabBarIcon: ({ color, size }) => (
            <Icon name="home" size={size} color={color} />
          ),
        }}
      />
      <Tab.Screen
        name="Assets"
        component={AssetsScreen}
        options={{
          tabBarIcon: ({ color, size }) => (
            <Icon name="wallet" size={size} color={color} />
          ),
        }}
      />
      <Tab.Screen
        name="DApps"
        component={DAppsScreen}
        options={{
          tabBarIcon: ({ color, size }) => (
            <Icon name="apps" size={size} color={color} />
          ),
        }}
      />
      <Tab.Screen
        name="Settings"
        component={SettingsScreen}
        options={{
          tabBarIcon: ({ color, size }) => (
            <Icon name="cog" size={size} color={color} />
          ),
        }}
      />
    </Tab.Navigator>
  );
};

const MainNavigator: React.FC = () => {
  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        presentation: 'card',
      }}
    >
      <Stack.Screen name="MainTabs" component={MainTabs} />
      <Stack.Screen
        name="Send"
        component={SendScreen}
        options={{ presentation: 'modal' }}
      />
      <Stack.Screen
        name="Receive"
        component={ReceiveScreen}
        options={{ presentation: 'modal' }}
      />
      <Stack.Screen
        name="TransactionDetail"
        component={TransactionDetailScreen}
      />
      <Stack.Screen
        name="QRScanner"
        component={QRScannerScreen}
        options={{ presentation: 'fullScreenModal' }}
      />
      <Stack.Screen name="TokenDetail" component={TokenDetailScreen} />
      <Stack.Screen
        name="AddToken"
        component={AddTokenScreen}
        options={{ presentation: 'modal' }}
      />
      <Stack.Screen name="NetworkSelection" component={NetworkSelectionScreen} />
      <Stack.Screen name="BackupWallet" component={BackupWalletScreen} />
      <Stack.Screen name="SecuritySettings" component={SecuritySettingsScreen} />
    </Stack.Navigator>
  );
};

export default MainNavigator;
