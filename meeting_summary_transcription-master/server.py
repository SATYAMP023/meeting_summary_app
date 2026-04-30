import os

BASE_CACHE = r"E:\CSE\NLP Project\hf_cache"

os.environ["HF_HOME"] = BASE_CACHE
os.environ["HUGGINGFACE_HUB_CACHE"] = BASE_CACHE
os.environ["TRANSFORMERS_CACHE"] = BASE_CACHE
os.environ["HF_HUB_ENABLE_HF_TRANSFER"] = "1"


from fastapi import FastAPI, UploadFile, File
from faster_whisper import WhisperModel
import shutil
import time

app = FastAPI()

model = None

from huggingface_hub import login
login("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")

from huggingface_hub import whoami
print(whoami())

# 🚀 LOAD MODEL ON STARTUP
@app.on_event("startup")
def load_model():
    global model
    print("🚀 Loading Whisper model...")
    model = WhisperModel(
        "medium",
        device="cpu",
        compute_type="int8"
    )
    print("✅ Whisper model ready")


@app.get("/")
def home():
    return {"status": "Whisper API running"}


@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    start_time = time.time()

    try:
        print("\n================= NEW REQUEST =================")

        # 📁 FILE INFO
        print(f"📁 Filename: {file.filename}")
        print(f"📄 Content Type: {file.content_type}")

        # 💾 SAVE FILE
        file_path = f"temp_{int(time.time())}.wav"

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        file_size = os.path.getsize(file_path)
        print(f"📏 File Size: {file_size / 1024:.2f} KB")
        print(f"⏱️ File saved at: {file_path}")

        print("🚀 Starting transcription...")

        # 🔥 STEP 1: AUTO DETECTION
        segments, info = model.transcribe(
            file_path,
            beam_size=1,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500)
        )

        print(f"🎧 Detected Language: {info.language} (confidence: {info.language_probability:.2f})")

        # 🔥 STEP 2: FALLBACK TO HINDI IF LOW CONFIDENCE
        if info.language_probability < 0.6:
            print("⚠️ Low confidence detected, retrying with Hindi...")
            segments, info = model.transcribe(
                file_path,
                language="hi"
            )
            print(f"🔁 Forced Language: {info.language}")

        # 🧠 BUILD TEXT
        print("\n--- SEGMENTS ---")
        texts = []
        for i, segment in enumerate(segments):
            print(f"[{i}] {segment.start:.2f}s → {segment.end:.2f}s : {segment.text}")
            texts.append(segment.text)

        final_text = " ".join(texts).strip()

        # 🛑 HANDLE EMPTY AUDIO
        if not final_text:
            final_text = "No speech detected"

        print("\n🧠 FINAL TRANSCRIPTION:")
        print(final_text)

        # 🗑️ CLEANUP
        if os.path.exists(file_path):
            os.remove(file_path)
            print("🗑️ Temp file deleted")

        # ⏱️ TIME
        total_time = time.time() - start_time
        print(f"⏱️ Total Processing Time: {total_time:.2f} sec")
        print("=============================================\n")

        return {
            "success": True,
            "text": final_text,
            "language": info.language
        }

    except Exception as e:
        print("\n❌ ERROR OCCURRED")
        print(str(e))
        print("=============================================\n")

        return {
            "success": False,
            "error": str(e)
        }


# ▶️ RUN:
# uvicorn server:app --host 0.0.0.0 --port 8000