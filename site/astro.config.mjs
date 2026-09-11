// site/astro.config.mjs
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://vitomy.app',
  output: 'static',
  trailingSlash: 'never',
  build: {
    format: 'file',            // /privacy -> privacy.html, served by Caddy try_files
    inlineStylesheets: 'never', // the CSP has no 'unsafe-inline'
  },
  integrations: [sitemap()],
});
