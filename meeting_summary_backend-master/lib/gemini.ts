import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY!,
});

export async function generateSummary(text: string) {
  try {
    console.log("🤖 Sending to Gemini...");

    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: `
        You are an AI assistant.

        1. Fix grammar and spelling of this text and use it for your processing.
        2. Then give summary in bullet points.
        3. Your response format should be like this directly ->
            1. 
            2. 
            3.     
        Text:
        ${text}
        `,
    });

    const result = response.text;

    console.log("📄 Gemini Summary:", result);

    return result || "Summary not available";
  } catch (error) {
    console.error("❌ Gemini Error:", error);
    return "Summary failed";
  }
}