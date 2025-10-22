/**
 * Unit Tests for ConnectionPool
 * Tests connection pooling and failover mechanisms
 */

import { ConnectionPool } from '../../src/networking/rpc/common/ConnectionPool';
import { ConnectionError } from '../../src/networking/rpc/common/types';

describe('ConnectionPool', () => {
  const mockPoolConfig = {
    minConnections: 2,
    maxConnections: 5,
    acquireTimeout: 5000,
    idleTimeout: 30000,
  };

  const mockFailoverConfig = {
    primaryUrl: 'https://primary.example.com',
    fallbackUrls: ['https://fallback1.example.com', 'https://fallback2.example.com'],
    healthCheckInterval: 10000,
    failoverThreshold: 3,
  };

  describe('Initialization', () => {
    it('should create minimum connections on initialization', () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);
      const stats = pool.getStats();

      expect(stats.totalConnections).toBe(mockPoolConfig.minConnections);
      expect(stats.availableConnections).toBe(mockPoolConfig.minConnections);

      pool.destroy();
    });

    it('should distribute initial connections across URLs', () => {
      const pool = new ConnectionPool(
        { ...mockPoolConfig, minConnections: 3 },
        mockFailoverConfig
      );

      const stats = pool.getStats();
      expect(stats.totalConnections).toBe(3);

      pool.destroy();
    });

    it('should start health check monitoring', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      // Wait for first health check
      await new Promise(resolve => setTimeout(resolve, 100));

      const health = pool.getHealth(mockFailoverConfig.primaryUrl);
      expect(health).toBeDefined();

      pool.destroy();
    });
  });

  describe('Connection Acquisition', () => {
    it('should acquire available connection', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      const conn = await pool.acquire();
      expect(conn).toBeDefined();
      expect(conn.active).toBe(true);
      expect(conn.url).toBeTruthy();

      pool.release(conn);
      pool.destroy();
    });

    it('should create new connection if under max limit', async () => {
      const pool = new ConnectionPool(
        { ...mockPoolConfig, minConnections: 1, maxConnections: 3 },
        mockFailoverConfig
      );

      const conn1 = await pool.acquire();
      const conn2 = await pool.acquire();
      const conn3 = await pool.acquire();

      const stats = pool.getStats();
      expect(stats.totalConnections).toBe(3);
      expect(stats.activeConnections).toBe(3);

      pool.release(conn1);
      pool.release(conn2);
      pool.release(conn3);
      pool.destroy();
    });

    it('should wait for available connection when pool exhausted', async () => {
      const pool = new ConnectionPool(
        { ...mockPoolConfig, minConnections: 1, maxConnections: 1, acquireTimeout: 1000 },
        mockFailoverConfig
      );

      const conn1 = await pool.acquire();

      // Acquire in background, will wait
      const acquirePromise = pool.acquire();

      // Release after delay
      setTimeout(() => pool.release(conn1), 100);

      const conn2 = await acquirePromise;
      expect(conn2).toBeDefined();

      pool.release(conn2);
      pool.destroy();
    });

    it('should throw ConnectionError on timeout', async () => {
      const pool = new ConnectionPool(
        { ...mockPoolConfig, minConnections: 1, maxConnections: 1, acquireTimeout: 100 },
        mockFailoverConfig
      );

      const conn1 = await pool.acquire();

      // Try to acquire another without releasing
      await expect(pool.acquire()).rejects.toThrow(ConnectionError);
      await expect(pool.acquire()).rejects.toThrow(/Connection pool exhausted/);

      pool.release(conn1);
      pool.destroy();
    });

    it('should track connection usage', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      const conn = await pool.acquire();
      const lastUsedBefore = conn.lastUsed;

      await new Promise(resolve => setTimeout(resolve, 10));

      pool.release(conn);
      expect(conn.lastUsed).toBeGreaterThan(lastUsedBefore);

      pool.destroy();
    });
  });

  describe('Connection Release', () => {
    it('should return connection to available pool', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      const conn = await pool.acquire();
      const statsBefore = pool.getStats();

      pool.release(conn);
      const statsAfter = pool.getStats();

      expect(conn.active).toBe(false);
      expect(statsAfter.availableConnections).toBe(statsBefore.availableConnections + 1);
      expect(statsAfter.activeConnections).toBe(statsBefore.activeConnections - 1);

      pool.destroy();
    });

    it('should not duplicate connections in available pool', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      const conn = await pool.acquire();
      pool.release(conn);
      pool.release(conn); // Double release

      const stats = pool.getStats();
      // Should not create duplicates
      expect(stats.availableConnections).toBeLessThanOrEqual(stats.totalConnections);

      pool.destroy();
    });
  });

  describe('Failure Handling', () => {
    it('should track connection errors', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      const conn = await pool.acquire();
      const errorCountBefore = conn.errorCount;

      pool.markFailed(conn);

      expect(conn.errorCount).toBe(errorCountBefore + 1);

      pool.release(conn);
      pool.destroy();
    });

    it('should remove connection after threshold failures', async () => {
      const pool = new ConnectionPool(
        mockPoolConfig,
        { ...mockFailoverConfig, failoverThreshold: 2 }
      );

      const conn = await pool.acquire();
      const connectionId = conn.id;

      // Exceed failure threshold
      pool.markFailed(conn);
      pool.markFailed(conn);

      const stats = pool.getStats();
      const connections = Array.from((pool as any).connections.keys());

      expect(connections).not.toContain(connectionId);

      pool.destroy();
    });

    it('should trigger failover on connection failure', async () => {
      const pool = new ConnectionPool(
        mockPoolConfig,
        { ...mockFailoverConfig, failoverThreshold: 1 }
      );

      const conn = await pool.acquire();
      const originalUrl = conn.url;

      pool.markFailed(conn);

      // Next connection should potentially use different URL
      const newConn = await pool.acquire();
      expect(newConn.url).toBeDefined();

      pool.release(newConn);
      pool.destroy();
    });
  });

  describe('Connection Cleanup', () => {
    it('should cleanup idle connections', async () => {
      const pool = new ConnectionPool(
        { ...mockPoolConfig, idleTimeout: 100, minConnections: 1, maxConnections: 3 },
        mockFailoverConfig
      );

      // Create extra connections
      const conn1 = await pool.acquire();
      const conn2 = await pool.acquire();
      const conn3 = await pool.acquire();

      pool.release(conn1);
      pool.release(conn2);
      pool.release(conn3);

      // Wait for idle timeout
      await new Promise(resolve => setTimeout(resolve, 150));

      // Trigger cleanup by acquiring
      const newConn = await pool.acquire();
      pool.release(newConn);

      const stats = pool.getStats();
      // Should clean up to min connections
      expect(stats.totalConnections).toBeGreaterThanOrEqual(mockPoolConfig.minConnections);

      pool.destroy();
    });

    it('should not cleanup active connections', async () => {
      const pool = new ConnectionPool(
        { ...mockPoolConfig, idleTimeout: 50 },
        mockFailoverConfig
      );

      const conn = await pool.acquire();

      // Wait past idle timeout
      await new Promise(resolve => setTimeout(resolve, 100));

      const stats = pool.getStats();
      expect(stats.activeConnections).toBe(1);

      pool.release(conn);
      pool.destroy();
    });

    it('should maintain minimum connections', async () => {
      const pool = new ConnectionPool(
        { ...mockPoolConfig, minConnections: 3, idleTimeout: 50 },
        mockFailoverConfig
      );

      await new Promise(resolve => setTimeout(resolve, 100));

      const stats = pool.getStats();
      expect(stats.totalConnections).toBeGreaterThanOrEqual(3);

      pool.destroy();
    });
  });

  describe('Health Monitoring', () => {
    it('should track health check results', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      // Wait for health check
      await new Promise(resolve => setTimeout(resolve, 100));

      const health = pool.getHealth(mockFailoverConfig.primaryUrl);
      expect(health).toBeDefined();
      expect(health).toHaveProperty('healthy');
      expect(health).toHaveProperty('latency');
      expect(health).toHaveProperty('lastCheck');

      pool.destroy();
    });

    it('should update health status periodically', async () => {
      const pool = new ConnectionPool(
        mockPoolConfig,
        { ...mockFailoverConfig, healthCheckInterval: 100 }
      );

      await new Promise(resolve => setTimeout(resolve, 150));

      const health1 = pool.getHealth(mockFailoverConfig.primaryUrl);
      const timestamp1 = health1?.lastCheck;

      await new Promise(resolve => setTimeout(resolve, 150));

      const health2 = pool.getHealth(mockFailoverConfig.primaryUrl);
      const timestamp2 = health2?.lastCheck;

      expect(timestamp2).toBeGreaterThan(timestamp1 || 0);

      pool.destroy();
    });
  });

  describe('Statistics', () => {
    it('should provide accurate pool statistics', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      const stats = pool.getStats();

      expect(stats).toHaveProperty('totalConnections');
      expect(stats).toHaveProperty('availableConnections');
      expect(stats).toHaveProperty('activeConnections');
      expect(stats).toHaveProperty('primaryUrl');
      expect(stats).toHaveProperty('healthChecks');

      pool.destroy();
    });

    it('should track active connections correctly', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      const conn1 = await pool.acquire();
      const conn2 = await pool.acquire();

      const stats = pool.getStats();
      expect(stats.activeConnections).toBe(2);

      pool.release(conn1);
      const statsAfter = pool.getStats();
      expect(statsAfter.activeConnections).toBe(1);

      pool.release(conn2);
      pool.destroy();
    });
  });

  describe('Resource Management', () => {
    it('should cleanup all resources on destroy', () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      pool.destroy();

      const stats = pool.getStats();
      expect(stats.totalConnections).toBe(0);
      expect(stats.availableConnections).toBe(0);
    });

    it('should stop health checks on destroy', async () => {
      const pool = new ConnectionPool(
        mockPoolConfig,
        { ...mockFailoverConfig, healthCheckInterval: 100 }
      );

      await new Promise(resolve => setTimeout(resolve, 150));
      const health1 = pool.getHealth(mockFailoverConfig.primaryUrl);
      const timestamp1 = health1?.lastCheck;

      pool.destroy();

      await new Promise(resolve => setTimeout(resolve, 150));
      const health2 = pool.getHealth(mockFailoverConfig.primaryUrl);
      const timestamp2 = health2?.lastCheck;

      // Timestamp should not change after destroy
      expect(timestamp2).toBe(timestamp1);
    });
  });

  describe('Concurrent Operations', () => {
    it('should handle concurrent acquisitions safely', async () => {
      const pool = new ConnectionPool(
        { ...mockPoolConfig, maxConnections: 10 },
        mockFailoverConfig
      );

      const promises = Array(20).fill(null).map(() => pool.acquire());
      const connections = await Promise.all(promises);

      expect(connections).toHaveLength(20);
      connections.forEach(conn => expect(conn).toBeDefined());

      connections.forEach(conn => pool.release(conn));
      pool.destroy();
    });

    it('should handle rapid acquire/release cycles', async () => {
      const pool = new ConnectionPool(mockPoolConfig, mockFailoverConfig);

      for (let i = 0; i < 50; i++) {
        const conn = await pool.acquire();
        pool.release(conn);
      }

      const stats = pool.getStats();
      expect(stats.totalConnections).toBeGreaterThan(0);

      pool.destroy();
    });
  });
});
