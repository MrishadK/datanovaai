import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import router

app = FastAPI(
    title="DataNova AI",
    description="Next-Generation Automated Data Preparation & Preprocessing Local Backend",
    version="1.0.0"
)

# Enable CORS for Flutter Client requests (cross-origin on localhost)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins for local desktop flexibility
    allow_credentials=True,
    allow_methods=["*"],  # Allows all standard methods (GET, POST, etc.)
    allow_headers=["*"],  # Allows custom API key headers (X-Gemini-Key, X-OpenAI-Key)
)

# Register our data cleaner & AutoML router
app.include_router(router, prefix="/api")

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "DataNova AI Backend Core",
        "version": "1.0.0",
        "message": "Welcome to DataNova AI. Next-generation data science backend is up and running!"
    }

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
