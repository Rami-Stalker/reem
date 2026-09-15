import { Injectable, Logger } from '@nestjs/common';
import { supabaseRuntime } from '../runtime/env';

export class SupabaseHttpError extends Error {
  constructor(
    readonly status: number,
    readonly body: string,
    readonly path: string,
  ) {
    super(`Supabase ${path} answered ${status}: ${body.slice(0, 300)}`);
    this.name = 'SupabaseHttpError';
  }
}

export interface SupabaseRequest {
  method?: string;
  headers?: Record<string, string>;
  body?: BodyInit | null;
  json?: unknown;
  /** Defaults to the project secret key. */
  bearer?: string;
  timeoutMs?: number;
}

/**
 * Server-to-server calls to the project's own Storage, Realtime and Auth APIs.
 *
 * Authenticated with the project secret key, which Supabase injects into the
 * function's environment and which never leaves it. Nothing in here is
 * reachable from a client.
 */
@Injectable()
export class SupabaseHttp {
  private readonly logger = new Logger(SupabaseHttp.name);

  get url(): string {
    return supabaseRuntime().url;
  }

  async request(path: string, options: SupabaseRequest = {}): Promise<Response> {
    const { secretKey } = supabaseRuntime();
    const headers: Record<string, string> = {
      apikey: secretKey,
      Authorization: `Bearer ${options.bearer ?? secretKey}`,
      ...options.headers,
    };
    let body = options.body ?? null;
    if (options.json !== undefined) {
      headers['Content-Type'] = 'application/json';
      body = JSON.stringify(options.json);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), options.timeoutMs ?? 15_000);
    try {
      return await fetch(`${this.url}${path}`, {
        method: options.method ?? 'GET',
        headers,
        body,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }
  }

  /** Like `request`, but a non-2xx answer is an error carrying the body. */
  async expectOk(path: string, options: SupabaseRequest = {}): Promise<Response> {
    const response = await this.request(path, options);
    if (!response.ok) {
      const text = await response.text().catch(() => '');
      throw new SupabaseHttpError(response.status, text, path);
    }
    return response;
  }

  async json<T>(path: string, options: SupabaseRequest = {}): Promise<T> {
    const response = await this.expectOk(path, options);
    return (await response.json()) as T;
  }

  warn(message: string) {
    this.logger.warn(message);
  }
}
