import { Module } from '@nestjs/common';
import { DeliveryOrchestrator } from './delivery.orchestrator';
import { OtpCipherService } from './otp-cipher.service';
import { OtpDeliveryReadiness } from './otp-delivery-readiness';
import { OtpDispatcherService } from './otp-dispatcher.service';
import { OtpOutboxCron } from './otp-outbox.cron';
import { OTP_TRANSPORTS, OtpTransport } from './otp-transport';
import { OtpDeliveryAdminController } from './otp-delivery.admin.controller';
import { WhatsAppWebhookController } from './whatsapp-webhook.controller';
import { DevInboxController } from './dev-inbox.controller';
import { OpsConsoleTransport } from './transports/ops-console.transport';
import { SmsGatewayTransport } from './transports/sms-gateway.transport';
import { VoiceTransport } from './transports/voice.transport';
import { WhatsAppCloudTransport } from './transports/whatsapp-cloud.transport';
import { ReverseSmsService } from './syrotp/reverse-sms.service';
import { SyrotpClient } from './syrotp/syrotp.client';

/**
 * The OTP delivery subsystem.
 *
 * Transports are collected into one array under {@link OTP_TRANSPORTS} by a
 * factory, so adding a provider is a class plus one line here plus a row in
 * `otp_transport_routes` — the orchestrator, the outbox and the report all
 * pick it up without changes. (A factory rather than a `multi: true` provider,
 * which is an Angular concept Nest does not have.)
 */
@Module({
  controllers: [
    OtpDeliveryAdminController,
    WhatsAppWebhookController,
    // Temporary: stands in for the SMS aggregator. Refuses to serve in
    // production, and comes out with the contract.
    DevInboxController,
  ],
  providers: [
    OtpCipherService,
    OtpDispatcherService,
    DeliveryOrchestrator,
    // Reverse SMS is not a transport: it carries nothing outbound, so it is
    // not a link in the chain below and does not belong in OTP_TRANSPORTS. It
    // sits beside the chain and is tried first — see `syrotp/`.
    SyrotpClient,
    ReverseSmsService,
    OtpOutboxCron,
    OtpDeliveryReadiness,
    WhatsAppCloudTransport,
    SmsGatewayTransport,
    VoiceTransport,
    OpsConsoleTransport,
    {
      provide: OTP_TRANSPORTS,
      inject: [
        WhatsAppCloudTransport,
        SmsGatewayTransport,
        VoiceTransport,
        OpsConsoleTransport,
      ],
      useFactory: (...transports: OtpTransport[]) => transports,
    },
  ],
  exports: [
    OtpCipherService,
    OtpDispatcherService,
    DeliveryOrchestrator,
    ReverseSmsService,
  ],
})
export class OtpDeliveryModule {}
