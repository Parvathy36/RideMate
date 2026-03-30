const express = require('express');
const cors = require('cors');
const axios = require('axios');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
try {
  admin.initializeApp();
  console.log("Firebase Admin Initialized");
} catch (e) {
  console.log("Failed to initialize Firebase Admin", e);
}

const db = admin.firestore?.() || null;

const app = express();
app.use(cors());
app.use(express.json());

const ML_API_URL = 'http://localhost:5000/predict';

async function fetchUserMetrics(userId) {
  if (!db) {
    // Return mock metrics if DB is not available
    return {
      rides_per_hour: 1.5,
      cancel_ratio: 0.1,
      payment_failure_rate: 0.05,
      account_age_days: 120,
    };
  }

  // Assuming 'users' and 'rides' collections exist
  const userRef = await db.collection('users').doc(userId).get();
  const userData = userRef.exists ? userRef.data() : {};
  
  const created_at = userData.created_at ? userData.created_at.toDate() : new Date();
  const account_age_days = (new Date() - created_at) / (1000 * 60 * 60 * 24);

  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const recentRidesSnapshot = await db.collection('rides')
    .where('userId', '==', userId)
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(oneHourAgo))
    .get();
  
  const rides_per_hour = recentRidesSnapshot.size;

  const allRidesSnapshot = await db.collection('rides')
    .where('userId', '==', userId)
    .get();

  let totalRides = 0;
  let cancelledRides = 0;
  let failedPayments = 0;

  allRidesSnapshot.forEach(doc => {
    totalRides++;
    const ride = doc.data();
    if (ride.status === 'cancelled') cancelledRides++;
    if (ride.paymentStatus === 'failed') failedPayments++;
  });

  const cancel_ratio = totalRides > 0 ? cancelledRides / totalRides : 0;
  const payment_failure_rate = totalRides > 0 ? failedPayments / totalRides : 0;

  return {
    rides_per_hour,
    cancel_ratio,
    payment_failure_rate,
    account_age_days
  };
}

async function logSuspiciousActivity(userId, reason, features) {
  if (db) {
    await db.collection('suspicious_activities').add({
      userId,
      reason,
      features,
      status: 'flagged',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  console.log(`Suspicious activity logged for user ${userId}: ${reason}`);
}

app.post('/book-ride', async (req, res) => {
  try {
    const { userId, distance } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const metrics = await fetchUserMetrics(userId);
    const features = {
      ...metrics,
      distance: distance || 5.0
    };

    // 1. Rule-Based Fraud Detection System
    if (features.rides_per_hour > 5) {
      await logSuspiciousActivity(userId, 'High booking frequency', features);
      return res.json({ status: 'blocked', reason: 'High booking frequency' });
    }
    
    if (features.cancel_ratio > 0.8 && features.account_age_days < 7) {
      await logSuspiciousActivity(userId, 'High cancellation rate for new user', features);
      return res.json({ status: 'blocked', reason: 'High cancellation rate for new user' });
    }

    if (features.payment_failure_rate > 0.5) {
      await logSuspiciousActivity(userId, 'High payment failure rate', features);
      return res.json({ status: 'blocked', reason: 'High payment failure rate' });
    }

    // 2. Machine Learning Model Detection
    try {
      const mlResponse = await axios.post(ML_API_URL, features);
      if (mlResponse.data && mlResponse.data.prediction === 'fraud') {
        const prob = mlResponse.data.fraud_probability;
        if (prob > 0.8) {
           await logSuspiciousActivity(userId, 'ML Model predicted fraud (high confidence)', features);
           return res.json({ status: 'blocked', reason: 'Fraudulent activity detected by ML' });
        } else {
           await logSuspiciousActivity(userId, 'ML Model flagged for review', features);
           return res.json({ status: 'flagged', message: 'Ride allowed but flagged for review' });
        }
      }
    } catch (mlError) {
      console.warn("ML API Check failed or unavailable, proceeding with rule-based results only.");
    }

    // 3. Normal Ride Booking Proceed
    res.json({ status: 'allowed', message: 'Ride booked successfully', features });

  } catch (error) {
    console.error("Error booking ride:", error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Node API running on port ${PORT}`);
});
