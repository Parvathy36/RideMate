import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import joblib
import os

def generate_synthetic_data(num_samples=1000):
    np.random.seed(42)
    # 0 = Normal, 1 = Fraud
    
    # Generate Normal Users (majority, ~90%)
    n_normal = int(num_samples * 0.9)
    normal_data = {
        'rides_per_hour': np.random.uniform(0, 2, n_normal),
        'cancel_ratio': np.random.uniform(0, 0.2, n_normal),
        'payment_failure_rate': np.random.uniform(0, 0.1, n_normal),
        'account_age_days': np.random.uniform(30, 1000, n_normal),
        'distance': np.random.uniform(1, 50, n_normal),
        'is_fraud': 0
    }
    
    # Generate Fraudulent Users (minority, ~10%)
    n_fraud = num_samples - n_normal
    fraud_data = {
        'rides_per_hour': np.random.uniform(2, 10, n_fraud),
        'cancel_ratio': np.random.uniform(0.3, 1.0, n_fraud),
        'payment_failure_rate': np.random.uniform(0.2, 1.0, n_fraud),
        'account_age_days': np.random.uniform(0, 30, n_fraud),
        'distance': np.random.uniform(1, 100, n_fraud),
        'is_fraud': 1
    }
    
    df_normal = pd.DataFrame(normal_data)
    df_fraud = pd.DataFrame(fraud_data)
    
    df = pd.concat([df_normal, df_fraud], ignore_index=True)
    # Shuffle
    df = df.sample(frac=1, random_state=42).reset_index(drop=True)
    return df

def train_and_save():
    print("Generating synthetic data...")
    df = generate_synthetic_data(2000)
    
    X = df[['rides_per_hour', 'cancel_ratio', 'payment_failure_rate', 'account_age_days', 'distance']]
    y = df['is_fraud']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("Training RandomForestClassifier...")
    model = RandomForestClassifier(n_estimators=100, random_state=42, max_depth=5)
    model.fit(X_train, y_train)
    
    preds = model.predict(X_test)
    acc = accuracy_score(y_test, preds)
    print(f"Model Accuracy: {acc:.4f}")
    
    # Save the model
    os.makedirs('models', exist_ok=True)
    model_path = 'models/fraud_model.pkl'
    joblib.dump(model, model_path)
    print(f"Model saved to {model_path}")

if __name__ == '__main__':
    train_and_save()
