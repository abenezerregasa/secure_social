# S3-Factor Authentication Social Blog App

## Overview
A secure social blogging application that implements multi-layered authentication and authorization mechanisms to protect user accounts and system resources.

The system goes beyond traditional password-based authentication by integrating **three-factor authentication (3FA)** along with **token-based authorization**, ensuring strong protection against common security threats.

---

## Features
- Secure user registration and login
- Create, like, and comment on posts
- User-specific content management
- Multi-layered authentication system
- Token-based authorization (JWT)
- Resource-level access control

---

## Architecture
The system is built using a modern full-stack approach:

- **Frontend:** Flutter (mobile app with biometric support)
- **Backend:** Flask (API, authentication, business logic)
- **Database:** MySQL (secure storage of users, posts, OTP data)

---

## Authentication System (3FA)
The application uses **three-factor authentication**:

1. **Something you know** → Password  
2. **Something you have** → One-Time Password (OTP)  
3. **Something you are** → Biometric authentication  

### Authentication Flow
1. User enters email and password  
2. Backend verifies credentials (hashed)  
3. OTP is generated and sent  
4. User verifies OTP  
5. Biometric authentication is triggered  
6. Access is granted  

---

## Security Implementation

### Password Security
- Passwords are hashed using **bcrypt with salt**
- Preprocessed using **SHA-256**
- Never stored in plaintext

**Protection against:**
- Brute-force attacks  
- Rainbow table attacks  
- Database leaks

---

### OTP Verification
- OTP hashed with SHA-256 + salt
- Expiration time: **5 minutes**
- One-time use only
- Previous OTPs are invalidated

**Prevents:**
- Replay attacks  
- OTP reuse  
- Interception misuse 

---

### Biometric Authentication
- Uses device-level secure hardware (e.g., fingerprint)
- No biometric data stored in the app
- Returns only success/failure

Adds an extra layer tied to the physical user. 

---

## Authorization & Access Control

- Uses **JWT (JSON Web Tokens)** for secure sessions
- Protected API endpoints require valid tokens
- Middleware validates each request

### Access Rules
- Only content owners can modify/delete their data
- Unauthorized actions are blocked
- UI reflects permissions, but backend enforces them

---

## Security Principles Applied
- **Defense in Depth** → Multiple authentication layers  
- **Least Privilege** → Users only access allowed actions  
- **Secure Storage** → Sensitive data is hashed  
- **Separation of Concerns** → Clear frontend/backend roles 

---

## Limitations & Future Improvements
- Refresh tokens for better session management  
- Rate limiting to prevent brute-force attacks  
- Device binding for stronger identity verification  
- Logging and monitoring for threat detection 

---

## Tech Stack
- Flutter (Frontend)
- Flask (Backend API)
- MySQL (Database)
- JWT (Authentication)
- bcrypt & SHA-256 (Security)

---

## Summary
This project demonstrates a real-world implementation of secure authentication and authorization by combining multiple layers of protection. It highlights how modern security practices can be applied effectively in a full-stack application.

© Abenezer Regasa
