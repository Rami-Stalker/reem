import { Logger } from '@nestjs/common';
import {
  PhrasedInsight,
  PhrasingRequest,
  TrendLlm,
} from './trend-llm';

export interface AnthropicTrendConfig {
  apiKey: string;
  baseUrl: string;
  model: string;
  timeoutMs: number;
  maxOutputTokens: number;
  /** Findings per request. Batched so one run has one voice. */
  batchSize: number;
}

/**
 * Claude, used for the one thing a language model is better at here than a
 * template: writing a sentence a busy woman actually wants to read at eight in
 * the morning.
 *
 * Everything about this class is defensive, and the defences are specific:
 *
 *  - **It never sees an identity.** The payload is a finding: a kind, a
 *    subject label, and a bag of numbers. No customer, no order, no phone
 *    number, no seller id — a seller's *own* product title is the most
 *    identifying thing in it.
 *  - **It never sees the catalogue or the database.** It cannot name a product
 *    that does not exist because it is not shown any products; it is shown one
 *    title and told to talk about it.
 *  - **Every number it may use is handed to it, pre-rounded.** The prompt says
 *    so, and `sanitise()` below throws away any reply that invents a figure the
 *    finding did not carry. That check is the load-bearing one: a warm sentence
 *    with a wrong percentage in it is worse than a cold sentence with a right
 *    one, because a seller will act on it.
 *  - **It cannot fail loudly.** Timeout, non-200, malformed JSON, wrong shape,
 *    empty batch — every path returns an empty map, and the caller keeps the
 *    Arabic templates it already computed.
 */
export class AnthropicTrendLlm implements TrendLlm {
  private readonly logger = new Logger(AnthropicTrendLlm.name);

  constructor(private readonly config: AnthropicTrendConfig) {}

  get name(): string {
    return this.config.model;
  }

  get enabled(): boolean {
    return Boolean(this.config.apiKey);
  }

  async phrase(
    findings: readonly PhrasingRequest[],
  ): Promise<Map<string, PhrasedInsight>> {
    const out = new Map<string, PhrasedInsight>();
    if (!this.enabled || !findings.length) return out;

    const size = Math.max(1, this.config.batchSize);
    for (let index = 0; index < findings.length; index += size) {
      const batch = findings.slice(index, index + size);
      const phrased = await this.phraseBatch(batch);
      for (const [key, value] of phrased) out.set(key, value);
    }
    return out;
  }

  private async phraseBatch(
    batch: readonly PhrasingRequest[],
  ): Promise<Map<string, PhrasedInsight>> {
    const out = new Map<string, PhrasedInsight>();

    const payload = batch.map((finding) => ({
      id: finding.dedupeKey,
      kind: finding.kind,
      severity: finding.severity,
      audience: finding.audience,
      subject: finding.subjectLabel,
      // Pre-rounded, and the only numbers the reply may contain.
      figures: finding.metrics,
      reference: finding.fallback,
    }));

    const text = await this.send({
      system: SYSTEM_PROMPT,
      maxTokens: Math.min(this.config.maxOutputTokens, 400 * batch.length + 400),
      messages: [
        {
          role: 'user',
          content: [
            '<ملاحظات>',
            JSON.stringify(payload, null, 1),
            '</ملاحظات>',
            '',
            'أعيدي مصفوفة JSON واحدة فقط، بلا أي نص قبلها أو بعدها.',
          ].join('\n'),
        },
      ],
    });
    if (!text) return out;

    const parsed = parseJsonArray(text);
    if (!parsed) {
      this.logger.warn('Trend model returned no usable JSON; keeping templates.');
      return out;
    }

    const byKey = new Map(batch.map((finding) => [finding.dedupeKey, finding]));
    for (const entry of parsed) {
      if (!entry || typeof entry !== 'object' || Array.isArray(entry)) continue;
      const row = entry as Record<string, unknown>;
      const id = typeof row.id === 'string' ? row.id : null;
      if (!id) continue;
      const finding = byKey.get(id);
      if (!finding) continue;

      const candidate = sanitise(row, finding);
      if (candidate) out.set(id, candidate);
    }

    if (out.size < batch.length) {
      this.logger.debug(
        `Trend model phrased ${out.size}/${batch.length}; the rest kept their templates.`,
      );
    }
    return out;
  }

  private async send(request: {
    system: string;
    maxTokens: number;
    messages: Array<{ role: 'user'; content: string }>;
  }): Promise<string | null> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      const response = await fetch(`${this.config.baseUrl}/v1/messages`, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'content-type': 'application/json',
          'x-api-key': this.config.apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: this.config.model,
          max_tokens: request.maxTokens,
          // Low, not zero: these are short business sentences, and the job is
          // clarity rather than variety.
          temperature: 0.3,
          system: request.system,
          messages: request.messages,
        }),
      });

      if (!response.ok) {
        this.logger.warn(
          `Trend model returned ${response.status}; keeping the Arabic templates.`,
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
        `Trend model unavailable (${reason}); keeping the Arabic templates.`,
      );
      return null;
    } finally {
      clearTimeout(timer);
    }
  }
}

/**
 * Accept a rewrite only if it is Arabic, the right length, and quotes no
 * number the finding did not carry.
 *
 * The numeric check is the important one and it is deliberately strict: every
 * numeric literal in the reply must appear among the finding's own figures (or
 * be a small integer, which is how «خلال ٧ أيام» and ordinals get written).
 * A model that decorates a real 34% with an invented "بزيادة ١٢ نقطة" fails
 * the check and the whole rewrite is dropped, template intact. Half-trusting a
 * sentence is not an option — a reader cannot tell which half.
 */
function sanitise(
  row: Record<string, unknown>,
  finding: PhrasingRequest,
): PhrasedInsight | null {
  const title = trimmed(row.title_ar ?? row.titleAr);
  const body = trimmed(row.body_ar ?? row.bodyAr);
  const action = trimmed(row.action_ar ?? row.actionAr);

  if (!title || !body) return null;
  if (title.length > 120 || body.length > 420) return null;
  if (action && action.length > 160) return null;
  // Arabic, not a translation and not an apology in English.
  if (!/[؀-ۿ]/.test(body)) return null;

  const allowed = allowedNumbers(finding.metrics);
  for (const text of [title, body, action ?? '']) {
    for (const literal of numericLiterals(text)) {
      if (allowed.has(literal)) continue;
      // Small integers are counting words, not claims.
      if (literal <= 31 && Number.isInteger(literal)) continue;
      return null;
    }
  }

  return {
    titleAr: title,
    bodyAr: body,
    actionAr: action ?? finding.fallback.actionAr,
  };
}

function trimmed(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const text = value.replace(/\s+/g, ' ').trim();
  return text || null;
}

/**
 * Every figure the finding carries, plus the roundings a writer would
 * naturally reach for. Without the roundings, a model that writes "٣٤٪" for a
 * metric of 33.7 would be rejected for being sensible.
 */
function allowedNumbers(
  metrics: Record<string, number | string | boolean | null>,
): Set<number> {
  const allowed = new Set<number>();
  for (const value of Object.values(metrics)) {
    const numeric =
      typeof value === 'number'
        ? value
        : typeof value === 'string' && /^-?\d+(\.\d+)?$/.test(value)
          ? Number(value)
          : null;
    if (numeric === null || !Number.isFinite(numeric)) continue;

    allowed.add(Math.abs(numeric));
    allowed.add(Math.abs(Math.round(numeric)));
    allowed.add(Math.abs(Number(numeric.toFixed(1))));
    // A rate of 0.34 is written as 34٪.
    if (Math.abs(numeric) <= 1) {
      allowed.add(Math.abs(Number((numeric * 100).toFixed(1))));
      allowed.add(Math.abs(Math.round(numeric * 100)));
    }
  }
  return allowed;
}

/** Every number written in the text, Arabic-Indic digits included. */
function numericLiterals(text: string): number[] {
  const western = text.replace(/[٠-٩]/g, (digit) =>
    String('٠١٢٣٤٥٦٧٨٩'.indexOf(digit)),
  );
  return [...western.matchAll(/\d+(?:[.,]\d+)?/g)]
    .map((match) => Number(match[0].replace(',', '.')))
    .filter((value) => Number.isFinite(value));
}

/**
 * Pulls the first balanced `[...]` out of a reply.
 *
 * Same reasoning as the stylist's object scanner: models fence JSON, preface
 * it and apologise before it, and a greedy regex swallows trailing prose while
 * a lazy one truncates nested objects.
 */
function parseJsonArray(text: string): unknown[] | null {
  const start = text.indexOf('[');
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
    else if (char === '[' || char === '{') depth += 1;
    else if (char === ']' || char === '}') {
      depth -= 1;
      if (depth === 0) {
        try {
          const parsed: unknown = JSON.parse(text.slice(start, index + 1));
          return Array.isArray(parsed) ? parsed : null;
        } catch {
          return null;
        }
      }
    }
  }
  return null;
}

const SYSTEM_PROMPT = [
  'أنتِ محرّرة تقارير داخل منصّة تسوّق نسائية اسمها «أوهارا». يصلك تحليلٌ جاهز',
  'أنجزه النظام، ومهمتك الوحيدة أن تعيدي صياغته بالعربية بجُمَل قصيرة وواضحة.',
  '',
  'أنتِ لا تحلّلين ولا تحسبين ولا تستنتجين. كل رقم تحتاجينه موجود في «figures».',
  '',
  'لكل ملاحظة أعيدي كائنًا بهذا الشكل:',
  '{ "id": "نفس المعرّف", "title_ar": "عنوان قصير", "body_ar": "جملتان على الأكثر",',
  '  "action_ar": "توصية واحدة قابلة للتنفيذ أو null" }',
  '',
  'قواعد صارمة:',
  '- استخدمي الأرقام الواردة في "figures" فقط، بلا تعديل ولا حساب جديد ولا أرقام إضافية.',
  '- لا تخترعي أسماء منتجات أو بائعات أو فئات؛ استخدمي "subject" كما هو.',
  '- لا تعِدي بنتائج ولا تذكري خصومات أو مواعيد لم ترد في البيانات.',
  '- audience = SELLER: خاطبي البائعة مباشرةً بضمير المخاطبة، بنبرة عملية مشجّعة.',
  '- audience = ADMIN: اكتبي بنبرة تقرير سوق محايد، بلا مخاطبة.',
  '- العنوان أقل من ٨٠ حرفًا، والنص أقل من ٣٠٠ حرف.',
  '- "reference" هي صياغة النظام؛ حسّني أسلوبها ولا تغيّري معناها ولا أرقامها.',
  '- أعيدي مصفوفة JSON فقط، بلا شرح ولا أسوار برمجية.',
].join('\n');
