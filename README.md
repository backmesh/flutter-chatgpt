# Nimbus, ChatGPT-like Flutter App

ChatGPT-like interface built on Flutter to target multiple platforms. 

## Architecture

- Flutter app
- Google Gemini LLM 
- Firebase Firestore is used to preserve chats and messages with security rules to ensure that only authenticated users can read or write their data.
- Firebase Authentication is used to let users log in using email or Google.
- There is no backend. The Flutter client uses a pass-through server proxy to directly call the Google AI Gemini API.
