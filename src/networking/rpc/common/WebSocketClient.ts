/**
 * WebSocket Client for Real-time Transaction Monitoring
 * Provides WebSocket connectivity with auto-reconnect
 */

import { EventEmitter } from 'events';
import {
  WebSocketConfig,
  TransactionMonitorEvent,
  ConnectionError,
  RPCClientError,
} from './types';

export interface WebSocketMessage {
  type: string;
  data: any;
  timestamp: number;
}

export class WebSocketClient extends EventEmitter {
  private ws: WebSocket | null = null;
  private reconnectAttempts: number = 0;
  private reconnectTimer?: NodeJS.Timeout;
  private pingTimer?: NodeJS.Timeout;
  private connected: boolean = false;
  private messageQueue: any[] = [];

  constructor(private config: WebSocketConfig) {
    super();
  }

  /**
   * Connect to WebSocket server
   */
  public async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        this.ws = new WebSocket(this.config.url);

        this.ws.onopen = () => {
          this.connected = true;
          this.reconnectAttempts = 0;
          this.emit('connected');
          this.startPing();
          this.flushMessageQueue();
          resolve();
        };

        this.ws.onmessage = (event) => {
          this.handleMessage(event.data);
        };

        this.ws.onerror = (error) => {
          this.emit('error', error);
          if (!this.connected) {
            reject(new ConnectionError('WebSocket connection failed'));
          }
        };

        this.ws.onclose = () => {
          this.connected = false;
          this.emit('disconnected');
          this.stopPing();

          if (this.config.reconnect) {
            this.scheduleReconnect();
          }
        };
      } catch (error) {
        reject(new ConnectionError(
          `Failed to create WebSocket connection: ${error instanceof Error ? error.message : 'Unknown error'}`
        ));
      }
    });
  }

  /**
   * Disconnect from WebSocket server
   */
  public disconnect(): void {
    this.config.reconnect = false; // Prevent auto-reconnect

    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
    }

    this.stopPing();

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }

    this.connected = false;
  }

  /**
   * Send message to server
   */
  public send(data: any): void {
    const message = JSON.stringify(data);

    if (!this.connected || !this.ws) {
      // Queue message if not connected
      this.messageQueue.push(message);
      return;
    }

    try {
      this.ws.send(message);
    } catch (error) {
      this.emit('error', new RPCClientError(
        `Failed to send message: ${error instanceof Error ? error.message : 'Unknown error'}`,
        -32007
      ));
    }
  }

  /**
   * Subscribe to transaction updates
   */
  public subscribeToAddress(address: string): void {
    this.send({
      type: 'subscribe',
      channel: 'address',
      address,
    });
  }

  /**
   * Subscribe to new blocks
   */
  public subscribeToBlocks(): void {
    this.send({
      type: 'subscribe',
      channel: 'blocks',
    });
  }

  /**
   * Subscribe to pending transactions
   */
  public subscribeToPendingTransactions(): void {
    this.send({
      type: 'subscribe',
      channel: 'pending_transactions',
    });
  }

  /**
   * Unsubscribe from channel
   */
  public unsubscribe(channel: string, address?: string): void {
    this.send({
      type: 'unsubscribe',
      channel,
      address,
    });
  }

  /**
   * Handle incoming message
   */
  private handleMessage(data: string): void {
    try {
      const message = JSON.parse(data);

      if (message.type === 'pong') {
        // Pong response to keep-alive
        return;
      }

      if (message.type === 'transaction') {
        this.handleTransactionEvent(message.data);
      } else if (message.type === 'block') {
        this.emit('block', message.data);
      } else if (message.type === 'error') {
        this.emit('error', new RPCClientError(
          message.error.message,
          message.error.code
        ));
      } else {
        this.emit('message', message);
      }
    } catch (error) {
      this.emit('error', new RPCClientError(
        `Failed to parse WebSocket message: ${error instanceof Error ? error.message : 'Unknown error'}`,
        -32008
      ));
    }
  }

  /**
   * Handle transaction event
   */
  private handleTransactionEvent(data: any): void {
    const event: TransactionMonitorEvent = {
      type: data.type || 'new_transaction',
      txHash: data.txHash || data.hash,
      blockHeight: data.blockHeight,
      confirmations: data.confirmations,
      data,
    };

    this.emit('transaction', event);
  }

  /**
   * Schedule reconnect attempt
   */
  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.config.maxReconnectAttempts) {
      this.emit('error', new ConnectionError(
        `Max reconnect attempts (${this.config.maxReconnectAttempts}) exceeded`
      ));
      return;
    }

    const delay = Math.min(
      this.config.reconnectInterval * Math.pow(2, this.reconnectAttempts),
      30000 // Max 30 seconds
    );

    this.reconnectTimer = setTimeout(() => {
      this.reconnectAttempts++;
      this.emit('reconnecting', this.reconnectAttempts);
      this.connect().catch(() => {
        // Will try again via onclose handler
      });
    }, delay);
  }

  /**
   * Start ping/keep-alive
   */
  private startPing(): void {
    if (!this.config.pingInterval) {
      return;
    }

    this.pingTimer = setInterval(() => {
      if (this.connected && this.ws) {
        this.send({ type: 'ping' });
      }
    }, this.config.pingInterval);
  }

  /**
   * Stop ping/keep-alive
   */
  private stopPing(): void {
    if (this.pingTimer) {
      clearInterval(this.pingTimer);
      this.pingTimer = undefined;
    }
  }

  /**
   * Flush queued messages
   */
  private flushMessageQueue(): void {
    while (this.messageQueue.length > 0 && this.connected) {
      const message = this.messageQueue.shift();
      if (this.ws) {
        this.ws.send(message);
      }
    }
  }

  /**
   * Check if connected
   */
  public isConnected(): boolean {
    return this.connected;
  }

  /**
   * Get connection stats
   */
  public getStats() {
    return {
      connected: this.connected,
      reconnectAttempts: this.reconnectAttempts,
      queuedMessages: this.messageQueue.length,
      url: this.config.url,
    };
  }
}
