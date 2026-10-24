import { Logger } from '@nestjs/common';
import { ModestyLevel, OutfitSlot, StylePersona } from '@prisma/client';
import {
  BriefExtractionInput,
  ReplyCompositionInput,
  StylistLlm,
} from './stylist-llm';
import { COLOUR_KEYS, OCCASION_KEYS } from '../understanding/style-brief';

export interface AnthropicStylistConfig {
  apiKey: string;
  baseUrl: string;
  model: string;
  timeoutMs: number;
  maxOutputTokens: number;
  composeReplies: boolean;
}

/**
 * Claude, used for the two things a language model is actually better at than
 * a regular expression: reading an unusual sentence, and writing a warm one.
 *
 * Everything about this class is defensive by design.
 *
 *  - **It never sees an identity.** The prompt carries the message text and the
 *    brief — an occasion, a colour, a budget band. No name, no phone, no
 *    address, no order history, no user id. A shopping brief leaving the
 *    building is a different thing from a customer leaving the building.
 *  - **It never sees the catalog on the extraction path.** Reading a sentence
 *    does not require knowing what is in stock, and not sending it removes any
 *    route by which a model could name a product.
 *  - **It cannot fail loudly.** Every path returns null on timeout, transport
 *    error, non-200, malformed JSON, or an unexpected shape. The caller then
 *    uses the rules result, which is always computed first.
 *  - **Its output is not trusted.** `extractBrief` returns `unknown`; the
 *    caller runs `sanitiseBrief` over it, which drops anything outside the
 *    closed vocabularies.
 */
export class AnthropicStylistLlm implements StylistLlm {
  private readonly logger = new Logger(AnthropicStylistLlm.name);

  constructor(private readonly config: AnthropicStylistConfig) {}

  get name(): string {
    return this.config.model;
  }

  get enabled(): boolean {
    return Boolean(this.config.apiKey);
  }

  async extractBrief(input: BriefExtractionInput): Promise<unknown | null> {
    if (!this.enabled) return null;

    const history = input.history
      .slice(-6)
      .map((turn) => `${turn.role === 'user' ? 'العميلة' : 'أوهارا'}: ${turn.content}`)
      .join('\n');

    const payload = await this.send({
      system: EXTRACTION_SYSTEM_PROMPT,
      maxTokens: 700,
      messages: [
        {
          role: 'user',
          content: [
            history ? `<محادثة_سابقة>\n${history}\n</محادثة_سابقة>` : '',
            `<ما_تم_فهمه_سابقا>\n${JSON.stringify(compactBrief(input.currentBrief))}\n</ما_تم_فهمه_سابقا>`,
            `<قراءة_القواعد>\n${JSON.stringify(input.ruleBrief)}\n</قراءة_القواعد>`,
            `<رسالة_العميلة>\n${input.message}\n</رسالة_العميلة>`,
            'أعيدي كائن JSON واحدًا فقط، بلا أي نص قبله أو بعده.',
          ]
            .filter(Boolean)
            .join('\n\n'),
        },
      ],
    });

    if (!payload) return null;
    return parseJsonObject(payload);
  }

  async composeReply(input: ReplyCompositionInput): Promise<string | null> {
    if (!this.enabled || !this.config.composeReplies) return null;
    // Nothing to phrase. The templates already say "لم أجد" better than a
    // model asked to be sorry about it.
    if (!input.products.length) return null;

    const catalogue = input.products
      .map(
        (product, index) =>
          `${index + 1}. ${product.title} — ${product.priceLabel} — البائعة: ${product.sellerName}` +
          ` — ${product.inStock ? 'متوفر' : 'غير متوفر حاليًا'} — سبب الاختيار: ${product.reason}`,
      )
      .join('\n');

    const payload = await this.send({
      system: COMPOSITION_SYSTEM_PROMPT,
      maxTokens: Math.min(this.config.maxOutputTokens, 400),
      messages: [
        {
          role: 'user',
          content: [
            `<رسالة_العميلة>\n${input.message}\n</رسالة_العميلة>`,
            input.outfitTitle ? `<اسم_الاطلالة>${input.outfitTitle}</اسم_الاطلالة>` : '',
            `<المنتجات_المتاحة>\n${catalogue}\n</المنتجات_المتاحة>`,
            input.relaxations.length
              ? `<تنازلات>\n${input.relaxations.join('\n')}\n</تنازلات>`
              : '',
            input.followUp ? `<سؤال_المتابعة>${input.followUp}</سؤال_المتابعة>` : '',
          ]
            .filter(Boolean)
            .join('\n\n'),
        },
      ],
    });

    const text = payload?.trim();
    if (!text) return null;
    // A reply that outgrew a chat bubble is a reply the model started
    // improvising in. Take the templates instead.
    return text.length > 900 ? null : text;
  }

  /**
   * One request, with its own deadline. Returns the concatenated text blocks,
   * or null — the caller cannot tell a timeout from a 500 and does not need
   * to, because it does the same thing either way.
   */
  private async send(request: {
    system: string;
    maxTokens: number;
    messages: Array<{ role: 'user' | 'assistant'; content: string }>;
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
            max_tokens: request.maxTokens,
            temperature: 0.2,
            system: request.system,
            messages: request.messages,
          }),
        },
      );

      if (!response.ok) {
        this.logger.warn(
          `Stylist model returned ${response.status}; using the deterministic path.`,
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
      this.logger.warn(`Stylist model unavailable (${reason}); using the deterministic path.`);
      return null;
    } finally {
      clearTimeout(timer);
    }
  }
}

/**
 * Pulls the first balanced `{...}` out of a reply.
 *
 * Models fence JSON, preface it, or apologise before it, and none of that is
 * worth a failed turn — but a brace-counting scan is also the only honest way
 * to do this without a parser: a greedy `/\{.*\}/s` swallows trailing prose
 * and a lazy one truncates nested objects.
 */
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

/** Only the fields worth spending prompt tokens on. */
function compactBrief(brief: BriefExtractionInput['currentBrief']) {
  return {
    occasion: brief.occasion,
    slots: brief.slots,
    budget_min: brief.budgetMin,
    budget_max: brief.budgetMax,
    colours: brief.colours,
    sizes: brief.sizes,
    modesty: brief.modesty,
    personas: brief.personas,
    for_self: brief.forSelf,
  };
}

const EXTRACTION_SYSTEM_PROMPT = [
  'أنتِ محلّلة لغوية داخل تطبيق تسوّق نسائي اسمه «أوهارا». مهمتك الوحيدة هي تحويل',
  'رسالة العميلة إلى كائن JSON منظّم. أنتِ لا تقترحين منتجات، ولا تذكرين أسماء',
  'منتجات أو أسعارًا أو بائعات — هذه ليست وظيفتك ولا تملكين بياناتها.',
  '',
  'أعيدي JSON بهذا الشكل بالضبط، واتركي أي حقل غير مذكور في الرسالة فارغًا (null أو []):',
  '{',
  '  "intent": "FIND_PRODUCT | BUILD_OUTFIT | FIND_GIFT | REFINE | ADVICE | SMALL_TALK",',
  `  "occasion": ${JSON.stringify(OCCASION_KEYS)} أو null,`,
  `  "slots": مصفوفة من ${JSON.stringify(Object.values(OutfitSlot))},`,
  '  "budget_min": رقم بالليرة السورية أو null,',
  '  "budget_max": رقم بالليرة السورية أو null,',
  `  "colours": مصفوفة من ${JSON.stringify(COLOUR_KEYS)},`,
  '  "avoid_colours": نفس القائمة، لما تستبعد لونًا,',
  '  "sizes": { "clothing": "S|M|L|XL", "shoes": "36..44" },',
  `  "modesty": ${JSON.stringify(Object.values(ModestyLevel))},`,
  `  "personas": مصفوفة من ${JSON.stringify(Object.values(StylePersona))},`,
  '  "materials": مصفوفة بأسماء الخامات بالعربية,',
  '  "recipient_age": رقم أو null,',
  '  "for_self": true إذا كانت تتسوّق لنفسها,',
  '  "deadline_days": عدد الأيام حتى تحتاج القطعة أو null,',
  '  "keywords": كلمات مفتاحية قصيرة من الرسالة,',
  '  "confidence": رقم بين 0 و 1',
  '}',
  '',
  'قواعد صارمة:',
  '- استخدمي القيم المذكورة أعلاه حرفيًا. أي قيمة خارجها ستُحذف.',
  '- «٥٠٠ ألف» تعني 500000. «مليون» تعني 1000000.',
  '- لا تخمّني الميزانية أو المقاس إذا لم تُذكرا.',
  '- إذا كانت الرسالة تعديلًا على طلب سابق فالنيّة "REFINE".',
  '- أعيدي JSON فقط، بلا شرح.',
].join('\n');

const COMPOSITION_SYSTEM_PROMPT = [
  'أنتِ «أوهارا»، مساعدة تسوّق شخصية ودودة ومختصرة، تكتبين بعربية فصحى سهلة ودافئة وتخاطبين المستخدمة بصيغة المؤنث دائماً («أهلاً بكِ»، «اختاري»).',
  '',
  'ستصلك قائمة المنتجات التي اختارها النظام من قاعدة البيانات. هذه القائمة هي كل',
  'ما هو موجود. اكتبي جملتين إلى أربع جمل تقدّمين فيها الاختيار وتشرحين المنطق.',
  '',
  'ممنوع منعًا باتًا:',
  '- ذكر أي منتج غير موجود في القائمة.',
  '- ذكر أي سعر أو مقاس أو توفّر غير مذكور في القائمة.',
  '- اختراع خصومات أو مواعيد توصيل أو أسماء بائعات.',
  '- إعادة كتابة القائمة كاملة؛ البطاقات ستُعرض تحت كلامك.',
  '',
  'إذا وُجدت «تنازلات» فاذكريها بصدق وبلطف. إذا وُجد «سؤال_المتابعة» فاختمي به.',
  'لا تستخدمي عناوين ولا نقاطًا؛ اكتبي فقرة واحدة قصيرة.',
].join('\n');
