# DataNova AI

Next-Generation Automated Data Preparation and AutoML Desktop Platform.

DataNova AI is a professional, local-first desktop application designed for data analysts, students, and machine learning engineers to instantly ingest, profile, clean, engineer, and model tabular datasets. Built with a fluid, glassmorphic **Flutter (Windows Desktop)** frontend and an asynchronous **Python (FastAPI)** data science engine, it operates entirely locally on your machine with high responsiveness and low resource footprints.

---

## System Architecture

The application implements a decoupled, offline-first client-server model:

```
┌─────────────────────────────────┐
│     Flutter Windows Client      │
│  - Fluid Glassmorphism UI       │
│  - Reactive Riverpod State      │
│  - Native Window Controls       │
└────────────────┬────────────────┘
                 │
                 │ Asynchronous REST API (Localhost:8000)
                 ▼
┌─────────────────────────────────┐
│       Python FastAPI Core       │
│  - Pandas Session Store         │
│  - Scikit-Learn & XGBoost ML    │
│  - Gemini-3.5-Flash AI Agent    │
└─────────────────────────────────┘
```

- **Frontend (Flutter)**: Manages layout, double-scrollable data grids, interactive charts, and Gemini chat threads with 60fps animations.
- **Backend (FastAPI)**: Operates local data science tasks (imputation, outlier capping, ML training) in memory. It holds the active dataset state and manages a local Undo/Redo transformation stack.
- **Zero-Configuration Process Lifecycle**: When the Flutter app starts, it automatically spawns the Python server process in the background. When you close the app window, the process manager intercepts the exit hook and terminates the Python server cleanly, preventing orphaned background tasks.

---

## Core Capabilities

### Ingestion & Visual Profiling
- **Multi-Format Support**: Drag and drop CSV, Excel (.xlsx), or JSON files directly into the workspace.
- **Metadata Summary Profile**: Instantly views rows/columns count, null counts, duplicates percentage, datatypes, and column-level statistics (mean, median, standard deviation, top values).
- **Interactive Visualization Board**: Renders high-fidelity Histograms, Box Plots, Pie Charts, Scatter Diagrams, and dynamic Pearson correlation heatmaps built natively with Syncfusion.

### AI-Powered Data Cleaning & Preprocessing
- **Missing Value Handling**: Detects missing cells and applies mean, median, mode, forward-fill, or backward-fill imputers.
- **Robust Outlier Control**: Detects outliers via IQR (Interquartile Range) or Z-score distributions. Offers instant capping (clipping values within standard boundaries) or dropping.
- **Feature Engineering Engine**:
  - *Categorical Encoders*: Low-cardinality One-Hot Encoding and high-cardinality Label Encoding.
  - *Numerical Scalers*: Standardization (StandardScaler) and Normalization (MinMax).
  - *Datetime Coordinate Splitter*: Separates raw date columns into Year, Month, Day, and Day-of-Week numerical indices.
  - *TF-IDF Text Frequency Vectorizer*: Transforms raw string reviews or text fields into frequency vectors.
- **Undo/Redo Transformation Stack**: Steps backward or forward through any cleaning steps without losing active changes.

### AI Co-Pilot & Chat Drawer
- **Gemini-3.5-Flash recommendations**: Analyzes the dataset's schema and statistics to generate cognitive recommendations (columns to drop, encoding paths, scaling methods, possible target variables).
- **Context-Aware Interactive Chat**: Discusses dataset columns, anomalies, and analytical insights with a local chatbot seeded with active session metadata.
- **Local Fallback Heuristics**: Operates fully offline using deterministic data science rules when no Gemini or OpenAI API keys are configured.

### AutoML Training Center
- **Auto-Task Detection**: Automatically classifies the prediction task into Classification or Regression based on target datatype and cardinality.
- **Parallel Model Training**: Trains 5 baseline machine learning models concurrently (Logistic/Linear Regression, Decision Tree, Random Forest, XGBoost).
- **Leaderboard Evaluation**: Compares accuracy, precision, recall, F1-scores, R2-scores, MSE, and RMSE.
- **Diagnostic Visuals**: Instantly draws native confusion matrices and calculates Gini feature importances.
- **Production Pipeline Exporter**: Downloads trained modeling pipelines as binary `.pkl` objects, and exports elegant PDF data-quality reports containing complete execution histories.

---

## Quick Start & Verification

### Prerequisites
- **Flutter SDK** (compatible with Dart 3.8.1)
- **Python 3.10+**
- Standard development tools (Git, C++ build dependencies for Windows Desktop)

### Automatic App Setup & Execution
You do not need to start the Python server manually. To build and run the entire platform, execute:

```bash
# 1. Clone the repository
git clone <repository-url>](https://github.com/MrishadK/datanovaai.git
cd datanovaai

# 2. Upgrade Flutter dependencies
flutter pub get

# 3. Launch the Windows desktop app
flutter run -d windows
```
*The Flutter app will automatically boot the backend Python server in the background and establish a stable REST client handshake.*

### Manual Python Services Verification
To verify the data science engine and AutoML modules independently of the graphical interface, a local test suite is provided. Navigate to the backend directory and run:

```bash
cd backend
pip install -r requirements.txt
python test_services.py
```
*All tests pass with 100% success across deduplication, missing imputation, IQR outlier capping, scaling, date splits, TF-IDF vectorization, and model training leaderboards.*

---

## Codebase Organization

```
datanovaai/
├── backend/                  # Python FastAPI core
│   ├── app/
│   │   ├── api/routes.py     # Multipart ingestion, endpoints & binary exporters
│   │   └── services/
│   │       ├── ai_service.py # Gemini-3.5-Flash recommendation & Chat drawer
│   │       ├── clean_service.py  # Algorithms for imputation, capping & encoding
│   │       ├── data_manager.py   # Dataset memory states & Undo/Redo stack
│   │       └── ml_service.py # Parallel scikit-learn & XGBoost AutoML pipelines
│   ├── main.py               # Uvicorn entrypoint and CORS policy setup
│   └── test_services.py      # Automated testing suite
├── lib/                      # Flutter Dart source code
│   ├── providers/            # Riverpod state management & theme states
│   ├── screens/              # Dashboard, workspace, visualizations & AutoML screens
│   ├── services/
│   │   ├── api_client.dart   # Network HTTP data transfers & binary stream handlers
│   │   └── backend_launcher.dart # Automatic Python background server manager
│   └── main.dart             # Native size boundaries & window close listeners
└── pubspec.yaml              # Flutter desktop dependencies configurations
```

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
