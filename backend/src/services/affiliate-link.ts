import { config } from "../config.js";

// Amazon domains by country code
const AMAZON_DOMAINS: Record<string, string> = {
  US: "amazon.com",
  UK: "amazon.co.uk",
  GB: "amazon.co.uk",
  DE: "amazon.de",
  FR: "amazon.fr",
  ES: "amazon.es",
  IT: "amazon.it",
  JP: "amazon.co.jp",
  CA: "amazon.ca",
  AU: "amazon.com.au",
  TR: "amazon.com.tr",
  AE: "amazon.ae",
  SA: "amazon.sa",
  IN: "amazon.in",
  BR: "amazon.com.br",
  MX: "amazon.com.mx",
  NL: "amazon.nl",
  SE: "amazon.se",
  PL: "amazon.pl",
};

// iHerb affiliate base
const IHERB_BASE = "https://www.iherb.com/search";

export interface AffiliateLink {
  amazon_url: string;
  iherb_url: string | null;
  keyword: string;
  store_preference: "amazon" | "iherb";
}

/**
 * Build a dynamic Amazon affiliate search URL.
 * The user clicks this, Amazon shows search results, any purchase = commission.
 */
export function buildAmazonLink(keyword: string, country: string = "US"): string {
  const domain = AMAZON_DOMAINS[country.toUpperCase()] ?? AMAZON_DOMAINS.US;
  const tag = config.amazonAffiliateTag;
  const encoded = encodeURIComponent(keyword);

  if (tag) {
    return `https://www.${domain}/s?k=${encoded}&tag=${tag}`;
  }
  // Without tag, still works but no commission
  return `https://www.${domain}/s?k=${encoded}`;
}

/**
 * Build an iHerb affiliate search URL (better commissions for supplements).
 */
export function buildIherbLink(keyword: string): string | null {
  const code = config.iherbAffiliateCode;
  if (!code) return null;

  const encoded = encodeURIComponent(keyword);
  return `${IHERB_BASE}?kw=${encoded}&rcode=${code}`;
}

/**
 * Build affiliate links for a given keyword and country.
 */
export function buildAffiliateLinks(keyword: string, country: string = "US"): AffiliateLink {
  return {
    amazon_url: buildAmazonLink(keyword, country),
    iherb_url: buildIherbLink(keyword),
    keyword,
    store_preference: config.iherbAffiliateCode ? "iherb" : "amazon",
  };
}
