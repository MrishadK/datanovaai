import io
import pandas as pd
import numpy as np
from app.services.data_manager import DataManager
from app.services.clean_service import CleanService
from app.services.ml_service import MLService

def run_tests():
    print("="*60)
    print("STARTING DATANOVA AI BACKEND SERVICES TEST SUITE")
    print("="*60)

    # 1. Generate Mock Data
    print("\n[STEP 1] Generating mock dataset with various data issues...")
    data = {
        "id": range(1, 21),
        "age": [25.0, 30.0, np.nan, 35.0, 40.0, 150.0, 28.0, 31.0, 29.0, np.nan, 
                25.0, 30.0, 45.0, 50.0, 55.0, 60.0, 22.0, 24.0, 27.0, -10.0],  # Outliers: 150, -10; Missing: NaN
        "gender": ["M", "F", "F", "M", np.nan, "M", "F", "M", "F", "M", 
                   "M", "F", "F", "M", "M", "F", "F", "M", "F", "M"],            # Missing: NaN
        "salary": [50000, 60000, 55000, 80000, 95000, 120000, 62000, 67000, 58000, np.nan,
                   50000, 60000, 110000, 115000, 130000, 140000, 48000, 52000, 56000, 30000], # Missing: NaN
        "signup_date": ["2025-01-01", "2025-01-02", "2025-01-03", "2025-01-04", "2025-01-05",
                        "2025-01-06", "2025-01-07", "2025-01-08", "2025-01-09", "2025-01-10",
                        "2025-01-01", "2025-01-02", "2025-01-13", "2025-01-14", "2025-01-15",
                        "2025-01-16", "2025-01-17", "2025-01-18", "2025-01-19", "2025-01-20"],
        "review": ["Great app, loved the dataset cleaner!", "Simple and efficient.", "Had some errors but overall good.",
                   "Outstanding performance!", "Could be better, crashed once.", "Excellent UI, looks like premium.",
                   "Average app.", "I really like the dark mode.", "Very beautiful interface.", "Fast API backend is super fast.",
                   "Great app, loved the dataset cleaner!", "Simple and efficient.", "Nice visualization, scatter plot works well.",
                   "Best ML tool ever.", "Highly recommended.", "Helped me clean Titanic dataset in seconds.",
                   "Good, supports excel.", "Nice drag and drop area.", "The co-pilot chat is amazing.", "Perfect dataset cleaner."]
    }
    
    df = pd.DataFrame(data)
    
    # Let's add duplicate rows manually
    df = pd.concat([df, df.iloc[0:2]], ignore_index=True)
    print(f"Created dataset with {len(df)} rows, {len(df.columns)} columns.")
    print(f"Duplicates: {df.duplicated().sum()}")
    print(f"Missing values:\n{df.isnull().sum()}")

    # 2. Test DataManager Ingestion
    print("\n[STEP 2] Testing DataManager.load_file...")
    csv_buffer = io.BytesIO()
    df.to_csv(csv_buffer, index=False)
    csv_bytes = csv_buffer.getvalue()

    manager = DataManager()
    summary = manager.load_file("test_data.csv", csv_bytes)
    assert summary["rows_count"] == len(df), "Row count mismatch!"
    assert summary["columns_count"] == len(df.columns), "Col count mismatch!"
    assert summary["duplicate_rows_count"] == 2, "Duplicate count mismatch!"
    print("DataManager loading verified successfully. Row summary fields check:")
    print(f"  Rows: {summary['rows_count']}, Cols: {summary['columns_count']}, Duplicates: {summary['duplicate_rows_count']}")

    # 3. Test Duplicate Removal
    print("\n[STEP 3] Testing CleanService.remove_duplicates...")
    curr_df = manager.get_current_df()
    no_dup_df = CleanService.remove_duplicates(curr_df)
    manager.apply_operation(no_dup_df, "Remove Duplicates")
    summary = manager.get_summary()
    assert summary["duplicate_rows_count"] == 0, "Duplicate rows not successfully removed!"
    assert summary["rows_count"] == 20, "Row count after deduplication mismatch!"
    print("Duplicates removed correctly. Count is now 0.")

    # 4. Test Missing Value Imputation
    print("\n[STEP 4] Testing CleanService.impute_missing...")
    curr_df = manager.get_current_df()
    
    # Age - mean
    age_imputed = CleanService.impute_missing(curr_df, "age", "mean")
    assert age_imputed["age"].isnull().sum() == 0, "Age imputation failed!"
    print(f"  Age mean value used: {age_imputed['age'].mean()}")
    
    # Gender - mode
    gender_imputed = CleanService.impute_missing(curr_df, "gender", "mode")
    assert gender_imputed["gender"].isnull().sum() == 0, "Gender imputation failed!"
    print(f"  Gender mode category used: {gender_imputed['gender'].mode()[0]}")

    # Salary - ffill
    salary_imputed = CleanService.impute_missing(curr_df, "salary", "ffill")
    assert salary_imputed["salary"].isnull().sum() == 0, "Salary imputation failed!"
    print("  Salary forward fill imputation verified.")

    # Apply operations to the manager to progress state
    curr_df = CleanService.impute_missing(curr_df, "age", "mean")
    curr_df = CleanService.impute_missing(curr_df, "gender", "mode")
    curr_df = CleanService.impute_missing(curr_df, "salary", "median")
    manager.apply_operation(curr_df, "Imputed Null Values")
    assert manager.get_summary()["missing_values_count"] == 0, "Total missing cells not 0 after full imputation!"
    print("All missing value imputations successfully applied and verified.")

    # 5. Test Outlier Detection and Handling
    print("\n[STEP 5] Testing CleanService Outlier Detection...")
    curr_df = manager.get_current_df()
    
    # Detect outliers via Z-score
    z_res = CleanService.detect_outliers(curr_df, "age", "zscore", threshold=2.0)
    print(f"  Z-Score Outliers count (thr=2.0): {z_res['outlier_count']} (Indices: {z_res['outlier_indices']})")
    
    # Detect outliers via IQR
    iqr_res = CleanService.detect_outliers(curr_df, "age", "iqr")
    print(f"  IQR Outliers count: {iqr_res['outlier_count']} (Bounds: {iqr_res['bounds']})")

    # Handle outliers (cap outliers)
    capped_df = CleanService.handle_outliers(curr_df, "age", "iqr", "cap")
    new_iqr_res = CleanService.detect_outliers(capped_df, "age", "iqr")
    assert new_iqr_res["outlier_count"] == 0, "Outliers were not completely capped!"
    print("  IQR outlier capping verified. New outlier count is 0.")

    # Handle outliers (drop outliers)
    dropped_df = CleanService.handle_outliers(curr_df, "age", "zscore", "drop", threshold=2.0)
    print(f"  Rows count before dropping outliers: {len(curr_df)}, after dropping: {len(dropped_df)}")
    assert len(dropped_df) < len(curr_df), "No outlier rows were dropped!"

    # Save capped dataset to state
    manager.apply_operation(capped_df, "Capped Outliers in 'age'")
    print("Outlier handler verified successfully.")

    # 6. Test Feature Engineering (Encoding, Scaling, Datetime splits, Vectorization)
    print("\n[STEP 6] Testing CleanService Preprocessing...")
    curr_df = manager.get_current_df()

    # One-Hot encoding of Gender
    encoded_df = CleanService.one_hot_encode(curr_df, ["gender"])
    assert "gender_M" in encoded_df.columns and "gender_F" in encoded_df.columns, "One hot columns not created!"
    print("  One-Hot encoding verified.")

    # Label encoding gender
    label_df = CleanService.label_encode(curr_df, ["gender"])
    assert label_df["gender"].dtype == int or label_df["gender"].dtype == np.int32 or label_df["gender"].dtype == np.int64, "Label encoding dtype not integer!"
    print("  Label encoding verified.")

    # Scaling age & salary
    scaled_df = CleanService.scale_numerical(curr_df, ["age", "salary"], "standardize")
    assert np.isclose(scaled_df["age"].mean(), 0, atol=1e-5), "Standard scaling mean not close to 0!"
    print("  Standard scaling (Standardization) verified.")

    # Extract Datetime Features
    dt_df = CleanService.extract_datetime_features(curr_df, "signup_date")
    assert "signup_date_year" in dt_df.columns and "signup_date_month" in dt_df.columns, "Datetime feature split columns not created!"
    print("  Datetime extraction split verified.")

    # Text TF-IDF Vectorization
    vec_df = CleanService.text_vectorize(curr_df, "review", max_features=10)
    tfidf_cols = [c for c in vec_df.columns if "review_tfidf_" in c]
    assert len(tfidf_cols) > 0, "No TF-IDF columns created!"
    print(f"  TF-IDF text vectorizer verified. Created {len(tfidf_cols)} feature columns.")

    # Integrate engineered columns into our manager pipeline
    processed_df = CleanService.label_encode(curr_df, ["gender"])
    processed_df = CleanService.extract_datetime_features(processed_df, "signup_date")
    processed_df = CleanService.text_vectorize(processed_df, "review", max_features=10)
    manager.apply_operation(processed_df, "Feature Engineering Pipeline Completed")
    print("Feature engineering pipeline integrated into manager state.")

    # 7. Test AutoML Services
    print("\n[STEP 7] Testing MLService (AutoML Framework)...")
    final_df = manager.get_current_df()
    
    # 7.a Classification Task
    # We will use "gender" as class target since we label encoded it to 0 and 1
    # Check what features to use
    features = [c for c in final_df.columns if c not in ["gender", "id"]]
    print(f"  Training classification task. Target: 'gender', Features: {features}")
    clf_results = MLService.train_automl(final_df, "gender", feature_columns=features)
    assert clf_results["task_type"] == "classification", "Task type detected incorrect!"
    assert len(clf_results["models_evaluated"]) > 0, "No models evaluated!"
    print("  Classification results leaderboard:")
    for res in clf_results["models_evaluated"]:
        if res["success"]:
            print(f"    - {res['model_name']}: Accuracy = {res['accuracy']}, F1 Score = {res['f1_score']}")
        else:
            print(f"    - {res['model_name']} FAILED: {res['error']}")
    
    # 7.b Regression Task
    # Use "salary" as continuous numeric target
    features_reg = [c for c in final_df.columns if c not in ["salary", "id"]]
    print(f"  Training regression task. Target: 'salary', Features: {features_reg}")
    reg_results = MLService.train_automl(final_df, "salary", feature_columns=features_reg)
    assert reg_results["task_type"] == "regression", "Task type detected incorrect!"
    assert len(reg_results["models_evaluated"]) > 0, "No models evaluated!"
    print("  Regression results leaderboard:")
    for res in reg_results["models_evaluated"]:
        if res["success"]:
            print(f"    - {res['model_name']}: R2 Score = {res['r2_score']}, RMSE = {res['rmse']}")
        else:
            print(f"    - {res['model_name']} FAILED: {res['error']}")

    # 8. Test Undo/Redo Engine
    print("\n[STEP 8] Testing Undo/Redo operations stack...")
    history_len = len(manager.history)
    print(f"  Current history stack length: {history_len} (index: {manager.current_index})")
    
    # Undo
    undo_res = manager.undo()
    assert undo_res["success"], "Undo should be successful!"
    assert manager.current_index == history_len - 2, "Undo index did not update correctly!"
    print(f"  Undo complete: {undo_res['message']}")
    
    # Redo
    redo_res = manager.redo()
    assert redo_res["success"], "Redo should be successful!"
    assert manager.current_index == history_len - 1, "Redo index did not update correctly!"
    print(f"  Redo complete: {redo_res['message']}")

    print("\n" + "="*60)
    print("ALL DATANOVA AI BACKEND SERVICES VERIFIED 100% PERFECTLY!")
    print("="*60)

if __name__ == "__main__":
    run_tests()
