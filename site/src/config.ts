// The two switches the spec puts in one place. Both are read at build time.

/** Store links. `url: null` renders an inert "Coming soon" button; a URL
 *  renders the OFFICIAL badge from public/badges/ and links to it. Set both
 *  on launch day. */
export const stores = {
  apple: {
    url: 'https://apps.apple.com/us/app/vitomy-supps-vits-tracker/id6811004977' as string | null,
    label: 'App Store',
    badge: '/badges/app-store.svg',
  },
  google: { url: null as string | null, label: 'Google Play', badge: '/badges/google-play.png' },
} as const;

export type StoreId = keyof typeof stores;

/** Which documents in ../docs/legal are published. A listed document that
 *  still contains a [PLACEHOLDER] fails the build (integrations/legal-gate.mjs).
 *  Add 'terms' once [NOMINAL_SUM] is filled. */
export const legalPages: readonly string[] = ['privacy'];

export const supportEmail = 'support@vitomy.app';
