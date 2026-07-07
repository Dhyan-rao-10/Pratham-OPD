/** @type {import('next').NextConfig} */
const apiTarget = process.env.API_INTERNAL_URL || 'http://gateway:80';

const nextConfig = {
  output: 'standalone',
  async rewrites() {
    return [
      { source: '/api/:path*', destination: `${apiTarget}/api/:path*` },
      { source: '/his/:path*', destination: `${apiTarget}/his/:path*` },
    ];
  },
};

module.exports = nextConfig;
