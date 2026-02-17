import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { getDb } from "../db.js";
import { getCurrentUser } from "../middleware/auth.js";
import { analyzeNutrientNeeds, filterByDiet, generateMealPlan } from "../services/nutrient-mapping.js";
import type { HealthRecord } from "../models/health-record.js";
import { RecordStatus } from "../models/health-record.js";
import { isPro } from "../utils/subscription.js";

const nutrition = new Hono();

// GET /nutrition/recommendations — personalized food recs based on latest biomarkers
nutrition.get("/recommendations", async (c) => {
  const user = await getCurrentUser(c);
  const pro = isPro(user);
  const db = getDb();

  // Get latest completed record with biomarkers
  const record = await db.collection<HealthRecord>("health_records").findOne(
    {
      user_id: user._id,
      status: RecordStatus.COMPLETED,
      biomarkers: { $exists: true, $ne: [] },
    },
    { sort: { created_at: -1 } },
  );

  if (!record || !record.biomarkers?.length) {
    return c.json({
      message: "Upload blood work to get personalized food recommendations",
      needs: [],
      foods: [],
      has_data: false,
    });
  }

  const { needs, foods } = analyzeNutrientNeeds(record.biomarkers as any[]);
  const diet = user.dietary_preference ?? "omnivore";
  const allergies = user.allergies ?? [];
  const filtered = filterByDiet(foods, diet, allergies);

  return c.json({
    has_data: true,
    record_date: record.record_date,
    dietary_preference: diet,
    needs,
    foods: pro ? filtered : filtered.slice(0, 3),
    total_unfiltered: foods.length,
  });
});

// GET /nutrition/meal-plan — weekly meal plan
nutrition.get("/meal-plan", async (c) => {
  const user = await getCurrentUser(c);
  const db = getDb();
  const days = Math.min(parseInt(c.req.query("days") ?? "7"), 14);

  const record = await db.collection<HealthRecord>("health_records").findOne(
    {
      user_id: user._id,
      status: RecordStatus.COMPLETED,
      biomarkers: { $exists: true, $ne: [] },
    },
    { sort: { created_at: -1 } },
  );

  if (!record || !record.biomarkers?.length) {
    return c.json({
      message: "Upload blood work to get a personalized meal plan",
      plan: [],
      has_data: false,
    });
  }

  const { foods } = analyzeNutrientNeeds(record.biomarkers as any[]);
  const diet = user.dietary_preference ?? "omnivore";
  const allergies = user.allergies ?? [];
  const filtered = filterByDiet(foods, diet, allergies);
  const plan = generateMealPlan(filtered, days);

  return c.json({
    has_data: true,
    dietary_preference: diet,
    days_planned: days,
    plan,
  });
});

// GET /nutrition/weekly-focus — top 6 actionable recommendations for Home screen
nutrition.get("/weekly-focus", async (c) => {
  const user = await getCurrentUser(c);
  const db = getDb();

  const record = await db.collection<HealthRecord>("health_records").findOne(
    {
      user_id: user._id,
      status: RecordStatus.COMPLETED,
      biomarkers: { $exists: true, $ne: [] },
    },
    { sort: { created_at: -1 } },
  );

  if (!record || !record.biomarkers?.length) {
    return c.json({ items: [], summary: "Upload blood work to get personalized focus items" });
  }

  const items: {
    title: string;
    subtitle: string;
    icon_name: string;
    action_label: string;
    action_type: "reminder" | "recipe" | "activity" | "tip";
    reminder_name?: string;
    reminder_timing?: string;
    reminder_hour?: number;
  }[] = [];

  for (const b of record.biomarkers) {
    const name = (b.name ?? "").toLowerCase();
    const isLow = b.status === "low";

    if (name.includes("vitamin d")) {
      items.push({ title: "Add Salmon", subtitle: "Omega-3 & Vitamin D boost", icon_name: "fish.fill", action_label: "See Recipe", action_type: "recipe" });
      items.push({ title: "Morning Sun", subtitle: "15 mins before 10 AM", icon_name: "sun.max.fill", action_label: "Set Reminder", action_type: "reminder", reminder_name: "Morning Sun (15 min)", reminder_timing: "morning_empty_stomach", reminder_hour: 8 });
    } else if (name.includes("cholesterol") || name.includes("ldl")) {
      items.push({ title: "Add Oatmeal", subtitle: "Soluble fiber lowers LDL", icon_name: "leaf.fill", action_label: "See Recipe", action_type: "recipe" });
      items.push({ title: "30 Min Walk", subtitle: "Daily cardio helps cholesterol", icon_name: "figure.walk", action_label: "Set Reminder", action_type: "reminder", reminder_name: "30 Min Walk", reminder_timing: "afternoon", reminder_hour: 17 });
    } else if (name.includes("hdl") && isLow) {
      items.push({ title: "Eat Avocados", subtitle: "Healthy fats boost HDL", icon_name: "heart.fill", action_label: "See Recipe", action_type: "recipe" });
    } else if (name.includes("triglyceride")) {
      items.push({ title: "Cut Refined Carbs", subtitle: "Reduce bread, pasta, sugar", icon_name: "xmark.circle.fill", action_label: "Tips", action_type: "tip" });
    } else if (name.includes("iron") || name.includes("ferritin")) {
      items.push({ title: isLow ? "Spinach & Red Meat" : "Reduce Red Meat", subtitle: isLow ? "Iron-rich foods with vitamin C" : "High iron may need monitoring", icon_name: "leaf.fill", action_label: "See Recipe", action_type: "recipe" });
    } else if (name.includes("b12") || name.includes("cobalamin")) {
      items.push({ title: "Add Eggs & Dairy", subtitle: "B12 for energy & nerves", icon_name: "bolt.fill", action_label: "See Recipe", action_type: "recipe" });
      items.push({ title: "B12 Supplement", subtitle: "Methylcobalamin 1000mcg daily", icon_name: "pills.fill", action_label: "Set Reminder", action_type: "reminder", reminder_name: "B12 Supplement", reminder_timing: "morning_with_food", reminder_hour: 8 });
    } else if (name.includes("folate") || name.includes("folic")) {
      items.push({ title: "Eat Dark Leafy Greens", subtitle: "Folate for cell repair", icon_name: "leaf.fill", action_label: "See Recipe", action_type: "recipe" });
    } else if (name.includes("glucose") || name.includes("blood sugar") || name.includes("hba1c")) {
      items.push({ title: "Reduce Sugar", subtitle: "Swap refined carbs for whole grains", icon_name: "cube.fill", action_label: "Tips", action_type: "tip" });
      items.push({ title: "Post-Meal Walk", subtitle: "10 min walk after meals", icon_name: "figure.walk", action_label: "Set Reminder", action_type: "reminder", reminder_name: "Post-Meal Walk (10 min)", reminder_timing: "afternoon", reminder_hour: 13 });
    } else if (name.includes("tsh")) {
      items.push({ title: "Brazil Nuts", subtitle: "Selenium supports thyroid", icon_name: "tree.fill", action_label: "See Recipe", action_type: "recipe" });
    } else if (name.includes("crp") || name.includes("c-reactive")) {
      items.push({ title: "Anti-Inflammatory Diet", subtitle: "Berries, turmeric, omega-3", icon_name: "flame.fill", action_label: "See Recipe", action_type: "recipe" });
    } else if (name.includes("magnesium")) {
      items.push({ title: "Dark Chocolate & Nuts", subtitle: "Magnesium for sleep & recovery", icon_name: "moon.fill", action_label: "See Recipe", action_type: "recipe" });
      items.push({ title: "Magnesium Before Bed", subtitle: "Glycinate 400mg nightly", icon_name: "pills.fill", action_label: "Set Reminder", action_type: "reminder", reminder_name: "Magnesium Supplement", reminder_timing: "evening_before_bed", reminder_hour: 22 });
    } else if (name.includes("zinc")) {
      items.push({ title: "Pumpkin Seeds", subtitle: "Zinc for immunity & skin", icon_name: "leaf.fill", action_label: "See Recipe", action_type: "recipe" });
    } else if (name.includes("calcium")) {
      items.push({ title: isLow ? "Add Dairy or Fortified Foods" : "Watch Calcium Intake", subtitle: isLow ? "Calcium for bones & muscles" : "Excess calcium needs monitoring", icon_name: "cup.and.saucer.fill", action_label: "Tips", action_type: "tip" });
    } else if (name.includes("hemoglobin") || name.includes("haemoglobin")) {
      items.push({ title: "Iron-Rich Foods", subtitle: "Lentils, beef, fortified cereals", icon_name: "drop.fill", action_label: "See Recipe", action_type: "recipe" });
    } else if (name.includes("creatinine")) {
      items.push({ title: "Stay Hydrated", subtitle: "8+ glasses of water daily", icon_name: "drop.fill", action_label: "Set Reminder", action_type: "reminder", reminder_name: "Drink Water", reminder_timing: "morning_empty_stomach", reminder_hour: 7 });
    } else if (name.includes("alt") || name.includes("ast")) {
      items.push({ title: "Liver Support", subtitle: "Reduce alcohol, add cruciferous veg", icon_name: "leaf.fill", action_label: "Tips", action_type: "tip" });
    } else if (b.status !== "optimal") {
      items.push({ title: `Optimize ${b.name}`, subtitle: `${b.name} is ${b.status} — ask AI for tips`, icon_name: "sparkles", action_label: "Ask AI", action_type: "recipe" });
    }
  }

  const flagged = record.biomarkers.filter(b => b.status !== "optimal");
  const names = flagged.map(b => `${(b.status ?? "").toLowerCase()} ${b.name}`);
  const summary = names.length > 0
    ? `Based on your ${names.slice(0, 3).join(" and ")}.`
    : "All biomarkers look great!";

  return c.json({ items: items.slice(0, 6), summary });
});

export default nutrition;
