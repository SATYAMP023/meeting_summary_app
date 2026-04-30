import { NextRequest, NextResponse } from "next/server";
import fs from "fs-extra";
import path from "path";
import { generateSummary } from "@/../lib/gemini"; // ✅ NEW IMPORT

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const file = formData.get("file") as File;

    if (!file) {
      return NextResponse.json({ error: "No file" }, { status: 400 });
    }

    // ✅ Convert to buffer
    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);

    // ✅ Save locally
    const uploadDir = path.join(process.cwd(), "uploads");
    await fs.ensureDir(uploadDir);

    const filePath = path.join(uploadDir, file.name);
    await fs.writeFile(filePath, buffer);

    console.log("📁 Saved:", filePath);

    // 🔥 SEND TO FASTAPI (Whisper)
    const pythonForm = new FormData();
    pythonForm.append("file", new Blob([buffer]), file.name);

    const response = await fetch("http://127.0.0.1:8000/transcribe", {
      method: "POST",
      body: pythonForm,
    });

    const data = await response.json();

    console.log("🧠 Transcription:", data.text);

    // 🚨 SAFETY CHECK
    if (!data.text) {
      return NextResponse.json({
        success: false,
        error: "No transcription received",
      });
    }

    // 🔥 CALL GEMINI (NEW CLEAN WAY)
    const summary = await generateSummary(data.text);

    // ✅ FINAL RESPONSE
    return NextResponse.json({
      success: true,
      text: data.text,
      summary,
    });

  } catch (err: any) {
    console.error("❌ Error:", err);

    return NextResponse.json(
      { error: err.message },
      { status: 500 }
    );
  }
}