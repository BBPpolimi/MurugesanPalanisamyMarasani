# Best Bike Paths (BBP)

Best Bike Paths (BBP) is a mobile-first application designed to help cyclists discover safer, higher-quality bike routes while enabling the community to collaboratively maintain up-to-date information about bike path conditions. BBP combines personal trip tracking, crowd-sourced path quality reporting, and intelligent route scoring to go beyond traditional shortest-path navigation.
---
## Table of Contents

- [Overview](#overview)
- [Goals](#goals)
- [Key Features](#key-features)
- [User Types](#user-types)
- [System Scope](#system-scope)
- [Architecture Overview](#architecture-overview)
- [External Services](#external-services)
- [Privacy and Compliance](#privacy-and-compliance)
- [Project Status](#project-status)
- [Documentation](#documentation)
- [Authors](#authors)
- [License](#license)

---

## Overview

Urban and suburban cyclists often have multiple routing options, but route quality depends on factors such as road surface conditions, obstacles, safety, and traffic exposure. BBP addresses this by:

- Allowing users to **record and analyze bike trips**
- Enabling **manual and sensor-assisted reporting** of path conditions
- Providing **ranked bike routes** based on both quality and effectiveness
- Supporting **guest users** for quick route searches without registration

BBP is developed as part of the *Software Engineering II* course at *Politecnico di Milano* (Academic Year 2025–2026).

---

## Goals

The primary goals of BBP are:

1. **Personal Trip Tracking** – Record, store, and review trips with statistics and maps  
2. **Manual Path Contribution** – Let users report path statuses and obstacles  
3. **Automated Path Detection** – Detect candidate issues using device sensors  
4. **Route Search & Visualization** – Find and visualize bike routes between two points  
5. **Path Scoring** – Rank routes by quality and effectiveness  
6. **Data Merging** – Consolidate reports from multiple users into a single consensus  
7. **Privacy & Compliance** – Protect personal and location data  
8. **Context Enrichment** – Enrich trips with weather information when available  

---

## Key Features

### Trip Recording
- Real-time GPS tracking
- Automatic computation of distance, duration, and speed
- Offline handling and post-trip processing
- Optional weather enrichment

### Path Contribution
- Manual path and obstacle reporting
- Automatic detection of candidate obstacles via accelerometer and gyroscope
- User confirmation workflow before publication
- Editable and publishable contributions

### Route Search
- Origin–destination bike routing
- Scoring based on:
  - Path quality and surface condition
  - Obstacles and severity
  - Distance and route efficiency
- Visual comparison of multiple route options

### Data Aggregation
- Timestamp-based freshness weighting
- Majority-based conflict resolution
- Periodic recomputation of consolidated segment status

---

## User Types

- **Registered User**
  - Records trips
  - Contributes path information
  - Reviews personal history and statistics

- **Guest User**
  - Searches for bike routes
  - Views ranked paths without storing data

- **Administrator**
  - Moderates user activity
  - Manages data quality and abusive behavior

---

## System Scope

BBP is a **mobile-first web application and/or native app** that interacts with:

- Device hardware (GPS, accelerometer, gyroscope)
- External map and routing services
- External weather services
- A centralized backend for data storage and processing

The system focuses on community-maintained bike path data combined with personal trip logs.

---

## Architecture Overview

At a high level, the system consists of:

- **Client Application**
  - User interface
  - Sensor data collection
  - Local trip persistence

- **Backend Services**
  - User management
  - Trip and report storage
  - Route computation and scoring
  - Data merging and consensus engine

- **External APIs**
  - Maps and routing
  - Weather data

All communications use secure HTTPS channels.

---

## External Services

BBP integrates with third-party services for:

- **Maps & Routing**
  - Base map tiles
  - Geocoding
  - Route computation

- **Weather**
  - Historical and contextual weather data for trips

All external services are used in compliance with their respective licenses and terms.

---

## Privacy and Compliance

BBP is designed with a privacy-first approach:

- Explicit user consent for location and sensor access
- User-controlled publishability of path data
- Encryption of sensitive data at rest and in transit
- Compliance with applicable data protection regulations (e.g., GDPR)

BBP provides advisory routing information and does not replace official traffic regulations.

---

## Project Status

This repository currently contains **requirements and design documentation**.  
Implementation is expected to follow the specifications defined in the RASD.
---
## Documentation

- **Requirement Analysis and Specification Document (RASD)**  
  See the full RASD for detailed requirements, domain models, and formal analysis.

---

## Authors

- Jayasurya Marasani  
- Arunkumar Murugesan  
- Sneharajalakshmi Palanisamy  

---

## License

Copyright © 2026  
Jayasurya Marasani, Arunkumar Murugesan, Sneharajalakshmi Palanisamy  
All rights reserved.
