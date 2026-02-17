export interface NutrientNeed {
  nutrient: string;
  reason: string;
  biomarker: string;
  status: string; // "low" or "high"
}

export interface FoodRecommendation {
  name: string;
  category: string; // "protein", "vegetable", "fruit", "grain", "fat", "dairy", "legume"
  nutrients: string[]; // which needs it addresses
  why: string;
  serving: string;
  tags: string[]; // "vegetarian", "vegan", "gluten-free", "dairy-free", "keto"
}

/** Map of biomarker name (lowercase) -> { condition, nutrients, foods } */
const BIOMARKER_NUTRIENT_MAP: Record<string, {
  low?: { nutrients: string[]; foods: FoodRecommendation[] };
  high?: { nutrients: string[]; foods: FoodRecommendation[] };
}> = {
  "vitamin d": {
    low: {
      nutrients: ["Vitamin D3", "Calcium"],
      foods: [
        { name: "Salmon", category: "protein", nutrients: ["Vitamin D3", "Omega-3"], why: "One of the richest natural sources of Vitamin D", serving: "150g fillet", tags: ["gluten-free", "dairy-free", "keto"] },
        { name: "Sardines", category: "protein", nutrients: ["Vitamin D3", "Calcium", "Omega-3"], why: "Excellent Vitamin D plus bone-building calcium", serving: "1 can (120g)", tags: ["gluten-free", "dairy-free", "keto"] },
        { name: "Egg Yolks", category: "protein", nutrients: ["Vitamin D3"], why: "Each yolk provides ~40 IU of Vitamin D", serving: "2-3 eggs", tags: ["vegetarian", "gluten-free", "keto"] },
        { name: "Fortified Mushrooms", category: "vegetable", nutrients: ["Vitamin D2"], why: "UV-exposed mushrooms are the best plant source of Vitamin D", serving: "1 cup sliced", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
      ],
    },
  },
  "iron": {
    low: {
      nutrients: ["Iron", "Vitamin C"],
      foods: [
        { name: "Beef Liver", category: "protein", nutrients: ["Iron", "B12", "Folate"], why: "Highest bioavailable iron source (heme iron)", serving: "100g", tags: ["gluten-free", "dairy-free", "keto"] },
        { name: "Spinach", category: "vegetable", nutrients: ["Iron", "Folate"], why: "Rich in non-heme iron — pair with Vitamin C for absorption", serving: "2 cups raw", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Lentils", category: "legume", nutrients: ["Iron", "Folate", "Fiber"], why: "Plant-based iron powerhouse", serving: "1 cup cooked", tags: ["vegetarian", "vegan", "gluten-free"] },
        { name: "Dark Chocolate (85%+)", category: "fat", nutrients: ["Iron", "Magnesium"], why: "Surprisingly good iron source", serving: "30g", tags: ["vegetarian", "vegan", "gluten-free"] },
      ],
    },
  },
  "ferritin": {
    low: {
      nutrients: ["Iron", "Vitamin C"],
      foods: [
        { name: "Red Meat", category: "protein", nutrients: ["Iron", "B12", "Zinc"], why: "Most bioavailable form of heme iron to rebuild ferritin stores", serving: "150g", tags: ["gluten-free", "dairy-free", "keto"] },
        { name: "Pumpkin Seeds", category: "fat", nutrients: ["Iron", "Zinc", "Magnesium"], why: "Excellent plant iron source — great as snack", serving: "30g (2 tbsp)", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Tofu", category: "protein", nutrients: ["Iron", "Calcium"], why: "Good plant-based iron, especially firm/extra-firm", serving: "150g", tags: ["vegetarian", "vegan", "gluten-free"] },
      ],
    },
  },
  "vitamin b12": {
    low: {
      nutrients: ["Vitamin B12"],
      foods: [
        { name: "Clams", category: "protein", nutrients: ["B12", "Iron"], why: "Highest B12 of any food — just 3oz provides 1400% DV", serving: "85g", tags: ["gluten-free", "dairy-free"] },
        { name: "Nutritional Yeast", category: "grain", nutrients: ["B12", "B-vitamins"], why: "Fortified vegan B12 source with cheesy flavor", serving: "2 tbsp", tags: ["vegetarian", "vegan", "gluten-free"] },
        { name: "Eggs", category: "protein", nutrients: ["B12", "Vitamin D3"], why: "Easy daily B12 source", serving: "2 eggs", tags: ["vegetarian", "gluten-free", "keto"] },
      ],
    },
  },
  "folate": {
    low: {
      nutrients: ["Folate", "B-vitamins"],
      foods: [
        { name: "Asparagus", category: "vegetable", nutrients: ["Folate", "Vitamin K"], why: "One of the richest vegetable sources of folate", serving: "1 cup cooked", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Avocado", category: "fat", nutrients: ["Folate", "Potassium"], why: "Creamy folate-rich superfood", serving: "1 whole", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Black Beans", category: "legume", nutrients: ["Folate", "Iron", "Fiber"], why: "Folate-dense legume", serving: "1 cup cooked", tags: ["vegetarian", "vegan", "gluten-free"] },
      ],
    },
  },
  "magnesium": {
    low: {
      nutrients: ["Magnesium"],
      foods: [
        { name: "Almonds", category: "fat", nutrients: ["Magnesium", "Vitamin E"], why: "Top magnesium snack — 80mg per ounce", serving: "30g (23 almonds)", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Dark Leafy Greens", category: "vegetable", nutrients: ["Magnesium", "Iron", "Folate"], why: "Swiss chard and spinach are magnesium powerhouses", serving: "2 cups", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Banana", category: "fruit", nutrients: ["Magnesium", "Potassium"], why: "Easy magnesium and potassium source", serving: "1 medium", tags: ["vegetarian", "vegan", "gluten-free"] },
      ],
    },
  },
  "fasting glucose": {
    high: {
      nutrients: ["Fiber", "Chromium", "Magnesium"],
      foods: [
        { name: "Cinnamon", category: "fat", nutrients: ["Chromium"], why: "May help improve insulin sensitivity", serving: "1 tsp daily", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Oats (Steel-Cut)", category: "grain", nutrients: ["Fiber", "Magnesium"], why: "Slow-release carbs help stabilize blood sugar", serving: "1/2 cup dry", tags: ["vegetarian", "vegan"] },
        { name: "Berries", category: "fruit", nutrients: ["Fiber", "Antioxidants"], why: "Low-glycemic fruit packed with fiber", serving: "1 cup", tags: ["vegetarian", "vegan", "gluten-free"] },
        { name: "Broccoli", category: "vegetable", nutrients: ["Fiber", "Chromium", "Sulforaphane"], why: "Sulforaphane may reduce blood sugar", serving: "1 cup", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
      ],
    },
  },
  "ldl cholesterol": {
    high: {
      nutrients: ["Fiber", "Omega-3", "Plant Sterols"],
      foods: [
        { name: "Oatmeal", category: "grain", nutrients: ["Soluble Fiber"], why: "Beta-glucan in oats can lower LDL by 5-10%", serving: "1 cup cooked", tags: ["vegetarian", "vegan"] },
        { name: "Walnuts", category: "fat", nutrients: ["Omega-3", "Fiber"], why: "Heart-healthy omega-3s help reduce LDL", serving: "30g (14 halves)", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Avocado", category: "fat", nutrients: ["Monounsaturated Fat", "Fiber"], why: "Replaces saturated fat; can lower LDL", serving: "1/2 avocado", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Olive Oil (Extra Virgin)", category: "fat", nutrients: ["Monounsaturated Fat", "Polyphenols"], why: "Mediterranean diet staple for heart health", serving: "2 tbsp", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
      ],
    },
  },
  "hdl cholesterol": {
    low: {
      nutrients: ["Omega-3", "Monounsaturated Fat"],
      foods: [
        { name: "Fatty Fish (Salmon/Mackerel)", category: "protein", nutrients: ["Omega-3"], why: "Omega-3 fatty acids boost HDL levels", serving: "150g", tags: ["gluten-free", "dairy-free", "keto"] },
        { name: "Olive Oil", category: "fat", nutrients: ["Monounsaturated Fat"], why: "Increases HDL when used as primary cooking oil", serving: "2 tbsp", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Coconut Oil", category: "fat", nutrients: ["MCT"], why: "MCTs may help increase HDL", serving: "1 tbsp", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
      ],
    },
  },
  "triglycerides": {
    high: {
      nutrients: ["Omega-3", "Fiber"],
      foods: [
        { name: "Salmon", category: "protein", nutrients: ["Omega-3"], why: "EPA/DHA directly lower triglycerides", serving: "150g", tags: ["gluten-free", "dairy-free", "keto"] },
        { name: "Chia Seeds", category: "fat", nutrients: ["Omega-3", "Fiber"], why: "Plant omega-3 (ALA) plus fiber to lower triglycerides", serving: "2 tbsp", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Flaxseed", category: "fat", nutrients: ["Omega-3", "Fiber"], why: "Ground flaxseed is one of the best plant sources of ALA omega-3", serving: "2 tbsp ground", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
      ],
    },
  },
  "hemoglobin a1c": {
    high: {
      nutrients: ["Fiber", "Chromium", "Alpha-Lipoic Acid"],
      foods: [
        { name: "Leafy Greens", category: "vegetable", nutrients: ["Fiber", "Magnesium"], why: "Very low glycemic impact; magnesium helps insulin sensitivity", serving: "3 cups", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Sweet Potato", category: "vegetable", nutrients: ["Fiber", "Beta-Carotene"], why: "Lower glycemic than white potato; fiber slows sugar absorption", serving: "1 medium", tags: ["vegetarian", "vegan", "gluten-free"] },
        { name: "Legumes (Chickpeas/Lentils)", category: "legume", nutrients: ["Fiber", "Protein"], why: "High fiber and protein combo stabilizes blood sugar", serving: "1 cup cooked", tags: ["vegetarian", "vegan", "gluten-free"] },
      ],
    },
  },
  "zinc": {
    low: {
      nutrients: ["Zinc"],
      foods: [
        { name: "Oysters", category: "protein", nutrients: ["Zinc", "B12", "Iron"], why: "Highest zinc food — 6 oysters = 300% DV", serving: "6 medium", tags: ["gluten-free", "dairy-free"] },
        { name: "Pumpkin Seeds", category: "fat", nutrients: ["Zinc", "Magnesium", "Iron"], why: "Best plant zinc source", serving: "30g", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
        { name: "Beef", category: "protein", nutrients: ["Zinc", "Iron", "B12"], why: "Highly bioavailable zinc", serving: "150g", tags: ["gluten-free", "dairy-free", "keto"] },
      ],
    },
  },
  "omega-3 index": {
    low: {
      nutrients: ["EPA", "DHA"],
      foods: [
        { name: "Wild Salmon", category: "protein", nutrients: ["EPA", "DHA"], why: "Richest source of anti-inflammatory omega-3s", serving: "150g", tags: ["gluten-free", "dairy-free", "keto"] },
        { name: "Sardines", category: "protein", nutrients: ["EPA", "DHA", "Calcium"], why: "Sustainable and affordable omega-3 source", serving: "1 can", tags: ["gluten-free", "dairy-free", "keto"] },
        { name: "Walnuts", category: "fat", nutrients: ["ALA"], why: "Plant-based omega-3 (converts partially to EPA/DHA)", serving: "30g", tags: ["vegetarian", "vegan", "gluten-free", "keto"] },
      ],
    },
  },
};

/**
 * Analyze biomarkers and return nutrient needs + food recommendations.
 */
export function analyzeNutrientNeeds(
  biomarkers: { name: string; value: number; unit: string; status?: string | null }[],
): { needs: NutrientNeed[]; foods: FoodRecommendation[] } {
  const needs: NutrientNeed[] = [];
  const foodSet = new Map<string, FoodRecommendation>(); // dedupe by food name

  for (const biomarker of biomarkers) {
    const status = biomarker.status?.toLowerCase();
    if (status !== "low" && status !== "high") continue;

    const name = biomarker.name.toLowerCase();
    // Try exact match first, then partial match
    let mapping = BIOMARKER_NUTRIENT_MAP[name];
    if (!mapping) {
      for (const [key, val] of Object.entries(BIOMARKER_NUTRIENT_MAP)) {
        if (name.includes(key) || key.includes(name)) {
          mapping = val;
          break;
        }
      }
    }
    if (!mapping) continue;

    const directionMap = status === "low" ? mapping.low : mapping.high;
    if (!directionMap) continue;

    for (const nutrient of directionMap.nutrients) {
      needs.push({
        nutrient,
        reason: `${biomarker.name} is ${status} (${biomarker.value} ${biomarker.unit})`,
        biomarker: biomarker.name,
        status,
      });
    }

    for (const food of directionMap.foods) {
      if (!foodSet.has(food.name)) {
        foodSet.set(food.name, food);
      }
    }
  }

  return { needs, foods: Array.from(foodSet.values()) };
}

/**
 * Filter foods by dietary preference.
 */
export function filterByDiet(
  foods: FoodRecommendation[],
  diet: string,
  allergies: string[] = [],
): FoodRecommendation[] {
  let filtered = foods;

  // Filter by diet
  if (diet !== "omnivore") {
    const tagMap: Record<string, string> = {
      vegetarian: "vegetarian",
      vegan: "vegan",
      keto: "keto",
      paleo: "gluten-free", // paleo is roughly gluten-free + dairy-free
      pescatarian: "vegetarian", // pescatarian includes fish, which is tagged as non-vegetarian
    };
    const requiredTag = tagMap[diet];
    if (requiredTag && diet !== "pescatarian") {
      filtered = filtered.filter((f) => f.tags.includes(requiredTag));
    } else if (diet === "pescatarian") {
      // Pescatarian: vegetarian foods + fish/seafood
      filtered = filtered.filter(
        (f) =>
          f.tags.includes("vegetarian") ||
          (f.category === "protein" &&
            (f.name.toLowerCase().includes("salmon") ||
              f.name.toLowerCase().includes("fish") ||
              f.name.toLowerCase().includes("sardine") ||
              f.name.toLowerCase().includes("clam") ||
              f.name.toLowerCase().includes("oyster"))),
      );
    }
  }

  // Filter by allergies (simple keyword match)
  if (allergies.length > 0) {
    const allergyLower = allergies.map((a) => a.toLowerCase());
    filtered = filtered.filter((f) => {
      const nameLower = f.name.toLowerCase();
      return !allergyLower.some((a) => nameLower.includes(a));
    });
  }

  return filtered;
}

/**
 * Generate a simple weekly meal plan from food recommendations.
 */
export function generateMealPlan(
  foods: FoodRecommendation[],
  days: number = 7,
): { day: number; dayName: string; meals: { type: string; foods: FoodRecommendation[] }[] }[] {
  const dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  const proteins = foods.filter((f) => f.category === "protein");
  const vegetables = foods.filter((f) => f.category === "vegetable");
  const fats = foods.filter((f) => f.category === "fat");
  const grains = foods.filter((f) => f.category === "grain");
  const fruits = foods.filter((f) => f.category === "fruit");
  const legumes = foods.filter((f) => f.category === "legume");

  const pick = (arr: FoodRecommendation[], idx: number): FoodRecommendation | null =>
    arr.length > 0 ? arr[idx % arr.length] : null;

  const plan: { day: number; dayName: string; meals: { type: string; foods: FoodRecommendation[] }[] }[] = [];

  for (let i = 0; i < days; i++) {
    const dayMeals: { type: string; foods: FoodRecommendation[] }[] = [];

    // Breakfast
    const breakfast: FoodRecommendation[] = [];
    const bGrain = pick(grains, i);
    const bFruit = pick(fruits, i);
    const bProtein = pick(proteins, i + 1);
    if (bGrain) breakfast.push(bGrain);
    if (bFruit) breakfast.push(bFruit);
    if (bProtein) breakfast.push(bProtein);
    if (breakfast.length === 0) {
      const bFat = pick(fats, i);
      if (bFat) breakfast.push(bFat);
    }
    dayMeals.push({ type: "breakfast", foods: breakfast });

    // Lunch
    const lunch: FoodRecommendation[] = [];
    const lProtein = pick(proteins, i);
    const lVeg = pick(vegetables, i);
    const lLegume = pick(legumes, i);
    if (lProtein) lunch.push(lProtein);
    if (lVeg) lunch.push(lVeg);
    if (lLegume) lunch.push(lLegume);
    dayMeals.push({ type: "lunch", foods: lunch });

    // Dinner
    const dinner: FoodRecommendation[] = [];
    const dProtein = pick(proteins, i + 2);
    const dVeg = pick(vegetables, i + 1);
    const dFat = pick(fats, i);
    if (dProtein) dinner.push(dProtein);
    if (dVeg) dinner.push(dVeg);
    if (dFat) dinner.push(dFat);
    dayMeals.push({ type: "dinner", foods: dinner });

    // Snack
    const snack: FoodRecommendation[] = [];
    const sFat = pick(fats, i + 1);
    const sFruit = pick(fruits, i + 1);
    if (sFat) snack.push(sFat);
    if (sFruit) snack.push(sFruit);
    dayMeals.push({ type: "snack", foods: snack });

    plan.push({ day: i + 1, dayName: dayNames[i % 7], meals: dayMeals });
  }

  return plan;
}
