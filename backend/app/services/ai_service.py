import json
import re
import google.generativeai as genai
from openai import OpenAI
from typing import Dict, List, Any, Optional

class AIService:
    @staticmethod
    def _get_dataset_context_prompt(summary: Dict[str, Any]) -> str:
        """Constructs a clean text context summarizing the dataset's structure for the LLM."""
        cols_summary = []
        for col in summary.get("columns", []):
            stats_str = ""
            if "stats" in col:
                if "mean" in col["stats"]:
                    stats = col["stats"]
                    stats_str = f" (Mean: {stats['mean']}, Min: {stats['min']}, Max: {stats['max']})"
                elif "top_values" in col["stats"]:
                    stats_str = f" (Top Categories: {list(col['stats']['top_values'].keys())[:3]})"
                    
            cols_summary.append(
                f"- Name: {col['name']}, Type: {col['type']}, Unique Count: {col['unique_count']}, Nulls: {col['null_count']} ({col['null_percentage']}%) {stats_str}"
            )
            
        cols_text = "\n".join(cols_summary)
        
        # Take a snippet of preview data to give semantic context
        preview_snippet = summary.get("preview_data", [])[:3]
        preview_text = json.dumps(preview_snippet, indent=2)

        return f"""
Dataset: {summary.get('filename', 'unnamed_dataset')}
Total Rows: {summary.get('rows_count')}
Total Columns: {summary.get('columns_count')}
Total Duplicate Rows: {summary.get('duplicate_rows_count')}

Columns Schema & Statistics:
{cols_text}

Sample Preview Data (first 3 rows):
{preview_text}
"""

    @classmethod
    def get_cleaning_recommendations(cls, summary: Dict[str, Any], gemini_key: Optional[str] = None, openai_key: Optional[str] = None) -> Dict[str, Any]:
        """Queries LLM to generate premium dataset cleaning and engineering recommendations in structured JSON."""
        context = cls._get_dataset_context_prompt(summary)
        
        system_prompt = """
You are an expert Data Scientist and AI Machine Learning Engineer. Analyze the provided dataset metadata and schema, and return a JSON object containing data preparation recommendations.
Your output MUST be a valid JSON object matching the following structure:
{
  "general_summary": "A high-level 2-3 sentence assessment of the dataset's quality, issues, and readiness.",
  "columns_to_drop": [
    {"column": "column_name", "reason": "Explanation of why this column should be removed (e.g. unique ID, redundant, >90% nulls)."}
  ],
  "encoding_recommendations": [
    {"column": "column_name", "method": "One-hot Encoding / Label Encoding", "reason": "Why this encoding fits (e.g. low-cardinality nominal, high-cardinality ordinal)."}
  ],
  "scaling_recommendations": [
    {"column": "column_name", "method": "Standardization (StandardScaler) / Normalization (MinMax)", "reason": "Why this scaling fits (e.g. standardizes outliers, bounds values between 0 and 1)."}
  ],
  "feature_engineering_ideas": [
    {"description": "A feature engineering idea.", "benefit": "What value this engineered feature adds."}
  ],
  "possible_targets": [
    {"column": "column_name", "task_type": "Classification / Regression", "reason": "Why this column is a suitable target variable."}
  ],
  "best_ml_models": [
    {"model": "Model Name", "reason": "Why this model is suitable for training on this dataset."}
  ]
}

DO NOT include any conversational text, markdown formatting (other than the JSON itself), or triple backticks outside the JSON. Return raw JSON.
"""
        
        user_prompt = f"Analyze this dataset and provide structured recommendations:\n{context}"

        # If no key, return offline recommendation template
        if not gemini_key and not openai_key:
            return cls._get_offline_recommendations(summary)

        try:
            if gemini_key:
                genai.configure(api_key=gemini_key)
                model = genai.GenerativeModel(
                    'gemini-3.5-flash',
                    generation_config={"response_mime_type": "application/json"}
                )
                response = model.generate_content([system_prompt, user_prompt])
                text_response = response.text
            else: # OpenAI
                client = OpenAI(api_key=openai_key)
                response = client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    response_format={"type": "json_object"}
                )
                text_response = response.choices[0].message.content

            # Parse JSON safely
            # Clean up potential markdown wrapper codeblocks if the LLM ignored guidelines
            cleaned_text = re.sub(r"^```json\s*", "", text_response, flags=re.IGNORECASE)
            cleaned_text = re.sub(r"\s*```$", "", cleaned_text)
            
            return json.loads(cleaned_text.strip())
        except Exception as e:
            # Fallback to local heuristic recommendations if LLM fails
            return {
                "general_summary": f"Local analysis completed (AI Service encountered a connection error: {str(e)}). Please check API configurations.",
                **cls._get_offline_recommendations(summary)
            }

    @classmethod
    def chat_assistant(cls, query: str, history: List[Dict[str, str]], summary: Dict[str, Any], gemini_key: Optional[str] = None, openai_key: Optional[str] = None) -> str:
        """Interactive chatbot response using Gemini or OpenAI, seeded with the full dataset summary context."""
        context = cls._get_dataset_context_prompt(summary)
        
        system_prompt = f"""
You are DataNova AI Assistant, an elite conversational data scientist embedded in a premium dataset cleaning desktop app.
You are helping the user clean and analyze their active dataset. 

Here is the current dataset context:
{context}

Guidelines:
1. Always base your explanations directly on the actual columns, statistics, missing values, or correlations present in the active dataset.
2. Keep responses highly informative, professional, concise, and mathematically sound.
3. Suggest specific cleaning actions or visualizations the user can perform inside the application.
4. If the user asks about ML models or correlations, provide insights tailored to their schema.
5. Support formatting with Markdown tables, bold text, and lists where appropriate.
"""

        if not gemini_key and not openai_key:
            return "Offline Mode is active. I can see your dataset statistics, but my intelligent chat agent requires a Gemini or OpenAI API Key. Please configure your API keys in the **Settings Page** to unlock full conversation capabilities!"

        try:
            messages = [{"role": "system", "content": system_prompt}]
            
            # Add conversation history
            for msg in history:
                messages.append({"role": msg["role"], "content": msg["content"]})
                
            messages.append({"role": "user", "content": query})

            if gemini_key:
                # Use Gemini chat interface
                genai.configure(api_key=gemini_key)
                
                # Combine system prompt with query/history for Gemini since standard API structure varies slightly
                # A reliable standard way is to construct a chat history block
                prompt_blocks = []
                prompt_blocks.append(f"System Instructions:\n{system_prompt}\n")
                prompt_blocks.append("Conversation History:\n")
                for msg in history:
                    role_lbl = "User" if msg["role"] == "user" else "Assistant"
                    prompt_blocks.append(f"{role_lbl}: {msg['content']}\n")
                prompt_blocks.append(f"User: {query}\nDataNova Assistant:")
                
                full_prompt = "".join(prompt_blocks)
                
                model = genai.GenerativeModel('gemini-3.5-flash')
                response = model.generate_content(full_prompt)
                return response.text
            else: # OpenAI
                client = OpenAI(api_key=openai_key)
                response = client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=messages
                )
                return response.choices[0].message.content
        except Exception as e:
            return f"An error occurred while communicating with the AI API: {str(e)}. Please check your API key and internet connection."

    @staticmethod
    def _get_offline_recommendations(summary: Dict[str, Any]) -> Dict[str, Any]:
        """Provides heuristic data science rules for local offline fallback recommendations."""
        columns = summary.get("columns", [])
        
        # 1. Detect ID-like or redundant columns (high cardinality categorical, or single value)
        columns_to_drop = []
        for col in columns:
            name_lower = col["name"].lower()
            if "id" in name_lower or "index" in name_lower or "serial" in name_lower:
                if col["unique_count"] == summary.get("rows_count"):
                    columns_to_drop.append({
                        "column": col["name"],
                        "reason": f"Column '{col['name']}' behaves like an ID column since every row has a unique value. It offers no predictive value for ML."
                    })
            if col["null_percentage"] > 80:
                columns_to_drop.append({
                    "column": col["name"],
                    "reason": f"Column '{col['name']}' has {col['null_percentage']}% missing values. Imputing it might introduce excessive noise."
                })

        # 2. Encoding Recommendations
        encoding = []
        for col in columns:
            if col["type"] == "categorical":
                if col["unique_count"] < 8:
                    encoding.append({
                        "column": col["name"],
                        "method": "One-hot Encoding",
                        "reason": f"Low cardinality ({col['unique_count']} unique values). Generates clear, non-sparse indicator columns."
                    })
                else:
                    encoding.append({
                        "column": col["name"],
                        "method": "Label Encoding",
                        "reason": f"Higher cardinality ({col['unique_count']} unique values). Label encoding prevents high column sparsity."
                    })

        # 3. Scaling recommendations
        scaling = []
        for col in columns:
            if col["type"] == "numerical":
                # Check standard stats
                stats = col.get("stats", {})
                std = stats.get("std", 0)
                mean = stats.get("mean", 0)
                median = stats.get("median", 0)
                
                # Check for skewness skew check (mean vs median)
                if std and abs(mean - median) / std > 0.15:
                    scaling.append({
                        "column": col["name"],
                        "method": "Normalization (MinMax)",
                        "reason": f"Distribution appears skewed (Mean {round(mean, 2)} vs Median {round(median, 2)}). Normalization bounds the data nicely."
                    })
                else:
                    scaling.append({
                        "column": col["name"],
                        "method": "Standardization (StandardScaler)",
                        "reason": f"Distribution is relatively symmetrical. Standardization centers values with a mean of 0 and unit variance."
                    })

        # 4. Feature Engineering Ideas
        feat_eng = []
        for col in columns:
            if col["type"] == "datetime":
                feat_eng.append({
                    "description": f"Extract components from '{col['name']}'",
                    "benefit": "Splits dates into Year, Month, Day, and Day of Week numerical parameters to capture seasonality."
                })
            elif col["type"] == "text":
                feat_eng.append({
                    "description": f"TF-IDF Text Vectorization on '{col['name']}'",
                    "benefit": "Generates mathematical frequency attributes for terms in text data to let ML models analyze textual sentiments."
                })

        # 5. Target column suggestion
        possible_targets = []
        # Suggest categorical/numeric columns with low-mid values that don't look like ID
        for col in columns:
            name_lower = col["name"].lower()
            if "target" in name_lower or "label" in name_lower or "class" in name_lower or "price" in name_lower or "survived" in name_lower or "status" in name_lower:
                possible_targets.append({
                    "column": col["name"],
                    "task_type": "Classification" if col["type"] == "categorical" else "Regression",
                    "reason": f"Column name '{col['name']}' strongly suggests it is a typical label/target variable."
                })
        
        if not possible_targets and columns:
            # Fallback suggestion (last column that isn't ID)
            last_col = columns[-1]
            possible_targets.append({
                "column": last_col["name"],
                "task_type": "Classification" if last_col["type"] == "categorical" else "Regression",
                "reason": f"Suggested as default target. It is the last column in the dataset structure."
            })

        # 6. ML Models
        best_ml_models = []
        has_categorical_target = any(t["task_type"] == "Classification" for t in possible_targets)
        if has_categorical_target:
            best_ml_models = [
                {"model": "Random Forest Classifier", "reason": "Excellent baseline. Handles mixed data types and captures non-linear boundaries perfectly."},
                {"model": "XGBoost Classifier", "reason": "Gradient boosted trees that yield industry-leading accuracies for structured datasets."}
            ]
        else:
            best_ml_models = [
                {"model": "Random Forest Regressor", "reason": "Highly resilient ensemble model, excellent at avoiding overfitting for numerical predictions."},
                {"model": "XGBoost Regressor", "reason": "Highly efficient tree booster, optimal for predicting complex pricing or value predictions."}
            ]

        return {
            "general_summary": "Local heuristic rules used. Configure an API key in settings to unlock deep semantic insights and summary generator powered by Gemini or GPT-4o-mini.",
            "columns_to_drop": columns_to_drop,
            "encoding_recommendations": encoding,
            "scaling_recommendations": scaling,
            "feature_engineering_ideas": feat_eng,
            "possible_targets": possible_targets,
            "best_ml_models": best_ml_models
        }
