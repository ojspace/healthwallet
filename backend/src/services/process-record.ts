import { ObjectId } from "mongodb";
import { getDb } from "../db.js";
import { RecordStatus, calculateWellnessScore, calculateHealthAge } from "../models/health-record.js";
import type { HealthRecord } from "../models/health-record.js";
import { extractTextFromPdf } from "./pdf-processor.js";
import { parseLabResults, detectCorrelations, getSupplementProtocol } from "./lab-parser.js";
import { encryptData } from "./encryption.js";

export async function processRecordAsync(
  recordId: string,
  dietaryPreference: string = "omnivore",
  userAge: number | null = null
): Promise<void> {
  const db = getDb();
  const collection = db.collection<HealthRecord>("health_records");

  const record = await collection.findOne({ _id: new ObjectId(recordId) });
  if (!record) {
    throw new Error(`Record ${recordId} not found`);
  }

  try {
    // Update status to processing
    await collection.updateOne(
      { _id: record._id },
      { $set: { status: RecordStatus.PROCESSING, updated_at: new Date() } }
    );

    // Step 1: Extract text from PDF
    const rawText = await extractTextFromPdf(record.file_url);

    if (!rawText || rawText.trim().length < 50) {
      await collection.updateOne(
        { _id: record._id },
        { $set: { status: RecordStatus.FAILED, error_message: "Could not extract text from PDF", updated_at: new Date() } }
      );
      return;
    }

    // Step 2: Encrypt raw text
    const encryptedText = await encryptData(rawText);

    // Step 3: Parse with AI
    const parsedReports = await parseLabResults(rawText, dietaryPreference, true);

    if (!parsedReports.length) {
      await collection.updateOne(
        { _id: record._id },
        { $set: { status: RecordStatus.FAILED, error_message: "AI returned no data", raw_text_encrypted: encryptedText, updated_at: new Date() } }
      );
      return;
    }

    const firstReport = parsedReports[0];
    if (firstReport.parse_error) {
      await collection.updateOne(
        { _id: record._id },
        { $set: { status: RecordStatus.FAILED, error_message: `AI parsing failed: ${firstReport.parse_error}`, raw_text_encrypted: encryptedText, updated_at: new Date() } }
      );
      return;
    }

    // Step 4: Process reports (split if multiple)
    for (let index = 0; index < parsedReports.length; index++) {
      const reportData = parsedReports[index];
      let targetId: ObjectId;

      if (index === 0) {
        targetId = record._id;
      } else {
        // Create new record for subsequent splits
        let newFilename = record.original_filename;
        const dateStr = reportData.record_date;
        if (dateStr) {
          newFilename = `${newFilename} (${dateStr})`;
        } else {
          newFilename = `${newFilename} (Part ${index + 1})`;
        }

        const insertResult = await collection.insertOne({
          _id: new ObjectId(),
          user_id: record.user_id,
          file_url: record.file_url,
          original_filename: newFilename,
          status: RecordStatus.PROCESSING,
          raw_text_encrypted: encryptedText,
          record_date: null,
          lab_provider: null,
          record_type: "blood_panel",
          parsed_data: null,
          biomarkers: [],
          summary: null,
          correlations: [],
          key_findings: [],
          recommendations: [],
          food_recommendations: [],
          supplement_protocol: [],
          wellness_score: null,
          health_age: null,
          error_message: null,
          created_at: new Date(),
          updated_at: new Date(),
        });
        targetId = insertResult.insertedId;
      }

      // Rule-based correlation merge
      const aiCorrelations = reportData.correlations ?? [];
      const ruleCorrelations = detectCorrelations(reportData.biomarkers ?? []);
      const existingConditions = new Set(aiCorrelations.map((c: any) => c.condition).filter(Boolean));
      for (const corr of ruleCorrelations) {
        if (corr.condition && !existingConditions.has(corr.condition)) {
          aiCorrelations.push(corr);
        }
      }

      // Supplement protocol fallback
      let supplementProtocol = reportData.supplement_protocol ?? [];
      if (!supplementProtocol.length) {
        supplementProtocol = getSupplementProtocol(reportData.biomarkers ?? []);
      }

      const biomarkers = reportData.biomarkers ?? [];
      const wellnessScore = calculateWellnessScore(biomarkers);
      const healthAge = userAge != null ? calculateHealthAge(biomarkers, userAge) : null;

      // Parse record date
      let recordDate: Date | null = null;
      if (reportData.record_date) {
        try {
          recordDate = new Date(reportData.record_date);
          if (isNaN(recordDate.getTime())) recordDate = null;
        } catch {
          recordDate = null;
        }
      }

      const finalStatus = biomarkers.length > 0 ? RecordStatus.PENDING_REVIEW : RecordStatus.FAILED;
      const errorMessage = biomarkers.length === 0 ? "No biomarkers found" : null;

      await collection.updateOne(
        { _id: targetId },
        {
          $set: {
            biomarkers,
            summary: reportData.summary ?? null,
            correlations: aiCorrelations,
            key_findings: reportData.key_findings ?? [],
            recommendations: reportData.recommendations ?? [],
            food_recommendations: reportData.food_recommendations ?? [],
            supplement_protocol: supplementProtocol,
            record_date: recordDate,
            lab_provider: reportData.lab_provider ?? null,
            parsed_data: reportData,
            wellness_score: wellnessScore,
            health_age: healthAge,
            raw_text_encrypted: encryptedText,
            status: finalStatus,
            error_message: errorMessage,
            updated_at: new Date(),
          },
        }
      );
    }
  } catch (e: any) {
    await collection.updateOne(
      { _id: record._id },
      { $set: { status: RecordStatus.FAILED, error_message: String(e), updated_at: new Date() } }
    );
    throw e;
  }
}
