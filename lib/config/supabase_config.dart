// Supabase Project Credentials Configuration
// If environment variables SUPABASE_URL and SUPABASE_ANON_KEY are not passed via --dart-define,
// you can configure your Supabase URL & Anon Key below.

class SupabaseConfig {
  // Supabase project URL
  static const String fallbackUrl = 'https://tgexkxrhcyxvnqafbdff.supabase.co';

  // Supabase publishable key (sb_publishable_...). Public by design: it
  // only grants what the database's row-level security allows anyone.
  static const String fallbackAnonKey = 'sb_publishable_Iav9Fvuy4VNJUGRcfV7tLg_E7VcF4Dl';
}
