import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Request, Response } from 'express';

interface ErrorBody {
  statusCode: number;
  message: string | string[];
  error: string;
  code: string;
  timestamp?: string;
  path?: string;
}

/**
 * Single source of truth for error responses. Produces the
 * `{ statusCode, message, error, code }` shape the Flutter ErrorMapper
 * understands, mapping NestJS HttpExceptions and Prisma errors to clean HTTP
 * semantics while keeping a stable machine-readable code for the client.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const body = {
      ...this.toBody(exception),
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    if (body.statusCode >= 500) {
      this.logger.error(
        `${request.method} ${request.url} -> ${body.statusCode}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    response.status(body.statusCode).json(body);
  }

  private toBody(exception: unknown): ErrorBody {
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        return {
          statusCode: status,
          message: res,
          error: this.errorTitleFor(status),
          code: this.codeFor(status, res),
        };
      }
      const obj = res as Record<string, unknown>;
      const message =
        (obj.message as string | string[] | undefined) ?? exception.message;
      return {
        statusCode: status,
        message,
        error: (obj.error as string | undefined) ?? this.errorTitleFor(status),
        code: this.normalizeCode(
          obj.code ?? obj.errorCode ?? obj.error_code,
          this.codeFor(status, message),
        ),
      };
    }

    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      return this.fromPrisma(exception);
    }

    if (exception instanceof Prisma.PrismaClientValidationError) {
      return {
        statusCode: HttpStatus.UNPROCESSABLE_ENTITY,
        message: 'Invalid data supplied',
        error: this.errorTitleFor(HttpStatus.UNPROCESSABLE_ENTITY),
        code: 'VALIDATION_ERROR',
      };
    }

    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      message:
        process.env.NODE_ENV === 'production'
          ? 'Internal server error'
          : exception instanceof Error
            ? exception.message
            : 'Internal server error',
      error: this.errorTitleFor(HttpStatus.INTERNAL_SERVER_ERROR),
      code: 'INTERNAL_ERROR',
    };
  }

  private fromPrisma(
    e: Prisma.PrismaClientKnownRequestError,
  ): ErrorBody {
    switch (e.code) {
      case 'P2002': {
        const target = (e.meta?.target as string[] | undefined)?.join(', ');
        return {
          statusCode: HttpStatus.CONFLICT,
          message: target
            ? `${target} already exists`
            : 'Resource already exists',
          error: this.errorTitleFor(HttpStatus.CONFLICT),
          code: 'CONFLICT',
        };
      }
      case 'P2025':
        return {
          statusCode: HttpStatus.NOT_FOUND,
          message: 'Resource not found',
          error: this.errorTitleFor(HttpStatus.NOT_FOUND),
          code: 'NOT_FOUND',
        };
      case 'P2003':
        return {
          statusCode: HttpStatus.BAD_REQUEST,
          message: 'Related resource does not exist',
          error: this.errorTitleFor(HttpStatus.BAD_REQUEST),
          code: 'FK_CONSTRAINT',
        };
      default:
        return {
          statusCode: HttpStatus.BAD_REQUEST,
          message: 'Database request failed',
          error: this.errorTitleFor(HttpStatus.BAD_REQUEST),
          code: 'DATABASE_REQUEST_FAILED',
        };
    }
  }

  private codeFor(status: number, message?: string | string[]): string {
    if (Array.isArray(message)) return 'VALIDATION_ERROR';

    switch (status) {
      case HttpStatus.BAD_REQUEST:
        return 'BAD_REQUEST';
      case HttpStatus.UNAUTHORIZED:
        return 'UNAUTHORIZED';
      case HttpStatus.FORBIDDEN:
        return 'FORBIDDEN';
      case HttpStatus.NOT_FOUND:
        return 'NOT_FOUND';
      case HttpStatus.CONFLICT:
        return 'CONFLICT';
      case HttpStatus.UNPROCESSABLE_ENTITY:
        return 'VALIDATION_ERROR';
      case HttpStatus.TOO_MANY_REQUESTS:
        return 'RATE_LIMITED';
      case HttpStatus.SERVICE_UNAVAILABLE:
        return 'SERVICE_UNAVAILABLE';
      default:
        return status >= 500 ? 'INTERNAL_ERROR' : `HTTP_${status}`;
    }
  }

  private normalizeCode(value: unknown, fallback: string): string {
    if (typeof value !== 'string' || value.trim().length === 0) {
      return fallback;
    }
    return value
      .trim()
      .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
      .replace(/[\s-]+/g, '_')
      .toUpperCase();
  }

  private errorTitleFor(status: number): string {
    const label = HttpStatus[status] as string | undefined;
    if (!label) return 'Error';
    return label
      .toLowerCase()
      .split('_')
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ');
  }
}
