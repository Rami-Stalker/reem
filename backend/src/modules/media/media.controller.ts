import {
  BadRequestException,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ConfigService } from '@nestjs/config';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { serializeMediaAsset } from '../../common/serializers/media.serializer';
import { MediaService } from './media.service';
import {
  acceptedKinds,
  MediaPurpose,
  visibilityForPurpose,
} from './dto/upload-media.dto';

/**
 * The shape `multer` hands back. Declared here rather than pulled in with
 * `@types/multer`: three fields are used and a dependency whose only export is
 * a namespace declaration is not worth carrying for them.
 */
interface UploadedFileLike {
  buffer: Buffer;
  originalname?: string;
  size: number;
}

@Controller('media')
export class MediaController {
  constructor(
    private readonly media: MediaService,
    private readonly config: ConfigService,
  ) {}

  /**
   * One file in, one URL out.
   *
   * Deliberately not part of creating a product or a story. A woman on a
   * Syrian mobile connection uploading four photographs and then losing signal
   * on submit would otherwise lose all four; uploading each as she picks it
   * means the form re-submits in a second and the bytes are already there.
   *
   * The throttle is per IP and sits under the account-level daily quota in
   * `MediaService` — one covers the burst, the other covers the long patient
   * drip that no per-minute limit would ever notice.
   */
  @Post('uploads')
  @HttpCode(HttpStatus.CREATED)
  @Throttle({ default: { limit: 40, ttl: 60_000 } })
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        // The largest of the three ceilings; `MediaService` then applies the
        // one that matches what the bytes turned out to be. Doing it in that
        // order means an image cannot be smuggled past the image limit by
        // claiming to be a video, nor a PDF past the document limit.
        fileSize: Number(process.env.MEDIA_MAX_VIDEO_BYTES ?? 67_108_864),
        files: 1,
      },
    }),
  )
  async upload(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: UploadedFileLike | undefined,
    @Req() req: Request,
  ) {
    if (!file) throw new BadRequestException('FILE_REQUIRED');

    const purpose = (req.body?.purpose as MediaPurpose | undefined) ?? 'product';
    const visibility = visibilityForPurpose(purpose);

    const asset = await this.media.upload(user.id, {
      buffer: file.buffer,
      originalName: file.originalname,
      visibility,
      purpose,
      allowedKinds: acceptedKinds(purpose),
    });

    const origin = originOf(req);
    return serializeMediaAsset(
      asset,
      this.media.urlFor(asset, origin),
      this.media.variantUrlFor(asset, origin, 480),
    );
  }

  /**
   * Bytes for a private asset — today, a seller's verification documents.
   *
   * Public media never comes through here; it is served off disk by the mount
   * in `main.ts`, which is the difference between a static file and a database
   * round trip plus an authorisation decision on every image request.
   */
  @Get(':id/file')
  async file(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Req() req: Request,
    @Res() res: Response,
  ) {
    // `?w=480` asks for a resized copy. An unknown width falls back to the
    // original rather than 404ing: a client guessing at a variant must never
    // be able to break an image that exists.
    const width = Number.parseInt(String(req.query.w ?? ''), 10);
    const { asset, bytes, mimeType } = await this.media.readPrivateVariant(
      id,
      user,
      Number.isFinite(width) ? width : 0,
    );

    res.setHeader('Content-Type', mimeType);
    res.setHeader('Content-Length', String(bytes.length));
    // Never a shared cache: the response depends on who asked.
    res.setHeader('Cache-Control', 'private, max-age=300');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    // `inline` with no filename. A national ID card should render in the
    // review screen, not land in the reviewer's Downloads folder under the
    // seller's own filename.
    res.setHeader('Content-Disposition', 'inline');
    res.end(bytes);
  }
}

/**
 * The origin this request actually arrived on.
 *
 * `req.protocol` and `req.get('host')` already respect `X-Forwarded-*` when —
 * and only when — Express has been told to trust the proxy, which `main.ts`
 * gates behind `TRUST_PROXY`. So this is forgeable exactly in the deployment
 * where the IP throttle is forgeable too, and safe everywhere else.
 */
function originOf(req: Request): string {
  return `${req.protocol}://${req.get('host') ?? ''}`;
}
