import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../../middleware/error-handler.js';
import { validateBody } from '../../middleware/validate.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { AuthService } from './auth.service.js';

const registerSchema = z.object({
  name: z.string().min(2).max(100),
  email: z.string().email(),
  password: z.string().min(6).max(128),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({
  refresh_token: z.string().min(1),
});

const forgotSchema = z.object({
  email: z.string().email(),
});

export const authRouter = Router();

authRouter.post(
  '/register',
  validateBody(registerSchema),
  asyncHandler(async (req, res) => {
    const { name, email, password } = req.body;
    const result = await AuthService.register(name, email, password);
    res.status(201).json(result);
  }),
);

authRouter.post(
  '/login',
  validateBody(loginSchema),
  asyncHandler(async (req, res) => {
    const { email, password } = req.body;
    const result = await AuthService.login(email, password);
    res.json(result);
  }),
);

authRouter.post(
  '/refresh-token',
  validateBody(refreshSchema),
  asyncHandler(async (req, res) => {
    const result = await AuthService.refresh(req.body.refresh_token);
    res.json(result);
  }),
);

authRouter.get(
  '/me',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const result = await AuthService.me(req.user!.id);
    res.json(result);
  }),
);

authRouter.post(
  '/forgot-password',
  validateBody(forgotSchema),
  asyncHandler(async (req, res) => {
    const result = await AuthService.forgotPassword(req.body.email);
    res.json(result);
  }),
);
