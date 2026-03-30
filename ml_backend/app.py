from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import os

app = Flask(__name__)
CORS(app)

MODEL_PATH = 'models/fraud_model.pkl'
model = None

# Load the model at startup
if os.path.exists(MODEL_PATH):
    model = joblib.load(MODEL_PATH)
    print(f"Loaded model from {MODEL_PATH}")
else:
    print(f"Warning: Model not found at {MODEL_PATH}. Prediction endpoints will fail.")

@app.route('/predict', methods=['POST'])
def predict():
    if model is None:
        return jsonify({"error": "Model not loaded"}), 500

    try:
        data = request.json
        # Expected features: rides_per_hour, cancel_ratio, payment_failure_rate, account_age_days, distance
        features = [
            float(data.get('rides_per_hour', 0.0)),
            float(data.get('cancel_ratio', 0.0)),
            float(data.get('payment_failure_rate', 0.0)),
            float(data.get('account_age_days', 30.0)),
            float(data.get('distance', 5.0))
        ]

        prediction = model.predict([features])[0]
        # prediction: 0 is Normal, 1 is Fraud
        
        # Calculate a probability score just in case we need it
        probs = model.predict_proba([features])[0]
        fraud_probability = probs[1]
        
        response = {
            "prediction": "fraud" if prediction == 1 else "normal",
            "fraud_probability": round(float(fraud_probability), 4)
        }
        return jsonify(response)

    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
