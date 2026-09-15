/**
 * Realtime topic names. The same strings appear in the `realtime.messages`
 * policies (supabase/migrations/*_reem_supabase_realtime.sql) and in the
 * Flutter client (lib/core/backend/supabase/…); change all three together.
 */
export const userTopic = (userId: string) => `reem:user:${userId}`;
export const chatTopic = (chatId: string) => `reem:chat:${chatId}`;
