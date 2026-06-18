import { Controller, Get } from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { ExperienceService } from './experience.service';

@Controller('experience')
export class ExperienceController {
  constructor(private readonly experience: ExperienceService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.experience.getForUser(user);
  }
}
