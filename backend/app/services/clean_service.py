import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler, MinMaxScaler, LabelEncoder
from sklearn.feature_extraction.text import TfidfVectorizer
from typing import Dict, List, Any, Tuple, Optional

class CleanService:
    @staticmethod
    def impute_missing(df: pd.DataFrame, column: str, method: str) -> pd.DataFrame:
        """Imputes missing values in a column using the specified method."""
        df_new = df.copy()
        
        if column not in df_new.columns:
            raise ValueError(f"Column '{column}' not found in dataset.")
            
        if method == 'mean':
            if not np.issubdtype(df_new[column].dtype, np.number):
                raise ValueError("Mean replacement can only be applied to numerical columns.")
            val = df_new[column].mean()
            df_new[column] = df_new[column].fillna(val)
        elif method == 'median':
            if not np.issubdtype(df_new[column].dtype, np.number):
                raise ValueError("Median replacement can only be applied to numerical columns.")
            val = df_new[column].median()
            df_new[column] = df_new[column].fillna(val)
        elif method == 'mode':
            mode_series = df_new[column].mode()
            if len(mode_series) > 0:
                val = mode_series[0]
                df_new[column] = df_new[column].fillna(val)
            else:
                raise ValueError(f"Could not compute mode for column '{column}' as it is entirely empty.")
        elif method == 'ffill':
            df_new[column] = df_new[column].ffill()
        elif method == 'bfill':
            df_new[column] = df_new[column].bfill()
        else:
            raise ValueError(f"Unsupported imputation method: '{method}'")
            
        return df_new

    @staticmethod
    def remove_duplicates(df: pd.DataFrame) -> pd.DataFrame:
        """Removes duplicate rows from the dataset."""
        return df.drop_duplicates().reset_index(drop=True)

    @staticmethod
    def detect_outliers(df: pd.DataFrame, column: str, method: str, threshold: float = 3.0) -> Dict[str, Any]:
        """Detects outliers in a column using IQR, Z-Score, or Isolation Forest."""
        if column not in df.columns:
            raise ValueError(f"Column '{column}' not found in dataset.")
            
        col_data = df[column].dropna()
        if len(col_data) == 0:
            return {"outlier_indices": [], "outlier_count": 0, "outlier_percentage": 0}
            
        if not np.issubdtype(df[column].dtype, np.number):
            raise ValueError("Outlier detection can only be applied to numerical columns.")

        outlier_mask = pd.Series(False, index=df.index)

        if method == 'iqr':
            q1 = col_data.quantile(0.25)
            q3 = col_data.quantile(0.75)
            iqr = q3 - q1
            lower_bound = q1 - 1.5 * iqr
            upper_bound = q3 + 1.5 * iqr
            outlier_mask = (df[column] < lower_bound) | (df[column] > upper_bound)
            bounds = {"lower": float(lower_bound), "upper": float(upper_bound)}
        elif method == 'zscore':
            mean = col_data.mean()
            std = col_data.std()
            if std == 0:
                bounds = {"lower": float(mean), "upper": float(mean)}
            else:
                z_scores = (df[column] - mean) / std
                outlier_mask = z_scores.abs() > threshold
                bounds = {"lower": float(mean - threshold * std), "upper": float(mean + threshold * std)}
        elif method == 'isoforest':
            # Isolation Forest runs on the single column (reshaped)
            # Impute temporarily for IsoForest compatibility
            filled_col = df[[column]].fillna(col_data.median())
            iso = IsolationForest(contamination='auto', random_state=42)
            preds = iso.fit_predict(filled_col)
            outlier_mask = pd.Series(preds == -1, index=df.index)
            bounds = None
        else:
            raise ValueError(f"Unsupported outlier detection method: '{method}'")

        # Get the actual outlier rows
        outlier_indices = df.index[outlier_mask].tolist()
        outlier_count = len(outlier_indices)
        outlier_pct = float(outlier_count / len(df) * 100) if len(df) > 0 else 0

        return {
            "method": method,
            "column": column,
            "outlier_indices": outlier_indices,
            "outlier_count": outlier_count,
            "outlier_percentage": round(outlier_pct, 2),
            "bounds": bounds
        }

    @staticmethod
    def handle_outliers(df: pd.DataFrame, column: str, method: str, action: str, threshold: float = 3.0) -> pd.DataFrame:
        """Removes or caps outliers in a column based on IQR or Z-score boundaries."""
        df_new = df.copy()
        
        # Detect bounds
        results = CleanService.detect_outliers(df, column, method, threshold)
        bounds = results.get("bounds")
        outlier_indices = results.get("outlier_indices", [])
        
        if not bounds:
            # For Isolation Forest or where bounds are none, we can only drop
            if action == 'drop':
                df_new = df_new.drop(index=outlier_indices).reset_index(drop=True)
            else:
                raise ValueError("Isolation Forest outliers can only be dropped, not capped.")
            return df_new

        lower = bounds["lower"]
        upper = bounds["upper"]

        if action == 'drop':
            df_new = df_new.drop(index=outlier_indices).reset_index(drop=True)
        elif action == 'cap':
            df_new[column] = df_new[column].clip(lower=lower, upper=upper)
        else:
            raise ValueError(f"Unsupported outlier handling action: '{action}'")

        return df_new

    @staticmethod
    def one_hot_encode(df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
        """Applies one-hot encoding to specified categorical columns."""
        df_new = df.copy()
        for col in columns:
            if col not in df_new.columns:
                raise ValueError(f"Column '{col}' not found.")
        # Perform get_dummies
        df_new = pd.get_dummies(df_new, columns=columns, prefix=columns, drop_first=False)
        # Convert true/false columns to 1/0 integers for machine learning compat
        for col in df_new.columns:
            if df_new[col].dtype == 'bool':
                df_new[col] = df_new[col].astype(int)
        return df_new

    @staticmethod
    def label_encode(df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
        """Applies label encoding to specified columns."""
        df_new = df.copy()
        for col in columns:
            if col not in df_new.columns:
                raise ValueError(f"Column '{col}' not found.")
            le = LabelEncoder()
            # Handle nulls by treating them as a string category temporarily, or filling
            non_null = df_new[col].dropna()
            encoded_vals = le.fit_transform(non_null.astype(str))
            
            # Map back, leaving nulls intact or putting them in their own category
            df_new.loc[df_new[col].notnull(), col] = encoded_vals
            # Fill remaining NaN values with a default category code (-1 or new class)
            df_new[col] = df_new[col].fillna(-1).astype(int)
        return df_new

    @staticmethod
    def scale_numerical(df: pd.DataFrame, columns: List[str], method: str) -> pd.DataFrame:
        """Scales numerical columns using normalization (MinMax) or standardization (StandardScaler)."""
        df_new = df.copy()
        
        for col in columns:
            if col not in df_new.columns:
                raise ValueError(f"Column '{col}' not found.")
            if not np.issubdtype(df_new[col].dtype, np.number):
                raise ValueError(f"Scaling column '{col}' failed: Column is not numerical.")

        # Fill missing values temporarily for scaling
        for col in columns:
            if df_new[col].isnull().any():
                df_new[col] = df_new[col].fillna(df_new[col].median())

        if method == 'normalize':
            scaler = MinMaxScaler()
            df_new[columns] = scaler.fit_transform(df_new[columns])
        elif method == 'standardize':
            scaler = StandardScaler()
            df_new[columns] = scaler.fit_transform(df_new[columns])
        else:
            raise ValueError(f"Unsupported scaling method: '{method}'")
            
        return df_new

    @staticmethod
    def extract_datetime_features(df: pd.DataFrame, column: str) -> pd.DataFrame:
        """Extracts date/time sub-features (year, month, day, dayofweek, etc.) from a column."""
        df_new = df.copy()
        if column not in df_new.columns:
            raise ValueError(f"Column '{column}' not found.")
            
        try:
            # Parse to datetime
            dt_col = pd.to_datetime(df_new[column], errors='coerce')
            
            # If all are NaT, then parsing failed
            if dt_col.isnull().all():
                raise ValueError("Column cannot be parsed into date/time features.")
                
            # Create features
            df_new[f"{column}_year"] = dt_col.dt.year
            df_new[f"{column}_month"] = dt_col.dt.month
            df_new[f"{column}_day"] = dt_col.dt.day
            df_new[f"{column}_dayofweek"] = dt_col.dt.dayofweek
            
            # Fill missing parts of newly created columns with median values
            for suffix in ["_year", "_month", "_day", "_dayofweek"]:
                new_col = f"{column}{suffix}"
                df_new[new_col] = df_new[new_col].fillna(df_new[new_col].median()).astype(int)
                
            # Optionally drop the original datetime string column
            df_new = df_new.drop(columns=[column])
        except Exception as e:
            raise ValueError(f"Failed to parse datetime features for '{column}': {str(e)}")
            
        return df_new

    @staticmethod
    def text_vectorize(df: pd.DataFrame, column: str, max_features: int = 50) -> pd.DataFrame:
        """Applies TF-IDF vectorization to a text column, generating dynamic feature columns."""
        df_new = df.copy()
        if column not in df_new.columns:
            raise ValueError(f"Column '{column}' not found.")
            
        # Impute missing text with empty string
        filled_text = df_new[column].fillna("").astype(str)
        
        tfidf = TfidfVectorizer(max_features=max_features, stop_words='english')
        tfidf_matrix = tfidf.fit_transform(filled_text)
        
        # Turn matrix into DataFrame
        feature_names = [f"{column}_tfidf_{name}" for name in tfidf.get_feature_names_out()]
        tfidf_df = pd.DataFrame(tfidf_matrix.toarray(), columns=feature_names, index=df_new.index)
        
        # Join new columns and drop the original text column
        df_new = pd.concat([df_new, tfidf_df], axis=1)
        df_new = df_new.drop(columns=[column])
        
        return df_new
