from fastapi import APIRouter, UploadFile, File

router = APIRouter(prefix="/api/ocr", tags=["ocr"])

@router.post("/process")
async def process_document(file: UploadFile = File(...)):
    # TODO: Implement real OCR with Tesseract / Google Doc AI
    return {
        "raw_text": "Sample prescription: Warfarin 5mg OD, Metoprolol 25mg BD, Enalapril 5mg OD",
        "structured": {
            "medications": [
                {"name": "Warfarin", "dose": "5mg", "frequency": "OD"},
                {"name": "Metoprolol", "dose": "25mg", "frequency": "BD"},
                {"name": "Enalapril", "dose": "5mg", "frequency": "OD"},
            ],
            "doc_type": "prescription",
        },
        "confidence": 0.85,
    }
