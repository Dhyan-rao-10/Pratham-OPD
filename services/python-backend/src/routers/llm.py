import os
import re
from pathlib import Path
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import anthropic

from ..db import query

router = APIRouter(prefix="/api/llm", tags=["llm"])

PROMPT_DIR = Path(__file__).parent.parent / "prompts"

class InterviewRequest(BaseModel):
    session_id: str
    patient_message: str
    question_id: Optional[str] = None

class InterviewResponse(BaseModel):
    reply: str
    answer_complete: Optional[str] = None
    triage_flag: Optional[dict] = None

@router.post("/interview", response_model=InterviewResponse)
async def interview(req: InterviewRequest):
    from ..llm_client import has_llm, complete as llm_complete

    if not has_llm():
        # Fallback: echo back for demo without API key
        return InterviewResponse(
            reply="Thank you for sharing. Let me note that down.",
            answer_complete=req.patient_message,
            triage_flag=None,
        )

    # Load session context
    session = query("SELECT * FROM sessions WHERE id = %s", (req.session_id,))
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    session = session[0]

    answers = query(
        "SELECT question_id, answer_raw FROM session_answers WHERE session_id = %s ORDER BY created_at",
        (req.session_id,),
    )
    answers_summary = "; ".join([f"{a['question_id']}: {a['answer_raw']}" for a in answers]) or "None yet"

    # Get current question text
    current_question = "General follow-up"
    if req.question_id:
        q = query("SELECT * FROM questionnaire_nodes WHERE id = %s", (req.question_id,))
        if q:
            lang = session.get("language", "en")
            current_question = q[0].get(f"text_{lang}") or q[0]["text_en"]

    # Build system prompt
    system_template = (PROMPT_DIR / "system_interview.txt").read_text()
    lang_map = {"en": "English", "hi": "Hindi", "te": "Telugu"}
    system_prompt = system_template.format(
        department=session["department"],
        language=lang_map.get(session.get("language", "en"), "English"),
        documents_summary="None uploaded",
        answers_summary=answers_summary,
        current_question=current_question,
        structured_answer="{structured_answer}",
        symptom_description="{symptom_description}",
    )

    try:
        reply_text = llm_complete(system_prompt, req.patient_message, max_tokens=1024)
    except Exception as e:
        print(f"[llm.interview] LLM call failed: {type(e).__name__}: {e}", flush=True)
        return InterviewResponse(
            reply="Thank you for sharing. Let me note that down.",
            answer_complete=req.patient_message,
            triage_flag=None,
        )

    # Parse ANSWER_COMPLETE
    answer_complete = None
    match = re.search(r"ANSWER_COMPLETE:\s*(.+?)(?:\n|$)", reply_text)
    if match:
        answer_complete = match.group(1).strip()
        reply_text = reply_text[: match.start()].strip()

    # Parse TRIAGE_FLAG
    triage_flag = None
    flag_match = re.search(r"TRIAGE_FLAG:\s*(.+?)\s+(RED|AMBER)", reply_text)
    if flag_match:
        triage_flag = {
            "symptom": flag_match.group(1).strip(),
            "level": flag_match.group(2),
        }
        reply_text = reply_text[: flag_match.start()].strip()

    if not reply_text:
        reply_text = "Thank you, I've noted that."

    return InterviewResponse(
        reply=reply_text,
        answer_complete=answer_complete,
        triage_flag=triage_flag,
    )
