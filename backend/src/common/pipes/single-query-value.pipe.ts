import {
  ArgumentMetadata,
  BadRequestException,
  Injectable,
  PipeTransform,
} from '@nestjs/common';

/**
 * Refuses a repeated key on a single-value query parameter.
 *
 * `@Query('q') q: string` is typed as a string, but `?q=a&q=b` arrives as an
 * array, and the first `.trim()` on it answered 500. DTO-bound queries are
 * already covered by `@IsString()`; this covers the parameters read by name.
 * A parameter declared as an array (`@Query('ids') ids: string[]`) is left
 * alone.
 */
@Injectable()
export class SingleQueryValuePipe implements PipeTransform {
  transform(value: unknown, metadata: ArgumentMetadata): unknown {
    if (
      metadata.type === 'query' &&
      metadata.data &&
      metadata.metatype !== Array &&
      Array.isArray(value)
    ) {
      throw new BadRequestException(
        `Query parameter "${metadata.data}" must be given once`,
      );
    }
    return value;
  }
}
