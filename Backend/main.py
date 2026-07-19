from fastapi import FastAPI, UploadFile, File
from PIL import Image
import io
import torch
import torchvision.models as models
import torch.nn as nn
from fastapi.middleware.cors import CORSMiddleware
from torchvision import transforms
import numpy as np
import joblib
from groq import Groq  # ✅ Groq
import os
app = FastAPI()

# -------- Groq Setup --------
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
groq_client = Groq(api_key=GROQ_API_KEY)

# -------- Cache (avoids repeated API calls for same disease) --------
disease_cache = {}

# -------- Classes --------
classes = [
    'curl', 'early_spot', 'healthy', 'late_spot', 'rosette', 'rust', 'wormbite'
]

device = torch.device("cpu")

# -------- Load EfficientNet --------
eff_model = models.efficientnet_v2_s(weights=None)
num_features = eff_model.classifier[1].in_features
eff_model.classifier[1] = nn.Linear(num_features, 7)
eff_model.load_state_dict(torch.load("models/efficientnet_model.pth", map_location=device))
eff_model.eval()

# -------- Load ConvNeXt --------
conv_model = models.convnext_base(weights=None)
num_features = conv_model.classifier[2].in_features
conv_model.classifier[2] = nn.Linear(num_features, 7)
conv_model.load_state_dict(torch.load("models/convnext_model.pth", map_location=device))
conv_model.eval()

# -------- Load Ensemble Model --------
meta_model = joblib.load("models/ensemble_model.pkl")

# -------- Image Transform --------
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor()
])

# -------- Groq Function --------
def get_groq_suggestions(disease: str) -> str:

    # ✅ Return cached result if already fetched
    if disease in disease_cache:
        return disease_cache[disease]

    prompt = f"""
    A crop has been diagnosed with: {disease}

    Please provide the following in simple language for farmers:
    - Cause: Why does this disease occur?
    - Prevention: How to prevent it?
    - Treatment: How to treat it?
    - Advice: Any additional tips?

    Keep it short and easy to understand.
    """

    try:
        response = groq_client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {
                    "role": "system",
                    "content": "You are an agricultural expert helping farmers understand crop diseases."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            max_tokens=512,
            temperature=0.7
        )

        result = response.choices[0].message.content
        disease_cache[disease] = result  # ✅ Save to cache
        return result

    except Exception as e:
        return f"Error getting suggestions: {str(e)}"

# -------- Prediction API --------
@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    image = Image.open(io.BytesIO(await file.read())).convert("RGB")
    img = transform(image).unsqueeze(0)

    with torch.no_grad():
        eff_out = torch.softmax(eff_model(img), dim=1).numpy()
        conv_out = torch.softmax(conv_model(img), dim=1).numpy()

    X_meta = np.concatenate([eff_out, conv_out], axis=1)

    pred = meta_model.predict(X_meta)[0]
    confidence = float(np.max(X_meta))

    disease_name = classes[pred]

    # ✅ Groq suggestions
    suggestion_text = get_groq_suggestions(disease_name)

    return {
        "disease": disease_name,
        "confidence": round(confidence * 100, 2),
        "suggestions": suggestion_text
    }

# -------- CORS --------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)