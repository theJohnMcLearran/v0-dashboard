/** @type {import('next').NextConfig} */
const nextConfig = {
  eslint: {
    ignoreDuringBuilds: true,
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  transpilePackages: ['@supabase/supabase-js', '@supabase/auth-js', '@supabase/realtime-js', '@supabase/postgrest-js', '@supabase/storage-js', '@supabase/functions-js'],
}

export default nextConfig
