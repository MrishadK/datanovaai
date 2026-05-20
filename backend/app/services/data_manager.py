import io
import os
import numpy as np
import pandas as pd
from typing import Dict, List, Any, Optional

class DataState:
    def __init__(self, df: pd.DataFrame, description: str):
        self.df = df.copy()
        self.description = description

class DataManager:
    def __init__(self):
        self.history: List[DataState] = []
        self.current_index: int = -1
        self.filename: str = ""
        self.original_df: Optional[pd.DataFrame] = None

    def load_file(self, filename: str, contents: bytes) -> Dict[str, Any]:
        """Loads CSV, Excel, or JSON data from raw bytes, resets the history stack, and sets original data."""
        self.filename = filename
        ext = os.path.splitext(filename.lower())[1]
        
        # Parse based on extension
        if ext == '.csv':
            # Try different encodings
            for encoding in ['utf-8', 'latin1', 'cp1252', 'utf-16']:
                try:
                    df = pd.read_csv(io.BytesIO(contents), encoding=encoding)
                    break
                except Exception:
                    continue
            else:
                raise ValueError("Could not decode CSV file using standard encodings (utf-8, latin1, cp1252, utf-16).")
        elif ext in ['.xlsx', '.xls']:
            df = pd.read_excel(io.BytesIO(contents))
        elif ext == '.json':
            # Try default or orient='records'
            try:
                df = pd.read_json(io.BytesIO(contents))
            except Exception:
                df = pd.read_json(io.BytesIO(contents), orient='records')
        else:
            raise ValueError(f"Unsupported file format: {ext}. Please import CSV, Excel (.xlsx), or JSON.")

        # Reset history
        self.original_df = df.copy()
        self.history = [DataState(df, "Original Dataset Loaded")]
        self.current_index = 0
        
        return self.get_summary()

    def get_current_df(self) -> pd.DataFrame:
        """Retrieves the active dataframe from the top of the history stack pointer."""
        if self.current_index == -1 or not self.history:
            raise ValueError("No dataset is currently loaded.")
        return self.history[self.current_index].df

    def apply_operation(self, new_df: pd.DataFrame, description: str):
        """Applies a cleaning transformation, clearing any redo history ahead."""
        if self.current_index == -1:
            raise ValueError("Cannot apply operation: No dataset is loaded.")
        
        # Truncate forward history (redo path)
        self.history = self.history[:self.current_index + 1]
        
        # Add new state
        self.history.append(DataState(new_df, description))
        self.current_index += 1

    def undo(self) -> Dict[str, Any]:
        """Steps backward in the history stack."""
        if self.current_index > 0:
            self.current_index -= 1
            return {"success": True, "message": f"Undo: {self.history[self.current_index].description}", "summary": self.get_summary()}
        return {"success": False, "message": "Cannot Undo: Already at the original state."}

    def redo(self) -> Dict[str, Any]:
        """Steps forward in the history stack."""
        if self.current_index < len(self.history) - 1:
            self.current_index += 1
            return {"success": True, "message": f"Redo: {self.history[self.current_index].description}", "summary": self.get_summary()}
        return {"success": False, "message": "Cannot Redo: Already at the latest state."}

    def get_history_log(self) -> List[Dict[str, Any]]:
        """Returns a listing of all operations in the stack with indicator of active index."""
        return [
            {
                "index": i,
                "description": state.description,
                "is_active": i == self.current_index
            } for i, state in enumerate(self.history)
        ]

    def reset_dataset(self) -> Dict[str, Any]:
        """Resets the dataset to its original loaded form."""
        if self.original_df is None:
            raise ValueError("No dataset is loaded.")
        self.apply_operation(self.original_df, "Reset to Original Dataset")
        return self.get_summary()

    def get_column_types(self, df: pd.DataFrame) -> Dict[str, str]:
        """Classifies each column into 'numerical', 'datetime', 'categorical', or 'text'."""
        col_types = {}
        for col in df.columns:
            dtype = df[col].dtype
            
            # Numeric types
            if np.issubdtype(dtype, np.number):
                col_types[col] = 'numerical'
            # Datetime types
            elif np.issubdtype(dtype, np.datetime64) or 'datetime' in str(dtype).lower():
                col_types[col] = 'datetime'
            # Check if strings are parsable dates
            elif dtype == 'object' or str(dtype) == 'string':
                # Quick check if it looks like a datetime
                sample = df[col].dropna().head(10)
                if len(sample) > 0:
                    try:
                        pd.to_datetime(sample, errors='raise')
                        col_types[col] = 'datetime'
                        continue
                    except Exception:
                        pass
                
                # Check uniqueness to separate categorical vs text
                non_null_vals = df[col].dropna()
                if len(non_null_vals) == 0:
                    col_types[col] = 'categorical' # fallback
                else:
                    unique_ratio = len(non_null_vals.unique()) / len(non_null_vals)
                    unique_count = len(non_null_vals.unique())
                    if unique_count < 30 or unique_ratio < 0.1:
                        col_types[col] = 'categorical'
                    else:
                        col_types[col] = 'text'
            elif dtype == 'bool':
                col_types[col] = 'categorical'
            else:
                col_types[col] = 'categorical'
                
        return col_types

    def get_summary(self) -> Dict[str, Any]:
        """Generates overview statistics and paginated preview of the active dataset state."""
        df = self.get_current_df()
        
        rows_count = len(df)
        cols_count = len(df.columns)
        
        # Calculate stats
        missing_count = int(df.isnull().sum().sum())
        missing_by_column = df.isnull().sum().to_dict()
        duplicate_rows_count = int(df.duplicated().sum())
        
        col_types = self.get_column_types(df)
        
        # Quick summary stats per column
        column_details = []
        for col in df.columns:
            non_null_count = int(df[col].notnull().sum())
            null_count = int(df[col].isnull().sum())
            null_pct = float(null_count / rows_count * 100) if rows_count > 0 else 0
            unique_count = int(df[col].nunique())
            
            detail = {
                "name": col,
                "type": col_types[col],
                "native_dtype": str(df[col].dtype),
                "non_null_count": non_null_count,
                "null_count": null_count,
                "null_percentage": round(null_pct, 2),
                "unique_count": unique_count,
            }
            
            # Add specific numerical/categorical descriptions
            if col_types[col] == 'numerical':
                col_non_null = df[col].dropna()
                if len(col_non_null) > 0:
                    detail["stats"] = {
                        "mean": float(col_non_null.mean()) if not pd.isna(col_non_null.mean()) else None,
                        "min": float(col_non_null.min()) if not pd.isna(col_non_null.min()) else None,
                        "max": float(col_non_null.max()) if not pd.isna(col_non_null.max()) else None,
                        "std": float(col_non_null.std()) if not pd.isna(col_non_null.std()) else None,
                        "median": float(col_non_null.median()) if not pd.isna(col_non_null.median()) else None
                    }
            elif col_types[col] == 'categorical':
                val_counts = df[col].value_counts().head(5).to_dict()
                # Stringify keys for JSON serialization safety
                detail["stats"] = {
                    "top_values": {str(k): int(v) for k, v in val_counts.items()}
                }
            column_details.append(detail)

        # Build JSON-safe preview slice (first 100 rows)
        preview_df = df.head(100).copy()
        
        # Standardize NaNs and infinities to None so standard json parses it perfectly
        preview_df = preview_df.replace({np.nan: None, np.inf: None, -np.inf: None})
        
        # Convert all timestamps/datetimes to string representations
        for col in preview_df.columns:
            if col_types[col] == 'datetime':
                preview_df[col] = preview_df[col].apply(lambda x: str(x) if x is not None else None)
        
        preview_rows = preview_df.to_dict(orient='records')
        
        return {
            "filename": self.filename,
            "rows_count": rows_count,
            "columns_count": cols_count,
            "missing_values_count": missing_count,
            "duplicate_rows_count": duplicate_rows_count,
            "duplicate_percentage": round((duplicate_rows_count / rows_count * 100), 2) if rows_count > 0 else 0,
            "column_types": col_types,
            "columns": column_details,
            "preview_data": preview_rows,
            "history": self.get_history_log()
        }

# Global Data Manager instance
data_manager = DataManager()
