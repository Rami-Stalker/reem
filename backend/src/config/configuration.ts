export default () => ({
  nodeEnv: process.env.NODE_ENV ?? 'development',
  host: process.env.HOST ?? '0.0.0.0',
  port: parseInt(process.env.PORT ?? '3000', 10),
  apiPrefix: process.env.API_PREFIX ?? '',
  /**
   * Behind a reverse proxy every request arrives from the proxy's address, so
   * IP-scoped rate limiting collapses into one shared bucket for the whole
   * platform. Enabling this makes Express read `X-Forwarded-For` — which is
   * only safe when a proxy really is in front, hence the explicit switch.
   */
  trustProxy: process.env.TRUST_PROXY ?? 'false',
  cors: {
    origins: process.env.CORS_ORIGINS ?? '*',
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET as string,
    refreshSecret: process.env.JWT_REFRESH_SECRET as string,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '7d',
  },
  /**
   * Auth keyring. Each secret protects one thing, because a shared secret
   * makes rotation impossible in practice: the guest-token pepper used to be
   * `JWT_REFRESH_SECRET`, so rotating the JWT key after a compromise would
   * also have orphaned every guest cart on the platform — which is exactly the
   * moment you least want a second outage.
   */
  security: {
    otpPepper: process.env.OTP_PEPPER as string,
    guestTokenPepper: process.env.GUEST_TOKEN_PEPPER as string,
    /**
     * Echoes the one-time code into the server log (never into a response) so
     * local development works before a delivery provider is contracted.
     * Explicit opt-in, absent from `.env.example`, and refused at boot in
     * production — it is not tied to NODE_ENV, because NODE_ENV being unset is
     * precisely how the old fail-open behaviour reached a running server.
     */
    otpDevEcho: process.env.OTP_DEV_ECHO === 'true',
    /**
     * Seals the plaintext code in the outbox so escalation can resend the SAME
     * code on the next transport. Separate from the verification pepper: one
     * is one-way and one is reversible, and they must never be the same key.
     */
    otpDeliveryKey: process.env.OTP_DELIVERY_KEY as string,
    /**
     * Encrypts TOTP shared secrets. A shared secret must be recoverable to be
     * verified, so it is encrypted rather than hashed — and under its own key,
     * so a database dump alone does not yield working authenticators.
     */
    totpEncKey: process.env.TOTP_ENC_KEY as string,
    /**
     * Deadline for the retired `?token=` on the chat socket.
     *
     * An absolute instant rather than a boolean, because the boolean version
     * of this is the one nobody ever turns back off. The credential is the
     * whole access token and a query string is the one part of a request every
     * proxy on the way writes into its access log, so the fallback exists for
     * exactly as long as it takes to roll a client forward — and then stops
     * on its own, without needing anyone to remember.
     *
     * Empty means the fallback is off, which is the default and the state to
     * end in. Read on every handshake, so it expires without a restart.
     */
    wsQueryTokenUntil: process.env.WS_QUERY_TOKEN_UNTIL ?? '',
  },
  /**
   * OTP delivery. Every provider field is configuration rather than a
   * constant because the contracted provider is a commercial decision that can
   * change under sanctions pressure — and because the aggregator that ends up
   * carrying Syrian SMS shapes its HTTP API however it likes.
   */
  /**
   * Push notifications.
   *
   * Unset by default, and that is not an oversight: with no provider the
   * delivery worker records a push as skipped rather than pretending it was
   * sent. Contracting one is three environment variables.
   */
  push: {
    endpoint: process.env.PUSH_ENDPOINT,
    authHeader: process.env.PUSH_AUTH_HEADER,
    bodyTemplate: process.env.PUSH_BODY_TEMPLATE,
  },

  otpDelivery: {
    whatsapp: {
      phoneNumberId: process.env.WHATSAPP_PHONE_NUMBER_ID,
      accessToken: process.env.WHATSAPP_ACCESS_TOKEN,
      appSecret: process.env.WHATSAPP_APP_SECRET,
      verifyToken: process.env.WHATSAPP_VERIFY_TOKEN,
      template: process.env.WHATSAPP_TEMPLATE_NAME,
      locale: process.env.WHATSAPP_TEMPLATE_LOCALE,
      apiVersion: process.env.WHATSAPP_API_VERSION,
      costMicros: parseInt(process.env.WHATSAPP_COST_MICROS ?? '5000', 10),
    },
    sms: {
      endpoint: process.env.SMS_GATEWAY_URL,
      apiKey: process.env.SMS_GATEWAY_KEY,
      sender: process.env.SMS_SENDER_ID,
      bodyTemplate: process.env.SMS_BODY_TEMPLATE,
      costMicros: parseInt(process.env.SMS_COST_MICROS ?? '30000', 10),
    },
    voice: {
      endpoint: process.env.VOICE_OTP_URL,
      apiKey: process.env.VOICE_OTP_KEY,
      costMicros: parseInt(process.env.VOICE_COST_MICROS ?? '120000', 10),
    },
    /** Closed-beta stopgap; refused in production by env validation. */
    opsConsoleEnabled: process.env.AUTH_OPS_TRANSPORT_ENABLED === 'true',
    /**
     * Serves outstanding one-time codes at `/auth/dev/inbox` with no session.
     *
     * The stand-in for the SMS aggregator until one is contracted. Sign-in is
     * a code now, so without a readable delivery surface nobody — including
     * the first admin — can get in at all. Explicit opt-in, refused at boot in
     * production, and the controller refuses again on its own.
     */
    devInboxEnabled: process.env.OTP_DEV_INBOX_ENABLED === 'true',
  },
  /**
   * Uploads. The platform stores bytes on the API host's disk for the closed
   * beta — see `MediaStorageDriver` for why, and for the seam that lets a
   * bucket replace it later without touching a call site.
   */
  media: {
    driver: process.env.MEDIA_DRIVER ?? 'local',
    /** Resolved against the process working directory when relative. */
    localRoot: process.env.MEDIA_LOCAL_ROOT ?? 'storage/media',
    /** Path public assets are served under. Mounted in `main.ts`. */
    publicBaseUrl: process.env.MEDIA_PUBLIC_BASE_URL ?? '/media/files',
    /**
     * Origin prefixed onto public media URLs. Left unset it falls back to the
     * origin the request itself arrived on, which is the only value that works
     * unattended across the three addresses this API is reached at in
     * development — `localhost`, `10.0.2.2` from the Android emulator, and the
     * machine's LAN IP from a physical phone. Set it explicitly in production,
     * where the client-visible origin is the proxy's and not the app's.
     */
    publicOrigin: process.env.MEDIA_PUBLIC_ORIGIN ?? '',
    /**
     * A phone camera photograph is 3–6 MB; 12 leaves room for a burst shot
     * without letting a single request pin a worker allocating a buffer.
     */
    maxImageBytes: parseInt(process.env.MEDIA_MAX_IMAGE_BYTES ?? '12582912', 10),
    maxVideoBytes: parseInt(process.env.MEDIA_MAX_VIDEO_BYTES ?? '67108864', 10),
    /**
     * A scanned commercial register is a megabyte or two; 16 covers a
     * multi-page scan without letting the document slot become a file drop.
     */
    maxDocumentBytes: parseInt(
      process.env.MEDIA_MAX_DOCUMENT_BYTES ?? '16777216',
      10,
    ),
    /**
     * A voice note. Two minutes of AAC is well under a megabyte; 24 leaves
     * room for a long one and for the mp3 somebody forwards from elsewhere,
     * without turning the chat into a file drop.
     */
    maxAudioBytes: parseInt(process.env.MEDIA_MAX_AUDIO_BYTES ?? '25165824', 10),
    /**
     * How long an upload may sit unreferenced before the sweeper deletes it.
     * Long enough to survive a woman filling in a product form slowly, losing
     * signal and coming back; short enough that abandoned drafts do not
     * accumulate into the disk filling up.
     */
    orphanTtlHours: parseInt(process.env.MEDIA_ORPHAN_TTL_HOURS ?? '24', 10),
    /**
     * Per-account ceiling in a rolling day. The IP throttle already covers
     * bursts; this covers the patient case — one authenticated account
     * uploading steadily for hours until the disk is gone.
     */
    dailyUploadsPerUser: parseInt(process.env.MEDIA_DAILY_UPLOADS_PER_USER ?? '300', 10),
  },
  rateLimit: {
    ttl: parseInt(process.env.RATE_LIMIT_TTL ?? '60', 10),
    limit: parseInt(process.env.RATE_LIMIT_MAX ?? '120', 10),
  },
  /**
   * Q50/Q47 P1 — «تلقائياً من مصدر منحدده» / «موقع الليرة اليوم».
   *
   * Off by default. A rate feed reprices the entire catalogue, so it is not
   * something that should start working because a container happened to have
   * network access; someone has to turn it on and say where it reads from.
   */
  fx: {
    syncEnabled: process.env.FX_SYNC_ENABLED === 'true',
    /**
     * JSON endpoint returning the current SYP-per-USD rate.
     *
     * Defaults to `@fawazahmed0/currency-api` on jsDelivr, which is free, needs
     * no key, updates daily and — the reason it was chosen — quotes the
     * **parallel-market** rate (~13,000 SYP/USD), which is what this platform
     * actually prices against.
     *
     * That distinction is the whole difficulty. The obvious feeds
     * (open.er-api.com, exchangerate-api.com) return Syria's *official* rate
     * of ~2,000, and publishing one would have repriced the entire USD-listed
     * catalogue by more than six times. الليرة اليوم has no machine-readable
     * API any more — its old `app_api/*.json` endpoints now serve HTML and the
     * page renders its rates client-side, so neither can be fetched.
     */
    sourceUrl:
      process.env.FX_SOURCE_URL ??
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
    /**
     * Dotted path to the rate inside the response. The feed's shape is the
     * vendor's business and changes without notice, so it is configuration
     * rather than a parser baked into the build.
     */
    sourcePath: process.env.FX_SOURCE_PATH ?? 'usd.syp',
    sourceName: process.env.FX_SOURCE_NAME ?? 'fawazahmed0-currency-api',
    /**
     * The largest move, in basis points, that will be published without a
     * human. A scrape returning a mangled number is far likelier than a 25%
     * overnight devaluation, and publishing one reprices everything on the
     * platform — so past this the rate is logged and dropped, not applied.
     */
    maxMoveBps: parseInt(process.env.FX_MAX_MOVE_BPS ?? '2500', 10),
    /** Sanity bounds on SYP per USD; a value outside these is not a rate. */
    minRate: process.env.FX_MIN_RATE ?? '500',
    maxRate: process.env.FX_MAX_RATE ?? '100000',
  },
  /**
   * Reem AI Stylist.
   *
   * Off by default, and the feature works with it off — the stylist's
   * understanding has a complete rules implementation and its retrieval is
   * ordinary SQL either way. Configuring a provider buys better reading of an
   * unusual sentence and warmer phrasing; it never buys a product, a price or
   * a stock level, because the model is not on that path at all.
   *
   * So a missing key is not a degraded mode to apologise for. It is the
   * deterministic mode, and it is the one the tests run in.
   */
  stylist: {
    /** `none` (default) or `anthropic`. */
    provider: process.env.AI_STYLIST_PROVIDER ?? 'none',
    apiKey: process.env.AI_STYLIST_API_KEY ?? '',
    baseUrl: process.env.AI_STYLIST_BASE_URL ?? 'https://api.anthropic.com',
    model: process.env.AI_STYLIST_MODEL ?? 'claude-sonnet-5',
    /**
     * A turn that has not answered in this long is abandoned and the rules
     * path answers instead. She is waiting on a chat bubble, so the ceiling is
     * what a person will sit through, not what the provider's p99 is.
     */
    timeoutMs: parseInt(process.env.AI_STYLIST_TIMEOUT_MS ?? '8000', 10),
    maxOutputTokens: parseInt(process.env.AI_STYLIST_MAX_TOKENS ?? '1024', 10),
    /**
     * Let the model phrase the reply sentence. Extraction and phrasing are
     * separate switches because they carry different risk: a misread brief
     * shows the wrong goods, whereas phrasing only ever rewrites a sentence
     * around goods that were already chosen from the database.
     */
    composeReplies: process.env.AI_STYLIST_COMPOSE_REPLIES !== 'false',
  },

  /**
   * Reem Visual Shopping.
   *
   * The feature is complete with none of this set. The default embedder is a
   * deterministic perceptual descriptor computed in process, the default index
   * is exact cosine over the rows the platform already has, and the default
   * vision provider is off — so a missing key is not a degraded mode, it is
   * the mode the tests run in.
   *
   * Two switches are worth reading before deploying:
   *
   *  - `VISUAL_SEARCH_INDEXER_ENABLED` gates the hourly pass that describes
   *    product photographs. Off by default for the same reason the trend
   *    scheduler is: a laptop running `nest start --watch` should not start
   *    decoding the whole catalogue because it happened to be awake. Nothing
   *    can be found by image until it has run somewhere.
   *  - `VISUAL_SEARCH_IMAGE_RETENTION_HOURS` is the promise on the upload
   *    screen. Lowering it is safe; raising it changes what the client tells
   *    her, because the number is served from here.
   */
  visualSearch: {
    /**
     * 8 MB. Below the media module's 12 because this is a *query* image, not a
     * listing photograph: it is resampled to 1024px and thrown away within the
     * day, so the extra megabytes buy nothing but upload time on a Syrian
     * mobile connection.
     */
    maxImageBytes: parseInt(process.env.VISUAL_SEARCH_MAX_IMAGE_BYTES ?? '8388608', 10),
    /**
     * The decompression-bomb ceiling, applied at decode. A 40 KB PNG can
     * expand to a gigabyte, and the encoded-size limit above says nothing
     * about that.
     */
    maxImagePixels: parseInt(process.env.VISUAL_SEARCH_MAX_IMAGE_PIXELS ?? '40000000', 10),
    /** The longest edge of the copy actually stored, and what the client is told to resample to. */
    storedWidth: parseInt(process.env.VISUAL_SEARCH_STORED_WIDTH ?? '1024', 10),

    indexerEnabled: process.env.VISUAL_SEARCH_INDEXER_ENABLED === 'true',
    /** Products described per hourly pass. A first run spreads over nights. */
    indexerBatch: parseInt(process.env.VISUAL_SEARCH_INDEXER_BATCH ?? '120', 10),
    /**
     * Photographs described per listing. After the first two or three a
     * listing's images are detail shots of a sleeve, and a detail shot matches
     * every other detail shot in the shop — indexing them all costs time and
     * loses precision.
     */
    imagesPerProduct: parseInt(process.env.VISUAL_SEARCH_IMAGES_PER_PRODUCT ?? '3', 10),
    /**
     * Whether the indexer may fetch a product photograph from an address it
     * did not store itself. Needed in development, where the demo catalogue is
     * entirely external links. The outbound path is fenced against SSRF in
     * `CatalogImageService` — read that before turning it off in production,
     * because in production every image is ours and this can be `false`.
     */
    indexRemoteImages: process.env.VISUAL_SEARCH_INDEX_REMOTE !== 'false',
    // Fifteen seconds, not six: a catalogue image that lives on someone
    // else's host often redirects before it answers, and a timeout here is
    // not a slow page — it is a product that silently never becomes
    // searchable by picture.
    fetchTimeoutMs: parseInt(process.env.VISUAL_SEARCH_FETCH_TIMEOUT_MS ?? '15000', 10),

    /** Vectors scored exactly per region. See the note in the Postgres index. */
    candidateLimit: parseInt(process.env.VISUAL_SEARCH_CANDIDATES ?? '4000', 10),
    resultsPerRegion: parseInt(process.env.VISUAL_SEARCH_RESULTS ?? '12', 10),

    /**
     * How long her uploaded photograph is kept. The search itself — the
     * descriptor, the attributes, the matches — outlives it, which is what
     * lets her reopen and refine a search without uploading again.
     */
    imageRetentionHours: parseInt(
      process.env.VISUAL_SEARCH_IMAGE_RETENTION_HOURS ?? '24',
      10,
    ),
    /**
     * The shortest clock in the platform, for the most sensitive image in it.
     * A photograph of her body has no reason to outlive the render it was
     * uploaded for.
     */
    tryOnRetentionHours: parseInt(process.env.VISUAL_TRY_ON_RETENTION_HOURS ?? '2', 10),

    /** `none` (default) or `anthropic`. Proposes attributes; never ranks. */
    visionProvider: process.env.VISUAL_VISION_PROVIDER ?? 'none',
    visionApiKey: process.env.VISUAL_VISION_API_KEY ?? '',
    visionBaseUrl: process.env.VISUAL_VISION_BASE_URL ?? 'https://api.anthropic.com',
    visionModel: process.env.VISUAL_VISION_MODEL ?? 'claude-sonnet-5',
    /** She is waiting on an upload spinner, so the ceiling is what a person sits through. */
    visionTimeoutMs: parseInt(process.env.VISUAL_VISION_TIMEOUT_MS ?? '9000', 10),
    visionMaxTokens: parseInt(process.env.VISUAL_VISION_MAX_TOKENS ?? '900', 10),
    /** Ask the model for garment boxes as well as a brief. */
    visionDetectItems: process.env.VISUAL_VISION_DETECT_ITEMS !== 'false',
  },

  /**
   * Reem Trend Engine.
   *
   * The scheduler is **off by default**, and that is not caution for its own
   * sake: the nightly run reads the whole order history and rewrites ten
   * tables, which is not something a `nest start --watch` on somebody's laptop
   * should begin doing at 2am because the machine happened to be awake. Turn
   * it on where the data is real.
   *
   * The model, like the stylist's, is off by default too. With no provider the
   * insights are phrased by Arabic templates that are a complete
   * implementation rather than a placeholder — so a missing key is the
   * deterministic mode, and it is the one the tests run in.
   */
  trends: {
    schedulerEnabled: process.env.TRENDS_SCHEDULER_ENABLED === 'true',
    /**
     * How many days each nightly run re-reads.
     *
     * Facts settle late: an order placed on Monday is cancelled on Wednesday
     * and returned on Friday, and Monday's row should end up telling the truth
     * about Monday. Three days catches nearly all of it and costs three cheap
     * passes instead of one.
     */
    lookbackDays: parseInt(process.env.TRENDS_LOOKBACK_DAYS ?? '3', 10),
    /**
     * How long a cart may sit untouched before it counts as abandoned. Six
     * hours: long enough that "she is still shopping" is not called a loss,
     * short enough that the signal lands on the day it happened.
     */
    cartAbandonHours: parseInt(process.env.TRENDS_CART_ABANDON_HOURS ?? '6', 10),
    llm: {
      /** `none` (default) or `anthropic`. */
      provider: process.env.TREND_LLM_PROVIDER ?? 'none',
      apiKey: process.env.TREND_LLM_API_KEY ?? '',
      baseUrl: process.env.TREND_LLM_BASE_URL ?? 'https://api.anthropic.com',
      model: process.env.TREND_LLM_MODEL ?? 'claude-sonnet-5',
      /**
       * Generous compared with the stylist's eight seconds, because nobody is
       * waiting: this runs inside the nightly job, and the only cost of a slow
       * reply is a slightly longer run.
       */
      timeoutMs: parseInt(process.env.TREND_LLM_TIMEOUT_MS ?? '20000', 10),
      maxOutputTokens: parseInt(process.env.TREND_LLM_MAX_TOKENS ?? '4096', 10),
      /**
       * Findings per request. Batched so one night's feed has one voice, and
       * capped so a single failure costs eight sentences rather than forty.
       */
      batchSize: parseInt(process.env.TREND_LLM_BATCH_SIZE ?? '8', 10),
    },
  },

  /**
   * Reem Market Evolution.
   *
   * Its nightly sweep reads every live category and product against the
   * platform's own medians, so it carries the same default as the trend engine
   * for the same reason: not something a watch-mode process on a laptop should
   * start doing at 3am. Falls back to `TRENDS_SCHEDULER_ENABLED` when unset,
   * because in every real deployment the two are turned on together — the
   * market reading is computed *from* the trend engine's daily facts, and
   * running one without the other produces a market read against nothing.
   */
  market: {
    schedulerEnabled:
      process.env.MARKET_SCHEDULER_ENABLED === 'true'
        ? true
        : process.env.MARKET_SCHEDULER_ENABLED === 'false'
          ? false
          : undefined,
  },
  payments: {
    /**
     * Lets `POST /payments/:id/verify` settle a rail whose provider cannot
     * actually attest that money moved.
     *
     * Every provider is a stub until a merchant account exists, so in
     * development this is the only way to walk a checkout through to a
     * confirmed order. In production it is fraud: the endpoint is reachable by
     * the customer who owns the payment, so leaving it on lets anyone mark
     * their own order paid, credit the ledger and start the sellers shipping.
     *
     * Explicit opt-in, absent from `.env.example`, refused at boot in
     * production — the same shape as `OTP_DEV_ECHO`, and for the same reason:
     * NODE_ENV being unset is exactly how a fail-open default reaches a
     * running server.
     */
    sandboxConfirmation: process.env.PAYMENTS_SANDBOX_CONFIRMATION === 'true',
  },
});
