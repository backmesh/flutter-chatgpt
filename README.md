# ChatGPT-like Flutter App

ChatGPT-like interface built on Flutter to target multiple platforms. [Live Demo](https://flutter-chatgpt.pages.dev).

![](./demo.gif)


## Architecture

- Firebase Firestore is used to preserve chats and messages with security rules to ensure that only authenticated users can read or write their data.
- Firebase Authentication is used to let users log in using email.
- There is no backend or secrets. Google Gemini API is safely called using a [Backmesh](https://backmesh.com) API Proxy.
