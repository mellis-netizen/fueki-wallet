/**
 * Connection Pool Manager
 * Manages a pool of RPC connections with failover support
 */

import { Connection, ConnectionPoolConfig, FailoverConfig, HealthCheck, ConnectionError } from './types';

export class ConnectionPool {
  private connections: Map<string, Connection> = new Map();
  private availableConnections: string[] = [];
  private activeUrls: string[];
  private currentPrimaryIndex: number = 0;
  private healthChecks: Map<string, HealthCheck> = new Map();
  private healthCheckInterval?: NodeJS.Timeout;

  constructor(
    private poolConfig: ConnectionPoolConfig,
    private failoverConfig: FailoverConfig
  ) {
    this.activeUrls = [
      failoverConfig.primaryUrl,
      ...failoverConfig.fallbackUrls,
    ];
    this.initialize();
  }

  /**
   * Initialize connection pool
   */
  private initialize(): void {
    // Create minimum connections
    for (let i = 0; i < this.poolConfig.minConnections; i++) {
      const url = this.activeUrls[i % this.activeUrls.length];
      this.createConnection(url);
    }

    // Start health check monitoring
    this.startHealthChecks();
  }

  /**
   * Create a new connection
   */
  private createConnection(url: string): Connection {
    const connection: Connection = {
      id: `conn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      url,
      active: false,
      lastUsed: Date.now(),
      requestCount: 0,
      errorCount: 0,
    };

    this.connections.set(connection.id, connection);
    this.availableConnections.push(connection.id);

    return connection;
  }

  /**
   * Acquire a connection from the pool
   */
  public async acquire(timeout: number = 5000): Promise<Connection> {
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      // Try to get available connection
      const connectionId = this.availableConnections.shift();

      if (connectionId) {
        const connection = this.connections.get(connectionId);
        if (connection) {
          connection.active = true;
          connection.lastUsed = Date.now();
          return connection;
        }
      }

      // Try to create new connection if under max
      if (this.connections.size < this.poolConfig.maxConnections) {
        const url = this.getPrimaryUrl();
        const connection = this.createConnection(url);
        connection.active = true;
        return connection;
      }

      // Wait and retry
      await new Promise(resolve => setTimeout(resolve, 50));
    }

    throw new ConnectionError(
      `Connection pool exhausted: could not acquire connection within ${timeout}ms`
    );
  }

  /**
   * Release connection back to pool
   */
  public release(connection: Connection): void {
    connection.active = false;
    connection.lastUsed = Date.now();

    // Add back to available pool
    if (!this.availableConnections.includes(connection.id)) {
      this.availableConnections.push(connection.id);
    }

    // Clean up idle connections
    this.cleanupIdleConnections();
  }

  /**
   * Mark connection as failed
   */
  public markFailed(connection: Connection): void {
    connection.errorCount++;

    // Remove from pool if error threshold exceeded
    if (connection.errorCount >= this.failoverConfig.failoverThreshold) {
      this.removeConnection(connection.id);
      this.handleFailover(connection.url);
    }
  }

  /**
   * Remove connection from pool
   */
  private removeConnection(connectionId: string): void {
    this.connections.delete(connectionId);
    this.availableConnections = this.availableConnections.filter(
      id => id !== connectionId
    );
  }

  /**
   * Clean up idle connections
   */
  private cleanupIdleConnections(): void {
    const now = Date.now();
    const idleTimeout = this.poolConfig.idleTimeout;

    for (const [id, conn] of this.connections) {
      if (
        !conn.active &&
        now - conn.lastUsed > idleTimeout &&
        this.connections.size > this.poolConfig.minConnections
      ) {
        this.removeConnection(id);
      }
    }
  }

  /**
   * Handle failover to next available URL
   */
  private handleFailover(failedUrl: string): void {
    console.warn(`Connection failed for ${failedUrl}, initiating failover`);

    // Find next healthy URL
    const currentIndex = this.activeUrls.indexOf(failedUrl);
    if (currentIndex !== -1) {
      // Rotate to next URL
      this.currentPrimaryIndex = (currentIndex + 1) % this.activeUrls.length;
    }
  }

  /**
   * Get current primary URL
   */
  private getPrimaryUrl(): string {
    return this.activeUrls[this.currentPrimaryIndex];
  }

  /**
   * Start health check monitoring
   */
  private startHealthChecks(): void {
    this.healthCheckInterval = setInterval(() => {
      this.performHealthChecks();
    }, this.failoverConfig.healthCheckInterval);
  }

  /**
   * Perform health checks on all URLs
   */
  private async performHealthChecks(): Promise<void> {
    for (const url of this.activeUrls) {
      try {
        const startTime = Date.now();

        // Simple health check - could be enhanced with actual RPC call
        const response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            jsonrpc: '2.0',
            method: 'ping',
            params: [],
            id: 1,
          }),
          signal: AbortSignal.timeout(5000),
        });

        const latency = Date.now() - startTime;

        this.healthChecks.set(url, {
          healthy: response.ok,
          latency,
          lastCheck: Date.now(),
        });
      } catch (error) {
        this.healthChecks.set(url, {
          healthy: false,
          latency: -1,
          lastCheck: Date.now(),
        });
      }
    }
  }

  /**
   * Get health status for a URL
   */
  public getHealth(url: string): HealthCheck | undefined {
    return this.healthChecks.get(url);
  }

  /**
   * Get pool statistics
   */
  public getStats() {
    return {
      totalConnections: this.connections.size,
      availableConnections: this.availableConnections.length,
      activeConnections: Array.from(this.connections.values()).filter(
        c => c.active
      ).length,
      primaryUrl: this.getPrimaryUrl(),
      healthChecks: Object.fromEntries(this.healthChecks),
    };
  }

  /**
   * Destroy pool and cleanup
   */
  public destroy(): void {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
    }
    this.connections.clear();
    this.availableConnections = [];
    this.healthChecks.clear();
  }
}
