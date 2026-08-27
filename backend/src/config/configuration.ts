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
});
