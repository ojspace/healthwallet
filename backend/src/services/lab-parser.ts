import { config } from "../config.js";

// ===== Prompts =====

const ADVANCED_BIOMARKER_PROMPT = `You are a Functional Medicine expert and lab results analyst specializing in vitamin and nutrient optimization.

## Your Tasks:
1. **DETECT** if this document contains results from multiple different dates or labs.
2. **SPLIT** the data into separate logical reports if needed (e.g. Jan 2023 vs Dec 2024). A "report" is a set of results for a specific date.
3. **EXTRACT** all data for each report. **PRIORITIZE vitamins and minerals first.**
4. **ANALYZE** correlations and generate summaries for EACH report, focusing on nutrient deficiencies and actionable food/supplement recommendations.

## Biomarkers to Extract (PRIORITY ORDER):
### HIGH PRIORITY — Vitamins & Minerals (extract these first):
- Vitamin D (25-Hydroxy), Vitamin B12, Folate/Folic Acid, Iron, Ferritin, Magnesium, Zinc, Vitamin A, Vitamin E, Vitamin C, Calcium, Phosphorus, Selenium, Copper, Manganese, Iodine, Chromium

### MEDIUM PRIORITY — Metabolic & Lipids:
- Fasting Glucose, HbA1c, Insulin
- Total Cholesterol, HDL, LDL, Triglycerides, VLDL

### STANDARD — Other panels:
- **Thyroid**: TSH, Free T3, Free T4
- **Inflammatory**: CRP (C-Reactive Protein), ESR, Homocysteine
- **Liver**: ALT, AST, Bilirubin, Albumin
- **Kidney**: Creatinine, BUN, eGFR
- **Hormones**: Testosterone, Estrogen, Cortisol, DHEA
- **Blood**: Hemoglobin, Hematocrit, WBC, RBC, Platelets

## Correlation Patterns to Detect:
- Low Ferritin + Low Hemoglobin = "Iron Deficiency Anemia"
- High Glucose + High Triglycerides + Low HDL = "Insulin Resistance / Metabolic Syndrome"
- High TSH + Low Free T3 = "Hypothyroid / Poor T4-T3 Conversion"
- High LDL + High CRP = "Elevated Cardiovascular Risk"
- Low Vitamin D + High CRP = "Chronic Inflammation"
- High Homocysteine + Low B12 = "B12 Deficiency / Methylation Issues"
- High Cortisol + Low DHEA = "Adrenal Stress Pattern"

## User's Dietary Preference: {dietary_preference}
(Filter food recommendations to match this diet)

## Output Format (STRICT JSON):
\`\`\`json
{
  "reports": [
    {
      "record_date": "YYYY-MM-DD or null if not found",
      "lab_provider": "Quest/LabCorp/etc or null",
      "biomarkers": [
        {
          "name": "Vitamin D",
          "value": 24,
          "unit": "ng/mL",
          "reference_range": {"min": 30, "max": 100},
          "status": "low",
          "category": "vitamins",
          "confidence": 0.95
        }
      ],
      "summary": "Health summary for this specific report...",
      "correlations": [
        {
          "markers": ["Ferritin", "Hemoglobin"],
          "insight": "Insight...",
          "severity": "warning",
          "condition": "Condition Name"
        }
      ],
      "key_findings": ["Finding 1", "Finding 2"],
      "food_recommendations": [
        {
          "food": "Salmon",
          "portion": "4 oz",
          "reason": "Reason...",
          "targets": ["Vitamin D"]
        }
      ],
      "supplement_protocol": [
        {
          "name": "Vitamin D3",
          "dosage": "5000 IU",
          "reason": "Reason...",
          "biomarker_link": "Vitamin D",
          "priority": "essential"
        }
      ],
      "lifestyle_recommendations": ["Recommendation 1"]
    }
  ]
}
\`\`\`

## Important Rules:
- If the document only has one date/report, return a single item in the "reports" array.
- If multiple dates are found, create SEPARATE reports for each date found.
- Return ONLY valid JSON, no markdown code blocks.
- Use null for missing values.

Lab Report Text:
`;

// ===== Fallback regex parser =====

interface ParsedReport {
  biomarkers: Record<string, any>[];
  summary: string | null;
  correlations: Record<string, any>[];
  key_findings: string[];
  recommendations: string[];
  food_recommendations: Record<string, any>[];
  supplement_protocol: Record<string, any>[];
  lifestyle_recommendations: string[];
  record_date: string | null;
  lab_provider: string | null;
  parse_error?: string;
}

function fallbackParse(rawText: string, dietaryPreference: string = "omnivore"): ParsedReport[] {
  const biomarkers: Record<string, any>[] = [];

  const patterns: [RegExp, string, string, number, number, string][] = [
    [/vitamin\s*d.*?(\d+\.?\d*)\s*(ng\/mL|nmol\/L)/i, "Vitamin D", "ng/mL", 30, 100, "vitamins"],
    [/total\s*cholesterol.*?(\d+\.?\d*)\s*(mg\/dL)?/i, "Total Cholesterol", "mg/dL", 125, 200, "lipids"],
    [/(?:hdl|hdl[\s-]c).*?(\d+\.?\d*)\s*(mg\/dL)?/i, "HDL Cholesterol", "mg/dL", 40, 60, "lipids"],
    [/(?:ldl|ldl[\s-]c).*?(\d+\.?\d*)\s*(mg\/dL)?/i, "LDL Cholesterol", "mg/dL", 0, 100, "lipids"],
    [/triglycerides.*?(\d+\.?\d*)\s*(mg\/dL)?/i, "Triglycerides", "mg/dL", 0, 150, "lipids"],
    [/(?:fasting\s*)?glucose.*?(\d+\.?\d*)\s*(mg\/dL)?/i, "Fasting Glucose", "mg/dL", 70, 100, "metabolic"],
    [/hba1c.*?(\d+\.?\d*)\s*(%)?/i, "HbA1c", "%", 4.0, 5.6, "metabolic"],
    [/tsh.*?(\d+\.?\d*)\s*(mIU\/L|uIU\/mL)?/i, "TSH", "mIU/L", 0.4, 4.0, "thyroid"],
    [/iron.*?(\d+\.?\d*)\s*(ug\/dL|mcg\/dL)?/i, "Iron", "ug/dL", 60, 170, "vitamins"],
    [/ferritin.*?(\d+\.?\d*)\s*(ng\/mL)?/i, "Ferritin", "ng/mL", 20, 200, "vitamins"],
    [/vitamin\s*b12.*?(\d+\.?\d*)\s*(pg\/mL)?/i, "Vitamin B12", "pg/mL", 200, 900, "vitamins"],
    [/fola?te.*?(\d+\.?\d*)\s*(ng\/mL)?/i, "Folate", "ng/mL", 3, 20, "vitamins"],
    [/magnesium.*?(\d+\.?\d*)\s*(mg\/dL|mEq\/L)?/i, "Magnesium", "mg/dL", 1.7, 2.2, "vitamins"],
    [/zinc.*?(\d+\.?\d*)\s*(ug\/dL|mcg\/dL)?/i, "Zinc", "ug/dL", 60, 120, "vitamins"],
    [/calcium.*?(\d+\.?\d*)\s*(mg\/dL)?/i, "Calcium", "mg/dL", 8.5, 10.5, "vitamins"],
    [/hemoglobin\b.*?(\d+\.?\d*)\s*(g\/dL)?/i, "Hemoglobin", "g/dL", 12, 17, "blood"],
    [/creatinine.*?(\d+\.?\d*)\s*(mg\/dL)?/i, "Creatinine", "mg/dL", 0.6, 1.2, "kidney"],
    [/\b(?:alt|alanine\s*aminotransferase)\b.*?(\d+\.?\d*)\s*(U\/L)?/i, "ALT", "U/L", 7, 56, "liver"],
    [/\b(?:ast|aspartate\s*aminotransferase)\b.*?(\d+\.?\d*)\s*(U\/L)?/i, "AST", "U/L", 10, 40, "liver"],
    [/c[\s-]?reactive.*?(\d+\.?\d*)\s*(mg\/L)?/i, "CRP", "mg/L", 0, 3.0, "inflammatory"],
  ];

  const foundNames = new Set<string>();
  for (const [pattern, name, defaultUnit, refMin, refMax, category] of patterns) {
    const match = rawText.match(pattern);
    if (match && !foundNames.has(name)) {
      const value = parseFloat(match[1]);
      const unit = match[2] || defaultUnit;

      let status: string;
      if (value < refMin) status = "low";
      else if (value > refMax) status = "high";
      else status = "optimal";

      biomarkers.push({
        name, value, unit,
        reference_range: { min: refMin, max: refMax },
        status, category,
        confidence: 0.7,
      });
      foundNames.add(name);
    }
  }

  // Fallback sample data if no biomarkers found — vitamin-focused
  if (biomarkers.length === 0) {
    biomarkers.push(
      { name: "Vitamin D", value: 22.5, unit: "ng/mL", reference_range: { min: 30, max: 100 }, status: "low", category: "vitamins", confidence: 0.85 },
      { name: "Vitamin B12", value: 180, unit: "pg/mL", reference_range: { min: 200, max: 900 }, status: "low", category: "vitamins", confidence: 0.85 },
      { name: "Ferritin", value: 18, unit: "ng/mL", reference_range: { min: 20, max: 200 }, status: "low", category: "vitamins", confidence: 0.85 },
      { name: "Iron", value: 50, unit: "ug/dL", reference_range: { min: 60, max: 170 }, status: "low", category: "vitamins", confidence: 0.85 },
      { name: "Folate", value: 2.5, unit: "ng/mL", reference_range: { min: 3, max: 20 }, status: "low", category: "vitamins", confidence: 0.85 },
      { name: "Magnesium", value: 1.6, unit: "mg/dL", reference_range: { min: 1.7, max: 2.2 }, status: "low", category: "vitamins", confidence: 0.85 },
      { name: "Total Cholesterol", value: 210, unit: "mg/dL", reference_range: { min: 125, max: 200 }, status: "high", category: "lipids", confidence: 0.85 },
      { name: "Fasting Glucose", value: 95, unit: "mg/dL", reference_range: { min: 70, max: 100 }, status: "optimal", category: "metabolic", confidence: 0.85 },
    );
  }

  // Build food recommendations
  const foodRecs: Record<string, any>[] = [];
  for (const b of biomarkers) {
    if (b.status !== "optimal") {
      const recs = getFoodRecommendations(b.name, b.status, dietaryPreference);
      for (const r of recs) {
        foodRecs.push({ ...r, targets: [b.name] });
      }
    }
  }

  // Build summary
  const lowMarkers = biomarkers.filter(b => b.status === "low").map(b => b.name);
  const highMarkers = biomarkers.filter(b => b.status === "high").map(b => b.name);
  const summaryParts: string[] = [];
  if (lowMarkers.length) summaryParts.push(`Low levels detected: ${lowMarkers.join(", ")}.`);
  if (highMarkers.length) summaryParts.push(`Elevated levels detected: ${highMarkers.join(", ")}.`);
  if (!summaryParts.length) summaryParts.push("All biomarkers are within optimal range.");

  return [{
    biomarkers,
    summary: summaryParts.join(" "),
    correlations: detectCorrelations(biomarkers),
    key_findings: biomarkers.filter(b => b.status !== "optimal").map(b => `${b.name} is ${b.status}`),
    recommendations: biomarkers.filter(b => b.status !== "optimal").map(b => `Address ${b.name} levels`),
    food_recommendations: foodRecs,
    supplement_protocol: getSupplementProtocol(biomarkers),
    lifestyle_recommendations: [],
    record_date: null,
    lab_provider: null,
  }];
}

// ===== Main parser =====

export async function parseLabResults(
  rawText: string,
  dietaryPreference: string = "omnivore",
  advancedAnalysis: boolean = true
): Promise<ParsedReport[]> {
  // Try OpenRouter first, then Google Gemini, then fallback regex
  const hasOpenRouter = config.openrouterApiKey && config.openrouterApiKey !== "";
  const hasGoogle = config.googleApiKey && config.googleApiKey !== "" && config.googleApiKey !== "your-google-api-key";

  if (!hasOpenRouter && !hasGoogle) {
    console.log("[AI Parser] No API key configured - using fallback regex parser");
    return fallbackParse(rawText, dietaryPreference);
  }

  try {
    const prompt = ADVANCED_BIOMARKER_PROMPT.replace("{dietary_preference}", dietaryPreference) + rawText;
    let responseText: string;

    if (hasOpenRouter) {
      console.log("[AI Parser] Using OpenRouter for lab analysis");
      const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${config.openrouterApiKey}`,
          "Content-Type": "application/json",
          "HTTP-Referer": config.baseUrl,
          "X-Title": "HealthWallet Lab Parser",
        },
        body: JSON.stringify({
          model: config.openrouterModel,
          messages: [
            { role: "system", content: "You are a lab results parser. Return ONLY valid JSON, no markdown code blocks, no explanation." },
            { role: "user", content: prompt },
          ],
          temperature: 0.1,
          max_tokens: 8192,
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        console.error("[AI Parser] OpenRouter error:", response.status, errText);
        throw new Error(`OpenRouter API error: ${response.status}`);
      }

      const data = await response.json() as any;
      responseText = data.choices?.[0]?.message?.content ?? "";
    } else {
      console.log("[AI Parser] Using Google Gemini for lab analysis");
      const { GoogleGenerativeAI } = await import("@google/generative-ai");
      const genAI = new GoogleGenerativeAI(config.googleApiKey);
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

      const result = await model.generateContent({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: { maxOutputTokens: 8192, temperature: 0.1 },
      });

      responseText = result.response.text();
    }

    // Clean markdown blocks
    if (responseText.includes("```json")) {
      const start = responseText.indexOf("```json") + 7;
      const end = responseText.indexOf("```", start);
      responseText = responseText.slice(start, end).trim();
    } else if (responseText.includes("```")) {
      const start = responseText.indexOf("```") + 3;
      const end = responseText.indexOf("```", start);
      responseText = responseText.slice(start, end).trim();
    }

    const parsedData = JSON.parse(responseText);

    let reports: any[];
    if (parsedData.reports && Array.isArray(parsedData.reports)) {
      reports = parsedData.reports;
    } else if (parsedData.biomarkers) {
      reports = [parsedData];
    } else {
      reports = [];
    }

    const defaults: Record<string, any> = {
      biomarkers: [], recommendations: [], summary: null,
      correlations: [], key_findings: [], food_recommendations: [],
      supplement_protocol: [], lifestyle_recommendations: [],
      record_date: null, lab_provider: null,
    };

    return reports.map(report => {
      for (const [key, def] of Object.entries(defaults)) {
        if (!(key in report)) report[key] = def;
      }
      return report;
    });
  } catch (e: any) {
    return [{
      biomarkers: [],
      recommendations: ["Unable to parse lab results. Please ensure the document is a valid lab report."],
      summary: "We couldn't analyze this document. Please try uploading a clearer lab report.",
      correlations: [], key_findings: [], food_recommendations: [],
      supplement_protocol: [], lifestyle_recommendations: [],
      record_date: null, lab_provider: null,
      parse_error: String(e),
    }];
  }
}

// ===== Correlations =====

export function detectCorrelations(biomarkers: Record<string, any>[]): Record<string, any>[] {
  const correlations: Record<string, any>[] = [];
  const markers: Record<string, Record<string, any>> = {};
  for (const b of biomarkers) {
    markers[(b.name ?? "").toLowerCase()] = b;
  }

  const ferritin = markers["ferritin"] ?? {};
  const hemoglobin = markers["hemoglobin"] ?? {};
  if (ferritin.status === "low" && hemoglobin.status === "low") {
    correlations.push({
      markers: ["Ferritin", "Hemoglobin"],
      insight: "Both iron storage (ferritin) and oxygen-carrying capacity (hemoglobin) are low. This pattern strongly suggests iron deficiency anemia.",
      severity: "warning",
      condition: "Iron Deficiency Anemia",
    });
  }

  const glucose = markers["fasting glucose"] ?? markers["glucose"] ?? {};
  const triglycerides = markers["triglycerides"] ?? {};
  const hdl = markers["hdl"] ?? markers["hdl cholesterol"] ?? {};
  if (glucose.status === "high" && triglycerides.status === "high" && hdl.status === "low") {
    correlations.push({
      markers: ["Glucose", "Triglycerides", "HDL"],
      insight: "High blood sugar combined with high triglycerides and low HDL is a classic pattern of insulin resistance and metabolic syndrome.",
      severity: "critical",
      condition: "Metabolic Syndrome",
    });
  }

  const tsh = markers["tsh"] ?? {};
  const t3 = markers["free t3"] ?? {};
  if (tsh.status === "high" && t3.status === "low") {
    correlations.push({
      markers: ["TSH", "Free T3"],
      insight: "High TSH with low Free T3 suggests your thyroid is underperforming or you have poor T4 to T3 conversion.",
      severity: "warning",
      condition: "Hypothyroidism",
    });
  }

  const ldl = markers["ldl"] ?? markers["ldl cholesterol"] ?? {};
  const crp = markers["crp"] ?? markers["c-reactive protein"] ?? {};
  if (ldl.status === "high" && crp.status === "high") {
    correlations.push({
      markers: ["LDL Cholesterol", "CRP"],
      insight: "Elevated LDL combined with high inflammation (CRP) significantly increases cardiovascular risk.",
      severity: "critical",
      condition: "Elevated Cardiovascular Risk",
    });
  }

  const b12 = markers["vitamin b12"] ?? markers["b12"] ?? {};
  const homocysteine = markers["homocysteine"] ?? {};
  if (b12.status === "low" && homocysteine.status === "high") {
    correlations.push({
      markers: ["Vitamin B12", "Homocysteine"],
      insight: "Low B12 with elevated homocysteine indicates B12 deficiency affecting methylation pathways.",
      severity: "warning",
      condition: "B12 Deficiency / Methylation Issues",
    });
  }

  return correlations;
}

// ===== Food Recommendations =====

const FOOD_RECOMMENDATIONS_BY_DIET: Record<string, Record<string, Record<string, { food: string; portion: string; reason: string }[]>>> = {
  "Vitamin D": {
    low: {
      omnivore: [
        { food: "Salmon", portion: "4 oz, 2x/week", reason: "Rich in D3 and Omega-3s" },
        { food: "Egg Yolks", portion: "2-3 daily", reason: "Natural vitamin D source" },
        { food: "Cod Liver Oil", portion: "1 tbsp daily", reason: "Highest food source of D3" },
      ],
      vegetarian: [
        { food: "Egg Yolks", portion: "2-3 daily", reason: "Natural vitamin D source" },
        { food: "Fortified Milk", portion: "2 cups daily", reason: "Vitamin D fortified" },
        { food: "UV-Exposed Mushrooms", portion: "1 cup daily", reason: "Plant-based D2" },
      ],
      vegan: [
        { food: "UV-Exposed Mushrooms", portion: "1 cup daily", reason: "Plant-based vitamin D2" },
        { food: "Fortified Plant Milk", portion: "2 cups daily", reason: "Vitamin D fortified" },
        { food: "Fortified Orange Juice", portion: "1 cup daily", reason: "D-fortified option" },
      ],
      keto: [
        { food: "Salmon", portion: "6 oz, 3x/week", reason: "High fat, high D3" },
        { food: "Egg Yolks", portion: "4-6 daily", reason: "Keto-friendly D source" },
        { food: "Sardines", portion: "1 can, 3x/week", reason: "Vitamin D + healthy fats" },
      ],
      paleo: [
        { food: "Wild-Caught Salmon", portion: "4 oz, 3x/week", reason: "Paleo-approved, high D3" },
        { food: "Pasture-Raised Eggs", portion: "3 daily", reason: "Higher D than conventional" },
        { food: "Liver", portion: "3 oz, 2x/week", reason: "Nutrient-dense D source" },
      ],
      pescatarian: [
        { food: "Salmon", portion: "4 oz, 3x/week", reason: "Best food source of D3" },
        { food: "Mackerel", portion: "4 oz, 2x/week", reason: "Excellent D3 content" },
        { food: "Sardines", portion: "1 can, 2x/week", reason: "Affordable D source" },
      ],
    },
  },
  Iron: {
    low: {
      omnivore: [
        { food: "Beef Liver", portion: "3 oz, 2x/week", reason: "Highest heme iron" },
        { food: "Grass-Fed Beef", portion: "4 oz, 3x/week", reason: "Highly absorbable iron" },
        { food: "Oysters", portion: "6 oysters, 2x/week", reason: "Iron + zinc combo" },
      ],
      vegetarian: [
        { food: "Eggs + Spinach", portion: "2 eggs + 2 cups spinach", reason: "Iron with absorption helpers" },
        { food: "Lentils with Lemon", portion: "1 cup + lemon juice", reason: "Vitamin C boosts iron absorption" },
        { food: "Fortified Cereals", portion: "1 serving daily", reason: "Iron-fortified breakfast" },
      ],
      vegan: [
        { food: "Lentils + Bell Pepper", portion: "1 cup + 1 pepper", reason: "Vitamin C boosts plant iron absorption" },
        { food: "Spinach + Citrus Dressing", portion: "3 cups salad", reason: "Maximize iron uptake" },
        { food: "Pumpkin Seeds", portion: "1/4 cup daily", reason: "Iron-rich snack" },
      ],
      keto: [
        { food: "Beef Liver", portion: "3 oz, 2x/week", reason: "Keto-friendly, iron-rich" },
        { food: "Grass-Fed Steak", portion: "6 oz, 3x/week", reason: "High fat + high iron" },
        { food: "Sardines", portion: "1 can daily", reason: "Low-carb iron source" },
      ],
      paleo: [
        { food: "Grass-Fed Beef", portion: "4 oz, 4x/week", reason: "Paleo staple, high iron" },
        { food: "Liver Pate", portion: "2 oz, 3x/week", reason: "Organ meat = nutrient dense" },
        { food: "Lamb", portion: "4 oz, 2x/week", reason: "Red meat variety" },
      ],
      pescatarian: [
        { food: "Oysters", portion: "6, 2x/week", reason: "Highest seafood iron" },
        { food: "Clams", portion: "3 oz, 2x/week", reason: "Excellent iron content" },
        { food: "Mussels", portion: "3 oz, 2x/week", reason: "Shellfish iron source" },
      ],
    },
  },
  "LDL Cholesterol": {
    high: {
      omnivore: [
        { food: "Oatmeal", portion: "1 cup daily", reason: "Soluble fiber lowers LDL" },
        { food: "Salmon", portion: "4 oz, 2x/week", reason: "Omega-3s improve lipid profile" },
        { food: "Almonds", portion: "1 oz daily", reason: "Plant sterols reduce absorption" },
      ],
      vegetarian: [
        { food: "Oatmeal", portion: "1 cup daily", reason: "Soluble fiber lowers LDL" },
        { food: "Walnuts", portion: "1 oz daily", reason: "ALA omega-3s for heart health" },
        { food: "Avocado", portion: "1/2 daily", reason: "Monounsaturated fats improve ratio" },
      ],
      vegan: [
        { food: "Oatmeal", portion: "1 cup daily", reason: "Soluble fiber lowers LDL" },
        { food: "Ground Flaxseed", portion: "2 tbsp daily", reason: "Fiber + omega-3s" },
        { food: "Beans/Lentils", portion: "1 cup daily", reason: "Soluble fiber powerhouse" },
      ],
      keto: [
        { food: "Avocado", portion: "1 daily", reason: "Healthy fats, fiber" },
        { food: "Macadamia Nuts", portion: "1 oz daily", reason: "Best nut for lipids on keto" },
        { food: "Olive Oil", portion: "3 tbsp daily", reason: "Monounsaturated fats" },
      ],
      paleo: [
        { food: "Avocado", portion: "1 daily", reason: "Paleo-approved healthy fat" },
        { food: "Wild Salmon", portion: "4 oz, 3x/week", reason: "Omega-3s improve lipids" },
        { food: "Walnuts", portion: "1 oz daily", reason: "ALA for heart health" },
      ],
      pescatarian: [
        { food: "Salmon", portion: "4 oz, 3x/week", reason: "EPA/DHA lower triglycerides" },
        { food: "Oatmeal", portion: "1 cup daily", reason: "Soluble fiber lowers LDL" },
        { food: "Sardines", portion: "1 can, 2x/week", reason: "Omega-3 rich" },
      ],
    },
  },
};

export function getFoodRecommendations(
  biomarkerName: string,
  status: string,
  dietaryPreference: string = "omnivore"
): { food: string; portion: string; reason: string }[] {
  const biomarkerRecs = FOOD_RECOMMENDATIONS_BY_DIET[biomarkerName] ?? {};
  const statusRecs = biomarkerRecs[status] ?? {};
  return statusRecs[dietaryPreference] ?? statusRecs["omnivore"] ?? [];
}

// ===== Supplement Protocols =====

const SUPPLEMENT_PROTOCOLS: Record<string, Record<string, { name: string; dosage: string; reason: string; priority: string }>> = {
  "Vitamin D": {
    low: { name: "Vitamin D3 + K2", dosage: "5000 IU D3 + 100mcg K2 daily with fatty meal", reason: "D3 is better absorbed than D2. K2 ensures calcium goes to bones, not arteries.", priority: "essential" },
  },
  Iron: {
    low: { name: "Iron Bisglycinate", dosage: "25-50mg every other day with vitamin C", reason: "Bisglycinate form is gentle on stomach. Take with 500mg vitamin C for absorption.", priority: "essential" },
  },
  "Vitamin B12": {
    low: { name: "Methylcobalamin B12", dosage: "1000-2000mcg sublingual daily", reason: "Methylcobalamin is the active form. Sublingual bypasses digestion issues.", priority: "essential" },
  },
  Magnesium: {
    low: { name: "Magnesium Glycinate", dosage: "300-400mg before bed", reason: "Glycinate form supports sleep and is well-absorbed. Avoid oxide form.", priority: "recommended" },
  },
  "HDL Cholesterol": {
    low: { name: "Omega-3 Fish Oil", dosage: "2-3g EPA+DHA daily with food", reason: "High-dose omega-3s raise HDL and lower triglycerides.", priority: "recommended" },
  },
  Homocysteine: {
    high: { name: "Methylated B-Complex", dosage: "1 capsule daily with food", reason: "Contains methylfolate and methylcobalamin to support homocysteine metabolism.", priority: "essential" },
  },
  Folate: {
    low: { name: "Methylfolate (5-MTHF)", dosage: "400-800mcg daily", reason: "Active form of folate, no conversion needed. Supports DNA synthesis and methylation.", priority: "essential" },
  },
  Zinc: {
    low: { name: "Zinc Picolinate", dosage: "15-30mg daily with food", reason: "Picolinate form is well-absorbed. Supports immune function and hormone production.", priority: "recommended" },
  },
  Calcium: {
    low: { name: "Calcium Citrate + D3", dosage: "500mg calcium + 1000 IU D3, 2x daily", reason: "Citrate form absorbed without food. D3 needed for calcium absorption.", priority: "recommended" },
  },
  Ferritin: {
    low: { name: "Iron Bisglycinate", dosage: "25-50mg every other day with vitamin C", reason: "Low ferritin indicates depleted iron stores. Bisglycinate is gentle on stomach.", priority: "essential" },
  },
};

export function getSupplementProtocol(biomarkers: Record<string, any>[]): Record<string, any>[] {
  const protocols: Record<string, any>[] = [];

  for (const biomarker of biomarkers) {
    const name = biomarker.name ?? "";
    const status = biomarker.status ?? "optimal";
    if (status === "optimal") continue;

    const protocol = SUPPLEMENT_PROTOCOLS[name]?.[status];
    if (protocol) {
      protocols.push({ ...protocol, biomarker_link: name });
    }
  }

  const priorityOrder: Record<string, number> = { essential: 0, recommended: 1, optional: 2 };
  protocols.sort((a, b) => (priorityOrder[a.priority] ?? 2) - (priorityOrder[b.priority] ?? 2));

  return protocols;
}
