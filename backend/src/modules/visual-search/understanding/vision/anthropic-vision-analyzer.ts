import { Logger } from '@nestjs/common';
import { ModestyLevel, OutfitSlot, StylePersona } from '@prisma/client';
import {
  COLOUR_KEYS,
  OCCASION_KEYS,
} from '../../../ai-stylist/understanding/style-brief';
import {
  VisionAnalysis,
  VisionAnalysisInput,
  VisionAnalyzer,
} from './vision-analyzer';

export interface AnthropicVisionConfig {
  apiKey: string;
  baseUrl: string;
  model: string;
  timeoutMs: number;
  maxOutputTokens: number;
  /** Whether to ask for garment boxes as well as a brief. */
  detectItems: boolean;
}

/**
 * Claude, reading a photograph.
 *
 * The defences are the same ones `AnthropicStylistLlm` carries, for the same
 * reasons, plus one the text path does not need:
 *
 *  - **It never sees an identity.** One image and a short instruction. No
 *    name, no phone, no order history, no user id. A picture leaving the
 *    building is already the most sensitive thing this feature handles; it
 *    leaves alone.
 *  - **It sees the re-encoded copy.** `ImageProcessingService` has already
 *    stripped EXIF, so the GPS tag on a photograph taken at her home does not
 *    travel with it.
 *  - **It never sees the catalogue.** Only the list of leaf category slugs it
 *    may choose among — which is a vocabulary, not an inventory, and carries
 *    no prices, no sellers and no stock.
 *  - **It cannot fail loudly.** Timeout, non-200, malformed JSON and
 *    unexpected shapes all return null, and the measured reading stands alone.
 *  - **Its output is not trusted.** Both halves are sanitised by the caller
 *    against closed vocabularies before anything reaches a query.
 */
export class AnthropicVisionAnalyzer implements VisionAnalyzer {
  private readonly logger = new Logger(AnthropicVisionAnalyzer.name);

  constructor(private readonly config: AnthropicVisionConfig) {}

  get name(): string {
    return this.config.model;
  }

  get enabled(): boolean {
    return Boolean(this.config.apiKey);
  }

  async analyse(input: VisionAnalysisInput): Promise<VisionAnalysis | null> {
    if (!this.enabled) return null;

    // A vocabulary, capped. The whole taxonomy would be several thousand
    // tokens on every search for a list the model only picks one entry from.
    const slugs = input.knownCategorySlugs.slice(0, 160);

    const payload = await this.send({
      system: systemPrompt(slugs, this.config.detectItems),
      image: input.image,
      mimeType: input.mimeType,
      instruction: [
        '<قياسات_النظام>',
        JSON.stringify({
          colours: input.measured.colours,
          pattern: input.measured.pattern,
          framing: input.measured.framing,
        }),
        '</قياسات_النظام>',
        '',
        'حلّلي الصورة وأعيدي كائن JSON واحدًا فقط، بلا أي نص قبله أو بعده.',
      ].join('\n'),
    });

    if (!payload) return null;

    const parsed = parseJsonObject(payload);
    if (!parsed || typeof parsed !== 'object') return null;

    const record = parsed as Record<string, unknown>;
    return { brief: record['brief'] ?? record, items: record['items'] ?? [] };
  }

  private async send(request: {
    system: string;
    image: Buffer;
    mimeType: string;
    instruction: string;
  }): Promise<string | null> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      const response = await fetch(
        `${this.config.baseUrl.replace(/\/+$/, '')}/v1/messages`,
        {
          method: 'POST',
          signal: controller.signal,
          headers: {
            'content-type': 'application/json',
            'x-api-key': this.config.apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: JSON.stringify({
            model: this.config.model,
            max_tokens: this.config.maxOutputTokens,
            temperature: 0,
            system: request.system,
            messages: [
              {
                role: 'user',
                content: [
                  {
                    type: 'image',
                    source: {
                      type: 'base64',
                      media_type: request.mimeType,
                      data: request.image.toString('base64'),
                    },
                  },
                  { type: 'text', text: request.instruction },
                ],
              },
            ],
          }),
        },
      );

      if (!response.ok) {
        this.logger.warn(
          `Vision model returned ${response.status}; using the measured reading.`,
        );
        return null;
      }

      const body = (await response.json()) as {
        content?: Array<{ type?: string; text?: string }>;
      };
      const text = (body.content ?? [])
        .filter((block) => block.type === 'text' && typeof block.text === 'string')
        .map((block) => block.text as string)
        .join('\n')
        .trim();

      return text || null;
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(
        `Vision model unavailable (${reason}); using the measured reading.`,
      );
      return null;
    } finally {
      clearTimeout(timer);
    }
  }
}

/** Pulls the first balanced `{...}` out of a reply. */
function parseJsonObject(text: string): unknown | null {
  const start = text.indexOf('{');
  if (start === -1) return null;

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = start; index < text.length; index += 1) {
    const char = text[index];

    if (inString) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === '"') inString = false;
      continue;
    }

    if (char === '"') inString = true;
    else if (char === '{') depth += 1;
    else if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        try {
          return JSON.parse(text.slice(start, index + 1));
        } catch {
          return null;
        }
      }
    }
  }
  return null;
}

function systemPrompt(slugs: readonly string[], detectItems: boolean): string {
  return [
    'أنتِ محلّلة صور داخل تطبيق تسوّق نسائي اسمه «ريم». مهمتك الوحيدة هي وصف ما',
    'في الصورة بكائن JSON منظّم. أنتِ لا تقترحين منتجات، ولا تذكرين أسماء منتجات',
    'أو أسعارًا أو بائعات، ولا تملكين بيانات المتجر إطلاقًا.',
    '',
    'أعيدي JSON بهذا الشكل بالضبط:',
    '{',
    '  "brief": {',
    `    "category_slugs": مصفوفة من ${JSON.stringify(slugs)},`,
    `    "slots": مصفوفة من ${JSON.stringify(Object.values(OutfitSlot))},`,
    `    "colours": مصفوفة من ${JSON.stringify(COLOUR_KEYS)},`,
    `    "occasion": ${JSON.stringify(OCCASION_KEYS)} أو null,`,
    `    "modesty": ${JSON.stringify(Object.values(ModestyLevel))},`,
    `    "personas": مصفوفة من ${JSON.stringify(Object.values(StylePersona))},`,
    '    "materials": مصفوفة بأسماء الخامات بالعربية إذا كانت واضحة فعلًا,',
    '    "keywords": كلمات عربية قصيرة تصف القصّة والتفاصيل,',
    '    "confidence": رقم بين 0 و 1',
    '  },',
    detectItems
      ? '  "items": [{ "slot": ..., "label": "اسم عربي قصير", "box": { "x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0 }, "confidence": 0.0 }]'
      : '  "items": []',
    '}',
    '',
    'قواعد صارمة:',
    '- استخدمي القيم المذكورة أعلاه حرفيًا. أي قيمة خارجها ستُحذف.',
    '- «قياسات_النظام» هي ألوان مقيسة من البكسل. لا تناقضيها إلا إذا كانت خاطئة بوضوح.',
    '- لا تصفي الشخص في الصورة، ولا عمره، ولا ملامحه، ولا عرقه، ولا جسده. القطع فقط.',
    '- إذا كانت الخامة غير مؤكدة فاتركي "materials" فارغة. التخمين أسوأ من الصمت.',
    detectItems
      ? '- ضعي في "items" القطع القابلة للشراء فقط (فستان، حقيبة، حذاء، إكسسوار)، بإحداثيات نسبية بين 0 و 1.'
      : '- اتركي "items" فارغة.',
    '- أعيدي JSON فقط، بلا شرح.',
  ].join('\n');
}
