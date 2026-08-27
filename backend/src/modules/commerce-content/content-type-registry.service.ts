import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  CommerceContentPublicationChannel,
  CommerceContentTypeDefinition,
  Prisma,
} from '@prisma/client';
import { serializeCommerceContentType } from '../../common/serializers';
import { CommerceContentRepository } from './commerce-content.repository';
import { RegisterContentTypeDto } from './dto/content-type.dto';

interface SchemaProperty {
  type?: string;
  enum?: unknown[];
  items?: SchemaProperty;
}

interface MinimalJsonSchema {
  type?: string;
  required?: string[];
  properties?: Record<string, SchemaProperty>;
}

export interface ContentValidationIssue {
  path: string;
  message: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function propertyType(value: unknown): string {
  if (Array.isArray(value)) return 'array';
  if (value === null) return 'null';
  if (Number.isInteger(value)) return 'integer';
  return typeof value;
}

function matchesExpectedType(value: unknown, expected: string): boolean {
  if (expected === 'array') return Array.isArray(value);
  if (expected === 'object') return isRecord(value);
  if (expected === 'integer') return Number.isInteger(value);
  if (expected === 'number') return typeof value === 'number' && Number.isFinite(value);
  return typeof value === expected;
}

export function validatePayloadAgainstSchema(
  schema: Prisma.JsonValue,
  payload: Record<string, unknown>,
): ContentValidationIssue[] {
  if (!isRecord(schema)) return [];
  const typed = schema as MinimalJsonSchema;
  const issues: ContentValidationIssue[] = [];

  if (typed.type && typed.type !== 'object') {
    issues.push({ path: '$', message: 'Content schema root must be an object' });
    return issues;
  }

  for (const key of typed.required ?? []) {
    if (!(key in payload)) {
      issues.push({ path: key, message: 'Required field is missing' });
    }
  }

  for (const [key, definition] of Object.entries(typed.properties ?? {})) {
    if (!(key in payload)) continue;
    const value = payload[key];
    if (definition.type && !matchesExpectedType(value, definition.type)) {
      issues.push({
        path: key,
        message: `Expected ${definition.type}, received ${propertyType(value)}`,
      });
      continue;
    }
    if (definition.enum && !definition.enum.includes(value)) {
      issues.push({ path: key, message: 'Value is not allowed for this field' });
    }
    if (definition.type === 'array' && definition.items && Array.isArray(value)) {
      value.forEach((item, index) => {
        if (
          definition.items?.type &&
          !matchesExpectedType(item, definition.items.type)
        ) {
          issues.push({
            path: `${key}.${index}`,
            message: `Expected ${definition.items.type}, received ${propertyType(item)}`,
          });
        }
      });
    }
  }

  return issues;
}

@Injectable()
export class ContentTypeRegistryService {
  constructor(private readonly repo: CommerceContentRepository) {}

  async list(includeInactive = false) {
    const types = await this.repo.listContentTypes(includeInactive);
    return types.map(serializeCommerceContentType);
  }

  async register(dto: RegisterContentTypeDto) {
    const definition = await this.repo.upsertContentType({
      key: dto.key,
      name: dto.name,
      description: dto.description,
      schema: dto.schema as Prisma.InputJsonValue,
      uiSchema: (dto.ui_schema as Prisma.InputJsonValue) ?? Prisma.JsonNull,
      capabilities: (dto.capabilities as Prisma.InputJsonValue) ?? Prisma.JsonNull,
      lifecycle: (dto.lifecycle as Prisma.InputJsonValue) ?? Prisma.JsonNull,
      active: dto.active ?? true,
      version: dto.version ?? 1,
    });
    return serializeCommerceContentType(definition);
  }

  async requireActive(key: string): Promise<CommerceContentTypeDefinition> {
    const definition = await this.repo.findContentType(key);
    if (!definition || !definition.active) {
      throw new NotFoundException(`Content type "${key}" is not available`);
    }
    return definition;
  }

  validatePayload(
    definition: CommerceContentTypeDefinition,
    payload: Record<string, unknown>,
  ) {
    const issues = validatePayloadAgainstSchema(definition.schema, payload);
    if (issues.length > 0) {
      throw new BadRequestException({
        message: 'Content payload does not match the content type schema',
        issues,
      });
    }
  }

  moderationRequired(definition: CommerceContentTypeDefinition): boolean {
    const capabilities = definition.capabilities;
    return isRecord(capabilities) && capabilities.moderation_required === true;
  }

  defaultChannels(
    definition: CommerceContentTypeDefinition,
  ): CommerceContentPublicationChannel[] {
    const lifecycle = definition.lifecycle;
    if (!isRecord(lifecycle) || !Array.isArray(lifecycle.default_channels)) {
      return [CommerceContentPublicationChannel.HOME_FEED];
    }
    const valid = new Set(Object.values(CommerceContentPublicationChannel));
    const channels = lifecycle.default_channels
      .map((value) => (typeof value === 'string' ? value.toUpperCase() : value))
      .filter((value): value is CommerceContentPublicationChannel =>
        valid.has(value as CommerceContentPublicationChannel),
      );
    return channels.length ? channels : [CommerceContentPublicationChannel.HOME_FEED];
  }

  expiresAfterHours(definition: CommerceContentTypeDefinition): number | null {
    const lifecycle = definition.lifecycle;
    if (!isRecord(lifecycle)) return null;
    const value = lifecycle.expires_after_hours;
    return typeof value === 'number' && value > 0 ? value : null;
  }
}
