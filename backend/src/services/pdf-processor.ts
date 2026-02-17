import { readFile } from "fs/promises";
import pdfParse from "pdf-parse";

export async function extractTextFromPdf(filePath: string): Promise<string> {
  const dataBuffer = await readFile(filePath);
  const data = await pdfParse(dataBuffer);
  return data.text;
}
