import io
import os
import pickle
import pandas as pd
from fastapi import APIRouter, UploadFile, File, Header, HTTPException, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from fpdf import FPDF

# Import our backend services
from app.services.data_manager import data_manager
from app.services.clean_service import CleanService
from app.services.ml_service import MLService, active_pipelines_cache
from app.services.ai_service import AIService

router = APIRouter()

# --- Request Schemas ---

class ImputeRequest(BaseModel):
    column: str
    method: str  # mean, median, mode, ffill, bfill

class OutliersRequest(BaseModel):
    column: str
    method: str  # iqr, zscore, isoforest
    action: str  # detect, drop, cap
    threshold: Optional[float] = 3.0

class EncodeRequest(BaseModel):
    columns: List[str]
    method: str  # onehot, label

class ScaleRequest(BaseModel):
    columns: List[str]
    method: str  # normalize, standardize

class DatetimeRequest(BaseModel):
    column: str

class VectorizeRequest(BaseModel):
    column: str
    max_features: Optional[int] = 50

class TrainMLRequest(BaseModel):
    target_column: str
    feature_columns: Optional[List[str]] = None
    test_size: Optional[float] = 0.2

class ChatMessage(BaseModel):
    role: str  # user, assistant
    content: str

class ChatRequest(BaseModel):
    query: str
    history: List[ChatMessage]


# --- Helper response formatter ---
def ok_response(data: Dict[str, Any], message: str = "Success"):
    return {
        "success": True,
        "message": message,
        "data": data
    }


# --- Endpoints ---

@router.post("/import")
async def import_dataset(file: UploadFile = File(...)):
    """Uploads and loads a dataset into memory, resetting history."""
    try:
        contents = await file.read()
        summary = data_manager.load_file(file.filename, contents)
        return ok_response(summary, f"Dataset '{file.filename}' imported successfully.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to import dataset: {str(e)}")

@router.get("/preview")
async def get_preview():
    """Retrieves current preview, column info, and statistics."""
    try:
        summary = data_manager.get_summary()
        return ok_response(summary, "Active dataset preview retrieved.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/clean/missing")
async def impute_missing_values(req: ImputeRequest):
    """Imputes missing values for a column and saves state to history."""
    try:
        df = data_manager.get_current_df()
        new_df = CleanService.impute_missing(df, req.column, req.method)
        data_manager.apply_operation(new_df, f"Impute missing in '{req.column}' with '{req.method}'")
        return ok_response(data_manager.get_summary(), f"Imputed missing in '{req.column}' using '{req.method}'.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/clean/duplicates")
async def remove_duplicate_rows():
    """Drops duplicate rows from active dataframe."""
    try:
        df = data_manager.get_current_df()
        duplicates_count = df.duplicated().sum()
        if duplicates_count == 0:
            return ok_response(data_manager.get_summary(), "No duplicate rows detected in the dataset.")
            
        new_df = CleanService.remove_duplicates(df)
        data_manager.apply_operation(new_df, f"Remove {duplicates_count} Duplicate Rows")
        return ok_response(data_manager.get_summary(), f"Removed {duplicates_count} duplicate rows successfully.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/clean/outliers")
async def handle_dataset_outliers(req: OutliersRequest):
    """Detects, drops, or caps outliers in a column."""
    try:
        df = data_manager.get_current_df()
        
        if req.action == 'detect':
            results = CleanService.detect_outliers(df, req.column, req.method, req.threshold)
            return ok_response(results, f"Outliers detected in '{req.column}' using '{req.method}'.")
            
        # Action is 'drop' or 'cap'
        new_df = CleanService.handle_outliers(df, req.column, req.method, req.action, req.threshold)
        
        # Calculate number of affected outliers
        old_results = CleanService.detect_outliers(df, req.column, req.method, req.threshold)
        count = old_results.get("outlier_count", 0)
        
        data_manager.apply_operation(new_df, f"{req.action.capitalize()} {count} outliers in '{req.column}' using '{req.method}'")
        return ok_response(data_manager.get_summary(), f"Successfully applied '{req.action}' to {count} outliers in '{req.column}'.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/preprocess/encode")
async def encode_categorical_columns(req: EncodeRequest):
    """Applies One-Hot or Label Encoding to specified columns."""
    try:
        df = data_manager.get_current_df()
        
        if req.method == 'onehot':
            new_df = CleanService.one_hot_encode(df, req.columns)
            desc = f"One-Hot Encode columns: {', '.join(req.columns)}"
        elif req.method == 'label':
            new_df = CleanService.label_encode(df, req.columns)
            desc = f"Label Encode columns: {', '.join(req.columns)}"
        else:
            raise ValueError(f"Unsupported encoding method: '{req.method}'")
            
        data_manager.apply_operation(new_df, desc)
        return ok_response(data_manager.get_summary(), f"Encoding successfully applied.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/preprocess/scale")
async def scale_numerical_columns(req: ScaleRequest):
    """Applies Standardization or Normalization to specified columns."""
    try:
        df = data_manager.get_current_df()
        new_df = CleanService.scale_numerical(df, req.columns, req.method)
        
        desc = f"{req.method.capitalize()} columns: {', '.join(req.columns)}"
        data_manager.apply_operation(new_df, desc)
        return ok_response(data_manager.get_summary(), f"Scaling successfully applied.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/preprocess/datetime")
async def extract_datetime(req: DatetimeRequest):
    """Parses datetime components out of a selected column."""
    try:
        df = data_manager.get_current_df()
        new_df = CleanService.extract_datetime_features(df, req.column)
        
        data_manager.apply_operation(new_df, f"Extract datetime features from '{req.column}'")
        return ok_response(data_manager.get_summary(), f"Successfully extracted sub-features from date column '{req.column}'.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/preprocess/vectorize")
async def vectorize_text(req: VectorizeRequest):
    """Transforms raw string comments/text into TF-IDF vector columns."""
    try:
        df = data_manager.get_current_df()
        new_df = CleanService.text_vectorize(df, req.column, req.max_features)
        
        data_manager.apply_operation(new_df, f"TF-IDF Vectorize '{req.column}' (max features={req.max_features})")
        return ok_response(data_manager.get_summary(), f"Vectorized text column '{req.column}' into numeric frequency representations.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/undo")
async def undo_operation():
    """Reverts dataset to previous state on stack."""
    try:
        res = data_manager.undo()
        if res["success"]:
            return ok_response(res["summary"], res["message"])
        else:
            raise HTTPException(status_code=400, detail=res["message"])
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/redo")
async def redo_operation():
    """Fast-forwards dataset state on stack."""
    try:
        res = data_manager.redo()
        if res["success"]:
            return ok_response(res["summary"], res["message"])
        else:
            raise HTTPException(status_code=400, detail=res["message"])
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/reset")
async def reset_dataset():
    """Resets dataset to original file."""
    try:
        summary = data_manager.reset_dataset()
        return ok_response(summary, "Dataset successfully reset to original state.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# --- AutoML Endpoints ---

@router.post("/automl/train")
async def train_automl_models(req: TrainMLRequest):
    """Launches parallel AutoML model training, evaluates results, and caches models."""
    try:
        df = data_manager.get_current_df()
        results = MLService.train_automl(df, req.target_column, req.feature_columns, req.test_size)
        
        # Cache trained pipelines on backend using target column index to identify
        session_pipelines = results.pop("_pipelines") # Extract and hide private pipeline dictionary from json response
        active_pipelines_cache["latest"] = session_pipelines
        
        return ok_response(results, "AutoML model training completed successfully.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"AutoML Training failed: {str(e)}")

@router.get("/automl/export")
async def export_trained_model(model_name: str = Query(...)):
    """Downloads the trained scikit-learn/XGBoost pipeline object as a binary .pkl file."""
    latest = active_pipelines_cache.get("latest")
    if not latest or model_name not in latest:
        raise HTTPException(status_code=404, detail=f"No trained pipeline found for model: {model_name}. Please train AutoML first.")
        
    try:
        pipeline_data = latest[model_name]
        
        # Serialize pipeline to bytes
        buffer = io.BytesIO()
        pickle.dump(pipeline_data, buffer)
        buffer.seek(0)
        
        safe_name = model_name.replace(" ", "_").lower()
        return StreamingResponse(
            buffer,
            media_type="application/octet-stream",
            headers={"Content-Disposition": f"attachment; filename=datanova_model_{safe_name}.pkl"}
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Exporting model failed: {str(e)}")


# --- AI Assistant Endpoints ---

@router.get("/ai/recommend")
async def get_ai_recommendations(
    x_gemini_key: Optional[str] = Header(None, alias="X-Gemini-Key"),
    x_openai_key: Optional[str] = Header(None, alias="X-OpenAI-Key")
):
    """Retrieves AI recommendations utilizing API keys provided in request headers."""
    try:
        summary = data_manager.get_summary()
        recommendations = AIService.get_cleaning_recommendations(summary, x_gemini_key, x_openai_key)
        return ok_response(recommendations, "AI Recommendations generated successfully.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to generate recommendations: {str(e)}")

@router.post("/ai/chat")
async def chat_with_dataset(
    req: ChatRequest,
    x_gemini_key: Optional[str] = Header(None, alias="X-Gemini-Key"),
    x_openai_key: Optional[str] = Header(None, alias="X-OpenAI-Key")
):
    """Converses with chatbot, seeded with current dataset context."""
    try:
        summary = data_manager.get_summary()
        history_dicts = [{"role": msg.role, "content": msg.content} for msg in req.history]
        
        response = AIService.chat_assistant(req.query, history_dicts, summary, x_gemini_key, x_openai_key)
        return ok_response({"response": response}, "Chat response generated.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Chat error: {str(e)}")


# --- Export Endpoints ---

@router.get("/export/dataset")
async def export_cleaned_dataset(format: str = Query("csv")):
    """Downloads the full, currently cleaned dataset in CSV, Excel, or JSON formats."""
    try:
        df = data_manager.get_current_df()
        buffer = io.BytesIO()
        
        filename = os.path.splitext(data_manager.filename)[0]
        
        if format == 'csv':
            df.to_csv(buffer, index=False)
            media_type = "text/csv"
            ext = ".csv"
        elif format == 'excel':
            with pd.ExcelWriter(buffer, engine='openpyxl') as writer:
                df.to_excel(writer, index=False)
            media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            ext = ".xlsx"
        elif format == 'json':
            df.to_json(buffer, orient='records', indent=2)
            media_type = "application/json"
            ext = ".json"
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported export format: {format}")
            
        buffer.seek(0)
        return StreamingResponse(
            buffer,
            media_type=media_type,
            headers={"Content-Disposition": f"attachment; filename={filename}_cleaned{ext}"}
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to export dataset: {str(e)}")


@router.get("/export/report")
async def generate_pdf_report():
    """Generates a gorgeous PDF data quality and AutoML evaluation report."""
    try:
        summary = data_manager.get_summary()
        
        pdf = FPDF()
        pdf.add_page()
        
        # Color Palette
        primary = (79, 70, 229)    # Indigo
        secondary = (16, 185, 129) # Emerald
        dark = (31, 41, 55)        # Slate Grey
        light = (243, 244, 246)    # Light Grey
        
        # Title Page / Header
        pdf.set_fill_color(*primary)
        pdf.rect(0, 0, 210, 40, 'F')
        
        pdf.set_text_color(255, 255, 255)
        pdf.set_font("Helvetica", style="B", size=22)
        pdf.cell(0, 15, "DATANOVA AI REPORT", ln=True, align="C")
        pdf.set_font("Helvetica", size=10)
        pdf.cell(0, 5, "Next-Generation Automated Data Preparation & Preprocessing Report", ln=True, align="C")
        pdf.ln(15)
        
        # Section 1: Overview
        pdf.set_text_color(*dark)
        pdf.set_font("Helvetica", style="B", size=14)
        pdf.cell(0, 10, "1. Dataset Summary Overview", ln=True)
        pdf.set_draw_color(*primary)
        pdf.line(10, pdf.get_y(), 200, pdf.get_y())
        pdf.ln(5)
        
        # Statistics Table
        pdf.set_font("Helvetica", size=10)
        stats = [
            ("Dataset Name", summary.get("filename")),
            ("Total Rows Count", str(summary.get("rows_count"))),
            ("Total Columns Count", str(summary.get("columns_count"))),
            ("Total Missing Cells", str(summary.get("missing_values_count"))),
            ("Total Duplicate Rows", f"{summary.get('duplicate_rows_count')} ({summary.get('duplicate_percentage')}%)"),
        ]
        
        for label, val in stats:
            pdf.set_font("Helvetica", style="B")
            pdf.cell(60, 8, label, border=1)
            pdf.set_font("Helvetica")
            pdf.cell(130, 8, val, border=1, ln=True)
            
        pdf.ln(10)
        
        # Section 2: Columns Breakdown
        pdf.set_font("Helvetica", style="B", size=14)
        pdf.cell(0, 10, "2. Schema breakdown & Data Quality", ln=True)
        pdf.line(10, pdf.get_y(), 200, pdf.get_y())
        pdf.ln(5)
        
        # Columns Table Header
        pdf.set_fill_color(*light)
        pdf.set_font("Helvetica", style="B", size=9)
        pdf.cell(50, 7, "Column Name", border=1, fill=True)
        pdf.cell(35, 7, "Identified Type", border=1, fill=True)
        pdf.cell(35, 7, "Native Dtype", border=1, fill=True)
        pdf.cell(35, 7, "Missing Count", border=1, fill=True)
        pdf.cell(35, 7, "Missing %", border=1, fill=True, ln=True)
        
        pdf.set_font("Helvetica", size=9)
        for col in summary.get("columns", []):
            pdf.cell(50, 7, col["name"][:25], border=1)
            pdf.cell(35, 7, col["type"].upper(), border=1)
            pdf.cell(35, 7, col["native_dtype"], border=1)
            pdf.cell(35, 7, str(col["null_count"]), border=1)
            pdf.cell(35, 7, f"{col['null_percentage']}%", border=1, ln=True)

        pdf.ln(10)
        
        # Section 3: Preprocessing Log
        pdf.set_font("Helvetica", style="B", size=14)
        pdf.cell(0, 10, "3. Data Cleaning Transformation Log", ln=True)
        pdf.line(10, pdf.get_y(), 200, pdf.get_y())
        pdf.ln(5)
        
        pdf.set_font("Helvetica", size=10)
        history = summary.get("history", [])
        if len(history) <= 1:
            pdf.cell(0, 8, "No active cleaning modifications were made during this session.", ln=True, style="I")
        else:
            for step in history:
                active_str = " (Active State)" if step["is_active"] else ""
                pdf.cell(0, 7, f"Step {step['index']}: {step['description']}{active_str}", ln=True)
                
        # Output PDF to stream
        buffer = io.BytesIO()
        # fpdf2 requires writing bytes to buffer
        pdf_bytes = pdf.output()
        buffer.write(pdf_bytes)
        buffer.seek(0)
        
        filename = os.path.splitext(data_manager.filename)[0]
        return StreamingResponse(
            buffer,
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename=datanova_report_{filename}.pdf"}
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to generate PDF Report: {str(e)}")
