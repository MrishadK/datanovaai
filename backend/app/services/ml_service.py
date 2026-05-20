import time
import pickle
import numpy as np
import pandas as pd
from typing import Dict, List, Any, Tuple, Optional

# SciKit-Learn utilities
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.impute import SimpleImputer
from sklearn.metrics import (
    accuracy_score, precision_recall_fscore_support, confusion_matrix,
    r2_score, mean_squared_error, mean_absolute_error
)

# ML Models
from sklearn.linear_model import LogisticRegression, LinearRegression
from sklearn.tree import DecisionTreeClassifier, DecisionTreeRegressor
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from xgboost import XGBClassifier, XGBRegressor

class MLService:
    @staticmethod
    def detect_task_type(df: pd.DataFrame, target_column: str) -> str:
        """Determines whether the task is 'classification' or 'regression' based on target dtype and unique count."""
        col_type = df[target_column].dtype
        unique_count = df[target_column].dropna().nunique()
        
        if np.issubdtype(col_type, np.number):
            # If numerical but has very few unique values (e.g. binary classification, 0 or 1), treat as classification
            if unique_count <= 10:
                return "classification"
            return "regression"
        else:
            return "classification"

    @staticmethod
    def preprocess_for_ml(df: pd.DataFrame, target_column: str, feature_columns: List[str]) -> Tuple[np.ndarray, np.ndarray, List[str], Any]:
        """Preprocesses feature and target columns automatically for model consumption."""
        X_df = df[feature_columns].copy()
        y_df = df[target_column].copy()
        
        # 1. Target Imputation and Encoding
        if y_df.isnull().any():
            # Fill target nulls with mode or median
            if np.issubdtype(y_df.dtype, np.number):
                y_df = y_df.fillna(y_df.median())
            else:
                y_df = y_df.fillna(y_df.mode()[0] if len(y_df.mode()) > 0 else "unknown")
                
        target_encoder = None
        if not np.issubdtype(y_df.dtype, np.number) or y_df.dtype == 'bool':
            target_encoder = LabelEncoder()
            y = target_encoder.fit_transform(y_df.astype(str))
        else:
            y = y_df.values

        # 2. Features Preprocessing
        # Classify columns to handle them correctly
        num_cols = []
        cat_cols = []
        for col in X_df.columns:
            if np.issubdtype(X_df[col].dtype, np.number):
                num_cols.append(col)
            else:
                cat_cols.append(col)

        # Impute numeric features with median
        if num_cols:
            num_imputer = SimpleImputer(strategy='median')
            X_df[num_cols] = num_imputer.fit_transform(X_df[num_cols])

        # Impute and encode categorical features
        if cat_cols:
            for col in cat_cols:
                # Mode impute
                mode_val = X_df[col].mode()
                X_df[col] = X_df[col].fillna(mode_val[0] if len(mode_val) > 0 else "missing")
                # Label encode
                le = LabelEncoder()
                X_df[col] = le.fit_transform(X_df[col].astype(str))

        # Get final feature list (for feature importance tracking)
        processed_feature_names = list(X_df.columns)
        X = X_df.values

        return X, y, processed_feature_names, target_encoder

    @classmethod
    def train_automl(cls, df: pd.DataFrame, target_column: str, feature_columns: Optional[List[str]] = None, test_size: float = 0.2) -> Dict[str, Any]:
        """Trains multiple ML models, scores them, and identifies the best pipeline."""
        if target_column not in df.columns:
            raise ValueError(f"Target column '{target_column}' not found.")
            
        if not feature_columns:
            # Default to all columns except target
            feature_columns = [col for col in df.columns if col != target_column]
            
        if not feature_columns:
            raise ValueError("No feature columns selected for training.")

        task_type = cls.detect_task_type(df, target_column)
        
        # Preprocess
        X, y, feature_names, target_encoder = cls.preprocess_for_ml(df, target_column, feature_columns)
        
        # Train-Test Split
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_size, random_state=42)
        
        results = []
        trained_pipelines = {}

        if task_type == "classification":
            # Models to train
            models = {
                "Logistic Regression": LogisticRegression(max_iter=1000, random_state=42),
                "Decision Tree": DecisionTreeClassifier(random_state=42),
                "Random Forest": RandomForestClassifier(random_state=42),
                "XGBoost": XGBClassifier(use_label_encoder=False, eval_metric='logloss', random_state=42)
            }
            
            for name, model in models.items():
                start_time = time.time()
                try:
                    # Train
                    model.fit(X_train, y_train)
                    train_time = time.time() - start_time
                    
                    # Predict
                    y_pred = model.predict(X_test)
                    
                    # Evaluate
                    acc = float(accuracy_score(y_test, y_pred))
                    prec, rec, f1, _ = precision_recall_fscore_support(y_test, y_pred, average='weighted', zero_division=0)
                    
                    # Confusion Matrix
                    cm = confusion_matrix(y_test, y_pred)
                    cm_list = cm.tolist()
                    
                    # Unique labels in test set
                    unique_labels = sorted(list(set(y_test).union(set(y_pred))))
                    label_names = [str(target_encoder.inverse_transform([lbl])[0]) if target_encoder else str(lbl) for lbl in unique_labels]

                    # Feature Importance
                    importances = {}
                    if hasattr(model, "feature_importances_"):
                        raw_importances = model.feature_importances_
                        importances = {feature_names[i]: float(raw_importances[i]) for i in range(len(feature_names))}
                    elif hasattr(model, "coef_"):
                        # For LogisticRegression, take absolute values of first class coefficients
                        coef = model.coef_
                        if coef.ndim > 1:
                            coef = coef[0]
                        # Absolute weights
                        abs_coef = np.abs(coef)
                        # Normalize to sum to 1
                        total = abs_coef.sum()
                        if total > 0:
                            abs_coef = abs_coef / total
                        importances = {feature_names[i]: float(abs_coef[i]) for i in range(len(feature_names))}

                    # Sort importances
                    sorted_importances = sorted(importances.items(), key=lambda x: x[1], reverse=True)
                    
                    results.append({
                        "model_name": name,
                        "accuracy": round(acc, 4),
                        "precision": round(float(prec), 4),
                        "recall": round(float(rec), 4),
                        "f1_score": round(float(f1), 4),
                        "confusion_matrix": {
                            "matrix": cm_list,
                            "labels": label_names
                        },
                        "feature_importance": [{"feature": k, "importance": round(v, 4)} for k, v in sorted_importances],
                        "training_time_seconds": round(train_time, 4),
                        "success": True
                    })
                    
                    # Store model pipeline
                    trained_pipelines[name] = {
                        "model": model,
                        "feature_columns": feature_columns,
                        "target_encoder": target_encoder,
                        "task_type": task_type
                    }
                    
                except Exception as e:
                    results.append({
                        "model_name": name,
                        "success": False,
                        "error": str(e)
                    })

            # Determine best model based on F1 Score
            valid_results = [r for r in results if r["success"]]
            best_model_name = max(valid_results, key=lambda x: x["f1_score"])["model_name"] if valid_results else None

        else: # regression task
            models = {
                "Linear Regression": LinearRegression(),
                "Decision Tree": DecisionTreeRegressor(random_state=42),
                "Random Forest": RandomForestRegressor(random_state=42),
                "XGBoost": XGBRegressor(random_state=42)
            }
            
            for name, model in models.items():
                start_time = time.time()
                try:
                    # Train
                    model.fit(X_train, y_train)
                    train_time = time.time() - start_time
                    
                    # Predict
                    y_pred = model.predict(X_test)
                    
                    # Evaluate
                    r2 = float(r2_score(y_test, y_pred))
                    mse = float(mean_squared_error(y_test, y_pred))
                    mae = float(mean_absolute_error(y_test, y_pred))
                    rmse = float(np.sqrt(mse))

                    # Feature Importance
                    importances = {}
                    if hasattr(model, "feature_importances_"):
                        raw_importances = model.feature_importances_
                        importances = {feature_names[i]: float(raw_importances[i]) for i in range(len(feature_names))}
                    elif hasattr(model, "coef_"):
                        # Normalize coefficients for linear models
                        abs_coef = np.abs(model.coef_)
                        total = abs_coef.sum()
                        if total > 0:
                            abs_coef = abs_coef / total
                        importances = {feature_names[i]: float(abs_coef[i]) for i in range(len(feature_names))}

                    # Sort importances
                    sorted_importances = sorted(importances.items(), key=lambda x: x[1], reverse=True)
                    
                    results.append({
                        "model_name": name,
                        "r2_score": round(r2, 4),
                        "mse": round(mse, 4),
                        "mae": round(mae, 4),
                        "rmse": round(rmse, 4),
                        "feature_importance": [{"feature": k, "importance": round(v, 4)} for k, v in sorted_importances],
                        "training_time_seconds": round(train_time, 4),
                        "success": True
                    })
                    
                    # Store model pipeline
                    trained_pipelines[name] = {
                        "model": model,
                        "feature_columns": feature_columns,
                        "target_encoder": target_encoder,
                        "task_type": task_type
                    }
                except Exception as e:
                    results.append({
                        "model_name": name,
                        "success": False,
                        "error": str(e)
                    })

            # Determine best model based on R2 Score
            valid_results = [r for r in results if r["success"]]
            best_model_name = max(valid_results, key=lambda x: x["r2_score"])["model_name"] if valid_results else None

        # Return results along with cache references (can be retrieved via download endpoint)
        return {
            "task_type": task_type,
            "models_evaluated": results,
            "best_model": best_model_name,
            "_pipelines": trained_pipelines # Private, not sent to UI but kept in service cache if needed
        }

# Global AutoML pipeline registry cache
active_pipelines_cache: Dict[str, Any] = {}
