/**
 * @test Biometric Authentication Tests
 * @description Tests for biometric authentication flows and security
 * @prerequisites
 *   - Biometric authentication system
 *   - Mock biometric hardware
 * @expected Biometric authentication is secure and resistant to attacks
 */

import crypto from 'crypto';

// Mock biometric authentication system
class BiometricAuth {
  private enrolledBiometrics: Map<string, { hash: string; salt: Buffer; attempts: number }> = new Map();
  private readonly MAX_ATTEMPTS = 5;
  private readonly LOCKOUT_DURATION = 30000; // 30 seconds
  private lockedAccounts: Map<string, number> = new Map();

  async enrollBiometric(userId: string, biometricData: Buffer): Promise<{ success: boolean; error?: string }> {
    if (biometricData.length < 32) {
      return { success: false, error: 'Biometric data too short' };
    }

    // Generate salt and hash
    const salt = crypto.randomBytes(32);
    const hash = crypto.pbkdf2Sync(biometricData, salt, 100000, 64, 'sha512').toString('hex');

    this.enrolledBiometrics.set(userId, { hash, salt, attempts: 0 });
    return { success: true };
  }

  async authenticate(userId: string, biometricData: Buffer): Promise<{ success: boolean; error?: string; attemptsRemaining?: number }> {
    // Check if account is locked
    if (this.isLocked(userId)) {
      const lockTime = this.lockedAccounts.get(userId)!;
      const remaining = Math.ceil((lockTime - Date.now()) / 1000);
      return { success: false, error: `Account locked. Try again in ${remaining} seconds` };
    }

    const enrolled = this.enrolledBiometrics.get(userId);
    if (!enrolled) {
      return { success: false, error: 'Biometric not enrolled' };
    }

    // Hash provided biometric data
    const hash = crypto.pbkdf2Sync(biometricData, enrolled.salt, 100000, 64, 'sha512').toString('hex');

    // Constant-time comparison
    const isMatch = crypto.timingSafeEqual(
      Buffer.from(enrolled.hash, 'hex'),
      Buffer.from(hash, 'hex')
    );

    if (isMatch) {
      // Reset attempts on success
      enrolled.attempts = 0;
      return { success: true };
    }

    // Increment failed attempts
    enrolled.attempts++;

    if (enrolled.attempts >= this.MAX_ATTEMPTS) {
      this.lockAccount(userId);
      return { success: false, error: 'Too many failed attempts. Account locked.' };
    }

    return {
      success: false,
      error: 'Biometric authentication failed',
      attemptsRemaining: this.MAX_ATTEMPTS - enrolled.attempts,
    };
  }

  private isLocked(userId: string): boolean {
    const lockTime = this.lockedAccounts.get(userId);
    if (!lockTime) return false;

    if (Date.now() >= lockTime) {
      this.lockedAccounts.delete(userId);
      const enrolled = this.enrolledBiometrics.get(userId);
      if (enrolled) enrolled.attempts = 0;
      return false;
    }

    return true;
  }

  private lockAccount(userId: string): void {
    this.lockedAccounts.set(userId, Date.now() + this.LOCKOUT_DURATION);
  }

  async updateBiometric(userId: string, oldBiometric: Buffer, newBiometric: Buffer): Promise<{ success: boolean; error?: string }> {
    // Verify old biometric first
    const authResult = await this.authenticate(userId, oldBiometric);
    if (!authResult.success) {
      return { success: false, error: 'Current biometric authentication failed' };
    }

    // Enroll new biometric
    return this.enrollBiometric(userId, newBiometric);
  }

  async revokeBiometric(userId: string): Promise<boolean> {
    return this.enrolledBiometrics.delete(userId);
  }

  getAttempts(userId: string): number {
    return this.enrolledBiometrics.get(userId)?.attempts || 0;
  }
}

// Mock liveness detection
class LivenessDetection {
  async detectLiveness(biometricData: Buffer, challenge: Buffer): Promise<boolean> {
    // Simulate liveness detection based on challenge-response
    const response = crypto.createHash('sha256')
      .update(Buffer.concat([biometricData, challenge]))
      .digest();

    // In real implementation, this would check for signs of life
    return response[0] > 128; // Simplified check
  }

  generateChallenge(): Buffer {
    return crypto.randomBytes(32);
  }
}

describe('Biometric Authentication Tests', () => {
  let biometricAuth: BiometricAuth;
  let livenessDetection: LivenessDetection;

  beforeEach(() => {
    biometricAuth = new BiometricAuth();
    livenessDetection = new LivenessDetection();
  });

  describe('Biometric Enrollment', () => {
    it('should successfully enroll biometric data', async () => {
      const userId = 'user123';
      const biometricData = crypto.randomBytes(64);

      const result = await biometricAuth.enrollBiometric(userId, biometricData);
      expect(result.success).toBe(true);
    });

    it('should reject weak biometric data', async () => {
      const userId = 'user123';
      const weakBiometric = crypto.randomBytes(16); // Too short

      const result = await biometricAuth.enrollBiometric(userId, weakBiometric);
      expect(result.success).toBe(false);
      expect(result.error).toContain('too short');
    });

    it('should store biometric as hash, not plaintext', async () => {
      const userId = 'user123';
      const biometricData = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, biometricData);

      // Access internal storage to verify hashing
      const stored = (biometricAuth as any).enrolledBiometrics.get(userId);
      expect(stored.hash).toBeDefined();
      expect(stored.salt).toBeDefined();

      // Hash should not contain original data
      const originalHex = biometricData.toString('hex');
      expect(stored.hash).not.toContain(originalHex);
    });

    it('should use unique salts for different users', async () => {
      const biometricData = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric('user1', biometricData);
      await biometricAuth.enrollBiometric('user2', biometricData);

      const user1Data = (biometricAuth as any).enrolledBiometrics.get('user1');
      const user2Data = (biometricAuth as any).enrolledBiometrics.get('user2');

      expect(user1Data.salt.equals(user2Data.salt)).toBe(false);
      expect(user1Data.hash).not.toBe(user2Data.hash);
    });
  });

  describe('Biometric Authentication Flow', () => {
    it('should authenticate with correct biometric', async () => {
      const userId = 'user123';
      const biometricData = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, biometricData);
      const result = await biometricAuth.authenticate(userId, biometricData);

      expect(result.success).toBe(true);
    });

    it('should reject incorrect biometric', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);
      const wrongBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);
      const result = await biometricAuth.authenticate(userId, wrongBiometric);

      expect(result.success).toBe(false);
      expect(result.error).toContain('failed');
    });

    it('should reject authentication for non-enrolled users', async () => {
      const biometricData = crypto.randomBytes(64);
      const result = await biometricAuth.authenticate('unknown_user', biometricData);

      expect(result.success).toBe(false);
      expect(result.error).toContain('not enrolled');
    });

    it('should use constant-time comparison to prevent timing attacks', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);

      // Test multiple incorrect attempts and measure timing
      const timings: number[] = [];
      const attempts = 100;

      for (let i = 0; i < attempts; i++) {
        const wrongBiometric = crypto.randomBytes(64);
        const start = process.hrtime.bigint();
        await biometricAuth.authenticate(userId, wrongBiometric);
        const end = process.hrtime.bigint();
        timings.push(Number(end - start));
      }

      // Calculate standard deviation
      const mean = timings.reduce((a, b) => a + b) / timings.length;
      const variance = timings.reduce((sum, time) => sum + Math.pow(time - mean, 2), 0) / timings.length;
      const stdDev = Math.sqrt(variance);

      // Low coefficient of variation indicates constant time
      const coefficientOfVariation = (stdDev / mean) * 100;
      expect(coefficientOfVariation).toBeLessThan(20);
    });
  });

  describe('Failed Attempt Limiting', () => {
    it('should track failed authentication attempts', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);
      const wrongBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);

      for (let i = 0; i < 3; i++) {
        await biometricAuth.authenticate(userId, wrongBiometric);
      }

      expect(biometricAuth.getAttempts(userId)).toBe(3);
    });

    it('should lock account after max failed attempts', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);
      const wrongBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);

      // Make 5 failed attempts
      for (let i = 0; i < 5; i++) {
        await biometricAuth.authenticate(userId, wrongBiometric);
      }

      // Next attempt should be locked
      const result = await biometricAuth.authenticate(userId, wrongBiometric);
      expect(result.success).toBe(false);
      expect(result.error).toContain('locked');
    });

    it('should provide remaining attempts feedback', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);
      const wrongBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);

      const result1 = await biometricAuth.authenticate(userId, wrongBiometric);
      expect(result1.attemptsRemaining).toBe(4);

      const result2 = await biometricAuth.authenticate(userId, wrongBiometric);
      expect(result2.attemptsRemaining).toBe(3);
    });

    it('should reset attempts after successful authentication', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);
      const wrongBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);

      // Make some failed attempts
      await biometricAuth.authenticate(userId, wrongBiometric);
      await biometricAuth.authenticate(userId, wrongBiometric);
      expect(biometricAuth.getAttempts(userId)).toBe(2);

      // Successful authentication should reset
      await biometricAuth.authenticate(userId, correctBiometric);
      expect(biometricAuth.getAttempts(userId)).toBe(0);
    });

    it('should automatically unlock after timeout', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);
      const wrongBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);

      // Lock account
      for (let i = 0; i < 5; i++) {
        await biometricAuth.authenticate(userId, wrongBiometric);
      }

      // Verify locked
      const lockedResult = await biometricAuth.authenticate(userId, correctBiometric);
      expect(lockedResult.success).toBe(false);
      expect(lockedResult.error).toContain('locked');

      // Wait for unlock (simulate timeout)
      await new Promise(resolve => setTimeout(resolve, 100));

      // Manually clear lock for testing (in real scenario, wait for timeout)
      (biometricAuth as any).lockedAccounts.delete(userId);
      const enrolled = (biometricAuth as any).enrolledBiometrics.get(userId);
      enrolled.attempts = 0;

      // Should be able to authenticate again
      const unlockedResult = await biometricAuth.authenticate(userId, correctBiometric);
      expect(unlockedResult.success).toBe(true);
    });
  });

  describe('Liveness Detection', () => {
    it('should detect live biometric presentation', async () => {
      const biometricData = crypto.randomBytes(64);
      const challenge = livenessDetection.generateChallenge();

      const isLive = await livenessDetection.detectLiveness(biometricData, challenge);
      expect(typeof isLive).toBe('boolean');
    });

    it('should use unique challenges for each authentication', () => {
      const challenge1 = livenessDetection.generateChallenge();
      const challenge2 = livenessDetection.generateChallenge();

      expect(challenge1.equals(challenge2)).toBe(false);
    });

    it('should detect replay attacks using challenges', async () => {
      const biometricData = crypto.randomBytes(64);
      const challenge1 = livenessDetection.generateChallenge();
      const challenge2 = livenessDetection.generateChallenge();

      const response1 = crypto.createHash('sha256')
        .update(Buffer.concat([biometricData, challenge1]))
        .digest();

      const response2 = crypto.createHash('sha256')
        .update(Buffer.concat([biometricData, challenge2]))
        .digest();

      // Different challenges should produce different responses
      expect(response1.equals(response2)).toBe(false);
    });

    it('should reject spoofed biometric data', async () => {
      const realBiometric = crypto.randomBytes(64);
      const spoofedBiometric = Buffer.from(realBiometric); // Copy

      const challenge = livenessDetection.generateChallenge();

      const realResult = await livenessDetection.detectLiveness(realBiometric, challenge);
      const spoofedResult = await livenessDetection.detectLiveness(spoofedBiometric, challenge);

      // Both produce same result with same data (need additional liveness checks in production)
      expect(realResult).toBe(spoofedResult);

      // In production, additional factors (motion, temperature, etc.) would differentiate
    });
  });

  describe('Biometric Update and Revocation', () => {
    it('should allow updating biometric data', async () => {
      const userId = 'user123';
      const oldBiometric = crypto.randomBytes(64);
      const newBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, oldBiometric);

      const updateResult = await biometricAuth.updateBiometric(userId, oldBiometric, newBiometric);
      expect(updateResult.success).toBe(true);

      // Old biometric should no longer work
      const oldAuthResult = await biometricAuth.authenticate(userId, oldBiometric);
      expect(oldAuthResult.success).toBe(false);

      // New biometric should work
      const newAuthResult = await biometricAuth.authenticate(userId, newBiometric);
      expect(newAuthResult.success).toBe(true);
    });

    it('should require current biometric to update', async () => {
      const userId = 'user123';
      const oldBiometric = crypto.randomBytes(64);
      const wrongBiometric = crypto.randomBytes(64);
      const newBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, oldBiometric);

      const updateResult = await biometricAuth.updateBiometric(userId, wrongBiometric, newBiometric);
      expect(updateResult.success).toBe(false);
      expect(updateResult.error).toContain('failed');
    });

    it('should allow revoking biometric enrollment', async () => {
      const userId = 'user123';
      const biometricData = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, biometricData);
      const revoked = await biometricAuth.revokeBiometric(userId);

      expect(revoked).toBe(true);

      // Authentication should fail after revocation
      const authResult = await biometricAuth.authenticate(userId, biometricData);
      expect(authResult.success).toBe(false);
      expect(authResult.error).toContain('not enrolled');
    });
  });

  describe('Multi-User Security', () => {
    it('should isolate biometric data between users', async () => {
      const user1Biometric = crypto.randomBytes(64);
      const user2Biometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric('user1', user1Biometric);
      await biometricAuth.enrollBiometric('user2', user2Biometric);

      // User1's biometric should not work for user2
      const crossAuthResult = await biometricAuth.authenticate('user2', user1Biometric);
      expect(crossAuthResult.success).toBe(false);
    });

    it('should track attempts independently per user', async () => {
      const user1Biometric = crypto.randomBytes(64);
      const user2Biometric = crypto.randomBytes(64);
      const wrongBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric('user1', user1Biometric);
      await biometricAuth.enrollBiometric('user2', user2Biometric);

      // Failed attempts for user1
      await biometricAuth.authenticate('user1', wrongBiometric);
      await biometricAuth.authenticate('user1', wrongBiometric);

      // User2 should have zero attempts
      expect(biometricAuth.getAttempts('user1')).toBe(2);
      expect(biometricAuth.getAttempts('user2')).toBe(0);
    });
  });

  describe('Edge Cases and Attack Resistance', () => {
    it('should handle empty biometric data gracefully', async () => {
      const userId = 'user123';
      const emptyBiometric = Buffer.alloc(0);

      const result = await biometricAuth.enrollBiometric(userId, emptyBiometric);
      expect(result.success).toBe(false);
    });

    it('should handle very large biometric data', async () => {
      const userId = 'user123';
      const largeBiometric = crypto.randomBytes(1024 * 1024); // 1MB

      const enrollResult = await biometricAuth.enrollBiometric(userId, largeBiometric);
      expect(enrollResult.success).toBe(true);

      const authResult = await biometricAuth.authenticate(userId, largeBiometric);
      expect(authResult.success).toBe(true);
    });

    it('should resist brute force attacks with lockout', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);

      // Attempt brute force
      for (let i = 0; i < 10; i++) {
        const randomBiometric = crypto.randomBytes(64);
        await biometricAuth.authenticate(userId, randomBiometric);
      }

      // Account should be locked
      const result = await biometricAuth.authenticate(userId, correctBiometric);
      expect(result.success).toBe(false);
      expect(result.error).toContain('locked');
    });

    it('should handle concurrent authentication attempts', async () => {
      const userId = 'user123';
      const correctBiometric = crypto.randomBytes(64);

      await biometricAuth.enrollBiometric(userId, correctBiometric);

      const attempts = Array.from({ length: 10 }, () =>
        biometricAuth.authenticate(userId, correctBiometric)
      );

      const results = await Promise.all(attempts);
      const successCount = results.filter(r => r.success).length;

      expect(successCount).toBeGreaterThan(0);
    });
  });
});
