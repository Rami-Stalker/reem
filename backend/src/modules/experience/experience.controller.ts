import { Controller, Get } from '@nestjs/common';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { ExperienceService } from './experience.service';

@SelfScoped(
  "returns the navigation shell for the caller's own role",
)
@Controller('experience')
export class ExperienceController {
  constructor(private readonly experience: ExperienceService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.experience.getForUser(user);
  }
}
