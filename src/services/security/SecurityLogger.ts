/**
 * Security Logger
 *
 * Handles secure logging of security events while ensuring sensitive data is never logged
 */

import { SecurityConfig, SecurityEventType } from './SecurityConfig';

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  context?: Record<string, any>;
  eventType?: SecurityEventType;
}

/**
 * Security Logger Service
 */
export class SecurityLogger {
  private static instance: SecurityLogger;
  private logs: LogEntry[] = [];
  private maxLogs: number = 1000;

  private constructor() {}

  static getInstance(): SecurityLogger {
    if (!SecurityLogger.instance) {
      SecurityLogger.instance = new SecurityLogger();
    }
    return SecurityLogger.instance;
  }

  /**
   * Log debug message
   */
  debug(message: string, context?: Record<string, any>): void {
    if (this.shouldLog('debug')) {
      this.log('debug', message, context);
    }
  }

  /**
   * Log info message
   */
  info(message: string, context?: Record<string, any>): void {
    if (this.shouldLog('info')) {
      this.log('info', message, context);
    }
  }

  /**
   * Log warning message
   */
  warn(message: string, context?: Record<string, any>): void {
    if (this.shouldLog('warn')) {
      this.log('warn', message, context);
    }
  }

  /**
   * Log error message
   */
  error(message: string, context?: Record<string, any>): void {
    if (this.shouldLog('error')) {
      this.log('error', message, context);
    }
  }

  /**
   * Log security event
   */
  logSecurityEvent(
    eventType: SecurityEventType,
    message: string,
    context?: Record<string, any>
  ): void {
    this.log('info', message, context, eventType);
  }

  /**
   * Internal log method
   */
  private log(
    level: LogLevel,
    message: string,
    context?: Record<string, any>,
    eventType?: SecurityEventType
  ): void {
    const sanitizedContext = context ? this.sanitizeContext(context) : undefined;

    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      context: sanitizedContext,
      eventType,
    };

    this.logs.push(entry);

    // Trim logs if exceeded max
    if (this.logs.length > this.maxLogs) {
      this.logs = this.logs.slice(-this.maxLogs);
    }

    // Console output
    this.outputToConsole(entry);
  }

  /**
   * Sanitize context to remove sensitive data
   */
  private sanitizeContext(context: Record<string, any>): Record<string, any> {
    const sanitized: Record<string, any> = {};
    const sensitiveFields = SecurityConfig.logging.sensitiveFields;

    for (const [key, value] of Object.entries(context)) {
      const isSensitive = sensitiveFields.some(field =>
        key.toLowerCase().includes(field.toLowerCase())
      );

      if (isSensitive) {
        sanitized[key] = '[REDACTED]';
      } else if (value && typeof value === 'object') {
        sanitized[key] = this.sanitizeContext(value);
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  /**
   * Check if log level should be logged
   */
  private shouldLog(level: LogLevel): boolean {
    if (!SecurityConfig.logging.enabled) {
      return false;
    }

    const levels: LogLevel[] = ['debug', 'info', 'warn', 'error'];
    const configLevel = SecurityConfig.logging.logLevel as LogLevel;

    return levels.indexOf(level) >= levels.indexOf(configLevel);
  }

  /**
   * Output log to console
   */
  private outputToConsole(entry: LogEntry): void {
    const prefix = `[Security][${entry.level.toUpperCase()}]`;
    const output = `${prefix} ${entry.message}`;

    switch (entry.level) {
      case 'debug':
        console.debug(output, entry.context);
        break;
      case 'info':
        console.info(output, entry.context);
        break;
      case 'warn':
        console.warn(output, entry.context);
        break;
      case 'error':
        console.error(output, entry.context);
        break;
    }
  }

  /**
   * Get all logs
   */
  getLogs(filter?: {
    level?: LogLevel;
    eventType?: SecurityEventType;
    since?: Date;
  }): LogEntry[] {
    let filtered = [...this.logs];

    if (filter?.level) {
      filtered = filtered.filter(log => log.level === filter.level);
    }

    if (filter?.eventType) {
      filtered = filtered.filter(log => log.eventType === filter.eventType);
    }

    if (filter?.since) {
      filtered = filtered.filter(
        log => new Date(log.timestamp) >= filter.since!
      );
    }

    return filtered;
  }

  /**
   * Clear all logs
   */
  clearLogs(): void {
    this.logs = [];
  }

  /**
   * Export logs as JSON
   */
  exportLogs(): string {
    return JSON.stringify(this.logs, null, 2);
  }
}

export default SecurityLogger;
