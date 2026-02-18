/**
 * Affiliate Keyword Generator
 * Maps supplement names to optimal Amazon search terms.
 * Uses a rules-based approach (no AI call needed) for speed and reliability.
 * Falls back to the raw supplement name if no mapping exists.
 */

export interface SupplementKeyword {
  keyword: string;          // Amazon search term
  reason: string;           // Why this form is best
  timing: string;           // When to take: "morning_empty_stomach" | "morning_with_food" | "afternoon" | "evening_with_food" | "evening_before_bed"
  timing_note: string;      // Human-readable timing instruction
  search_category: string;  // Amazon category
}

// Map of common supplement names to their best bioavailable forms
const SUPPLEMENT_KEYWORDS: Record<string, SupplementKeyword> = {
  "vitamin d3": {
    keyword: "Vitamin D3 5000 IU K2 MK7",
    reason: "D3 with K2 ensures proper calcium routing; 5000 IU corrects deficiency",
    timing: "morning_with_food",
    timing_note: "Take with breakfast (needs dietary fat for absorption)",
    search_category: "Health & Household",
  },
  "vitamin d": {
    keyword: "Vitamin D3 5000 IU K2 MK7",
    reason: "D3 is the most bioavailable form; K2 prevents arterial calcification",
    timing: "morning_with_food",
    timing_note: "Take with breakfast (needs dietary fat for absorption)",
    search_category: "Health & Household",
  },
  "iron": {
    keyword: "Iron Bisglycinate 25mg Gentle",
    reason: "Bisglycinate is the gentlest form — no stomach upset, highest absorption",
    timing: "morning_empty_stomach",
    timing_note: "Take on empty stomach with vitamin C (orange juice) for 2x absorption",
    search_category: "Health & Household",
  },
  "iron bisglycinate": {
    keyword: "Iron Bisglycinate 25mg Gentle",
    reason: "Chelated iron with minimal GI side effects",
    timing: "morning_empty_stomach",
    timing_note: "Take on empty stomach with vitamin C for best absorption",
    search_category: "Health & Household",
  },
  "magnesium": {
    keyword: "Magnesium Glycinate 400mg",
    reason: "Glycinate is the best form for sleep, anxiety, and muscle recovery",
    timing: "evening_before_bed",
    timing_note: "Take 1 hour before bed for better sleep quality",
    search_category: "Health & Household",
  },
  "magnesium glycinate": {
    keyword: "Magnesium Glycinate 400mg",
    reason: "Best absorbed form, calming effect promotes sleep",
    timing: "evening_before_bed",
    timing_note: "Take 1 hour before bed for better sleep quality",
    search_category: "Health & Household",
  },
  "vitamin b12": {
    keyword: "Methylcobalamin B12 1000mcg Sublingual",
    reason: "Methylcobalamin is the active form — sublingual bypasses gut absorption issues",
    timing: "morning_empty_stomach",
    timing_note: "Dissolve under tongue in the morning for best absorption",
    search_category: "Health & Household",
  },
  "b12": {
    keyword: "Methylcobalamin B12 1000mcg Sublingual",
    reason: "Active methylated form, sublingual delivery",
    timing: "morning_empty_stomach",
    timing_note: "Dissolve under tongue in the morning",
    search_category: "Health & Household",
  },
  "b-complex": {
    keyword: "B Complex Methylated Active",
    reason: "Methylated B vitamins for those with MTHFR variants",
    timing: "morning_empty_stomach",
    timing_note: "Take in the morning — B vitamins can disrupt sleep if taken late",
    search_category: "Health & Household",
  },
  "omega-3": {
    keyword: "Omega 3 Fish Oil EPA DHA Triglyceride Form",
    reason: "Triglyceride form absorbs 70% better than ethyl ester; high EPA for inflammation",
    timing: "morning_with_food",
    timing_note: "Take with a meal containing fat",
    search_category: "Health & Household",
  },
  "omega 3": {
    keyword: "Omega 3 Fish Oil EPA DHA Triglyceride Form",
    reason: "Triglyceride form for superior absorption",
    timing: "morning_with_food",
    timing_note: "Take with a meal containing fat",
    search_category: "Health & Household",
  },
  "fish oil": {
    keyword: "Omega 3 Fish Oil EPA DHA Triglyceride Form",
    reason: "High EPA:DHA ratio for cardiovascular and anti-inflammatory benefits",
    timing: "morning_with_food",
    timing_note: "Take with a meal containing fat",
    search_category: "Health & Household",
  },
  "zinc": {
    keyword: "Zinc Picolinate 30mg",
    reason: "Picolinate is the most bioavailable zinc form",
    timing: "evening_with_food",
    timing_note: "Take with dinner — avoid taking with iron (they compete)",
    search_category: "Health & Household",
  },
  "folate": {
    keyword: "Methylfolate 5-MTHF 1000mcg",
    reason: "Active methylated form — 40% of people cannot convert folic acid",
    timing: "morning_empty_stomach",
    timing_note: "Take in the morning with B12 for synergy",
    search_category: "Health & Household",
  },
  "coq10": {
    keyword: "CoQ10 Ubiquinol 200mg",
    reason: "Ubiquinol is the active reduced form — 8x better absorption than ubiquinone",
    timing: "morning_with_food",
    timing_note: "Take with breakfast (fat-soluble)",
    search_category: "Health & Household",
  },
  "probiotics": {
    keyword: "Probiotics 50 Billion CFU Multi Strain",
    reason: "Multi-strain with high CFU count for gut diversity",
    timing: "morning_empty_stomach",
    timing_note: "Take 30 minutes before breakfast",
    search_category: "Health & Household",
  },
  "curcumin": {
    keyword: "Curcumin Turmeric BioPerine 1000mg",
    reason: "BioPerine (piperine) increases curcumin absorption by 2000%",
    timing: "morning_with_food",
    timing_note: "Take with a meal for best absorption",
    search_category: "Health & Household",
  },
  "selenium": {
    keyword: "Selenium 200mcg Selenomethionine",
    reason: "Selenomethionine is the most bioavailable organic form",
    timing: "morning_with_food",
    timing_note: "Take with breakfast",
    search_category: "Health & Household",
  },
};

/**
 * Get the optimal Amazon search keyword for a supplement name.
 * Falls back to a cleaned-up version of the supplement name.
 */
export function getSupplementKeyword(supplementName: string): SupplementKeyword {
  const normalized = supplementName.toLowerCase().trim();

  // Direct match
  if (SUPPLEMENT_KEYWORDS[normalized]) {
    return SUPPLEMENT_KEYWORDS[normalized];
  }

  // Partial match — check if any key is contained in the name
  for (const [key, value] of Object.entries(SUPPLEMENT_KEYWORDS)) {
    if (normalized.includes(key) || key.includes(normalized)) {
      return value;
    }
  }

  // Fallback: use the supplement name as-is
  return {
    keyword: `${supplementName} Supplement`,
    reason: "Recommended based on your lab results",
    timing: "morning_with_food",
    timing_note: "Take with a meal unless otherwise directed",
    search_category: "Health & Household",
  };
}
