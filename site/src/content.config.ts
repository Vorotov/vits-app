import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';

// The two publishable documents, read from the app repository. The research
// notes in the same directory are never a candidate.
export const collections = {
  legal: defineCollection({
    loader: glob({ pattern: ['privacy.md', 'terms.md'], base: '../docs/legal' }),
  }),
};
