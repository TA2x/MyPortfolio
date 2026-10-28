// Public values only. The anon key is meant to be public: access is enforced by database policies.
// NEVER put the service_role key or any secret in this file.
window.CFG = {
  SUPABASE_URL: "https://tsfoeepniamvbidromeb.supabase.co",        // e.g. https://abcdxyz.supabase.co
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRzZm9lZXBuaWFtdmJpZHJvbWViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxODI0NTgsImV4cCI6MjEwODc1ODQ1OH0.UuoTP_ZmPC4sgwce-32Rg071y1weBGnJnpHI0oOSCM8",   // Project Settings > API > anon public key
  TURNSTILE_SITE_KEY: ""   // optional: Cloudflare Turnstile site key (public)
};
