import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { ObjectId } from "mongodb";
import { getDb } from "../db.js";
import { getCurrentUser } from "../middleware/auth.js";
import type { HealthRecord } from "../models/health-record.js";
import { getSupplementKeyword } from "../services/affiliate-keywords.js";
import { buildAffiliateLinks } from "../services/affiliate-link.js";
import { isPro } from "../utils/subscription.js";

const affiliate = new Hono();

export interface SupplementRecommendation {
  name: string;
  dosage: string;
  reason: string;
  biomarker_link: string;
  priority: string;
  // Affiliate fields
  keyword: string;
  keyword_reason: string;
  timing: string;
  timing_note: string;
  amazon_url: string;
  iherb_url: string | null;
}

const priorityOrder: Record<string, number> = { essential: 0, recommended: 1, optional: 2 };

function buildRecommendations(
  supplementProtocol: Record<string, any>[],
  country: string,
): SupplementRecommendation[] {
  const recommendations: SupplementRecommendation[] = supplementProtocol.map((supp: any) => {
    const name = supp.name ?? "Unknown";
    const kw = getSupplementKeyword(name);
    const links = buildAffiliateLinks(kw.keyword, country);

    return {
      name,
      dosage: supp.dosage ?? "",
      reason: supp.reason ?? "",
      biomarker_link: supp.biomarker_link ?? "",
      priority: supp.priority ?? "recommended",
      keyword: kw.keyword,
      keyword_reason: kw.reason,
      timing: kw.timing,
      timing_note: kw.timing_note,
      amazon_url: links.amazon_url,
      iherb_url: links.iherb_url,
    };
  });

  // Sort by priority: essential first, then recommended, then optional
  recommendations.sort(
    (a, b) => (priorityOrder[a.priority] ?? 1) - (priorityOrder[b.priority] ?? 1),
  );

  return recommendations;
}

// GET /recommendations?record_id=xxx&country=US
affiliate.get("/recommendations", async (c) => {
  const user = await getCurrentUser(c);
  if (!isPro(user)) {
    throw new HTTPException(403, { message: "Upgrade to Pro to access supplement recommendations" });
  }
  const recordId = c.req.query("record_id");
  const country = c.req.query("country") ?? "US";

  if (!recordId) {
    throw new HTTPException(400, { message: "record_id is required" });
  }

  let oid: ObjectId;
  try {
    oid = new ObjectId(recordId);
  } catch {
    throw new HTTPException(400, { message: "Invalid record_id" });
  }

  const db = getDb();
  const record = await db.collection<HealthRecord>("health_records").findOne({
    _id: oid,
    user_id: user._id,
  });

  if (!record) {
    throw new HTTPException(404, { message: "Record not found" });
  }

  const supplementProtocol = record.supplement_protocol ?? [];

  if (!supplementProtocol.length) {
    return c.json({ record_id: recordId, recommendations: [], count: 0 });
  }

  const recommendations = buildRecommendations(supplementProtocol, country);

  return c.json({
    record_id: recordId,
    country,
    count: recommendations.length,
    recommendations,
  });
});

// GET /recommendations/latest?country=US
// Convenience: get recommendations from the user's latest completed record
affiliate.get("/recommendations/latest", async (c) => {
  const user = await getCurrentUser(c);
  if (!isPro(user)) {
    throw new HTTPException(403, { message: "Upgrade to Pro to access supplement recommendations" });
  }
  const country = c.req.query("country") ?? "US";

  const db = getDb();
  const record = await db.collection<HealthRecord>("health_records").findOne(
    {
      user_id: user._id,
      status: "completed",
      supplement_protocol: { $exists: true, $ne: [] },
    },
    { sort: { created_at: -1 } },
  );

  if (!record) {
    return c.json({ record_id: null, recommendations: [], count: 0 });
  }

  const supplementProtocol = record.supplement_protocol ?? [];
  const recommendations = buildRecommendations(supplementProtocol, country);

  return c.json({
    record_id: record._id.toHexString(),
    country,
    count: recommendations.length,
    recommendations,
  });
});

export default affiliate;
