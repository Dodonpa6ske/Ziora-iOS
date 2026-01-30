/**
 * Cloud Functions for Firebase (1st Gen)
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize with explicit credential to ensure FCM V1 auth works
admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: "ziora-520a9"
});

/**
 * Trigger: photos/{photoId}/likes/{likerId} created
 * Action: Send push notification to photo owner with localized message
 */
exports.sendLikeNotification = functions.firestore
    .document("photos/{photoId}/likes/{likerId}")
    .onCreate(async (snap, context) => {
        const photoId = context.params.photoId;
        const likerId = context.params.likerId;
        const likeData = snap.data();
        let likerCountry = likeData.likerCountry || "Unknown";
        const likerCountryCode = likeData.likerCountryCode; // ★追加

        try {

            // 写真の所有者を取得
            const photoDoc = await admin.firestore().collection("photos").doc(photoId).get();
            if (!photoDoc.exists) {
                console.log(`Photo ${photoId} not found, skipping notification.`);
                return;
            }

            const photoData = photoDoc.data();
            const ownerId = photoData.userId;

            // 自分自身のいいねは通知しない
            if (ownerId === likerId) return;

            // 所有者のFCMトークンと設定言語を取得
            const userDoc = await admin.firestore().collection("users").doc(ownerId).get();
            if (!userDoc.exists) return;

            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;
            const language = userData.language || "en";

            // ★追加: 国コードがあれば、受信者の言語で翻訳して上書きする
            if (likerCountryCode) {
                try {
                    // Node.js 14+ supports Intl.DisplayNames
                    const regionNames = new Intl.DisplayNames([language], { type: 'region' });
                    const translatedCountry = regionNames.of(likerCountryCode);
                    if (translatedCountry) {
                        likerCountry = translatedCountry;
                    }
                } catch (e) {
                    console.log(`Region translation failed for ${likerCountryCode} in ${language}:`, e);
                }
            }

            if (!fcmToken) {
                console.log(`No FCM token for user ${ownerId}`);
                return;
            }

            // 言語ごとのメッセージ
            let title = "New Like!";
            let body = `Someone from ${likerCountry} liked your photo!`;

            if (language === "ja") {
                title = "新しいいいね！";
                body = `${likerCountry} の誰かがあなたの写真にいいねしました！`;
            } else if (language === "ko") {
                title = "새로운 좋아요!";
                body = `${likerCountry}에서 누군가가 회원님의 사진을 좋아합니다!`;
            } else if (language === "es") {
                title = "¡Nuevo Me gusta!";
                body = `¡A alguien de ${likerCountry} le gustó tu foto!`;
            } else if (language === "fr") {
                title = "Nouveau J'aime !";
                body = `Quelqu'un de ${likerCountry} a aimé votre photo !`;
            }

            const message = {
                token: fcmToken,
                notification: {
                    title: title,
                    body: body
                },
                data: {
                    type: "like",
                    photoId: photoId
                },
                android: {
                    priority: "high",
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default"
                        }
                    }
                }
            };

            await admin.messaging().send(message);
            console.log(`Notification sent to ${ownerId} from ${likerCountry} (${language})`);

        } catch (error) {
            console.error("Error sending notification:", error);
        }
    });

// Cleanup tool for 404 images
exports.cleanupBrokenPhoto = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    }

    const photoId = data.photoId;
    if (!photoId) {
        throw new functions.https.HttpsError("invalid-argument", "photoId is required.");
    }

    const photoRef = admin.firestore().collection("photos").document(photoId);
    const doc = await photoRef.get();

    if (!doc.exists) {
        return { success: true, message: "Document already deleted." };
    }

    const photoData = doc.data();
    const imagePath = photoData.imagePath;

    if (!imagePath) {
        await photoRef.delete();
        return { success: true, message: "Deleted photo with no image path." };
    }

    try {
        const file = admin.storage().bucket().file(imagePath);
        const [exists] = await file.exists();

        if (!exists) {
            await photoRef.delete();
            console.log(`Cleaned up broken photo: ${photoId}`);
            return { success: true, message: "Deleted broken photo document." };
        } else {
            return { success: false, message: "Image exists." };
        }
    } catch (error) {
        console.error("Cleanup error:", error);
        throw new functions.https.HttpsError("internal", "Failed to check storage or delete.");
    }
});
